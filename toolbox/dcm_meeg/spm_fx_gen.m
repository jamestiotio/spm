function [f,J,Q] = spm_fx_gen(x,u,P,M)
% generic state equations for a neural mass models
% FORMAT [f,J,D] = spm_fx_cmc(x,u,P,M)
% FORMAT [f,J]   = spm_fx_cmc(x,u,P,M)
% FORMAT [f]     = spm_fx_cmc(x,u,P,M)
% x  - neuronal states
% u  - exogenous input
% P  - model parameters
% M  - model structure
%
% This routine compiles equations of motion is for multiple nodes or neural
% masses in the cell array of hidden states. To include a new sort of node,
% it is necessary to updatethe following routines:
% 
% spm_dcm_neural_priors: to specify the intrinsic parameters of a new model
% spm_dcm_x_neural:      to specify its initial states
% spm_L_priors:          to specify which hidden states generate signal
% spm_fx_gen (below):    to specify how different models interconnect
%
% This routine deal separately with the coupling between nodes (but depend
% upon extrinsic connectivity, sigmoid activation functions and delays -
% and coupling within notes (that calls on the model specific equations of
% motion.
%
%__________________________________________________________________________
% David O, Friston KJ (2003) A neural mass model for MEG/EEG: coupling and
% neuronal dynamics. NeuroImage 20: 1743-1755
%__________________________________________________________________________
% Copyright (C) 2005 Wellcome Trust Centre for Neuroimaging
 
% Karl Friston
% $Id: spm_fx_gen.m 6721 2016-02-16 20:26:40Z karl $
 
 
% model-specific parameters
%==========================================================================

% model or node-specific state equations of motions
%--------------------------------------------------------------------------
fx{1} = @spm_fx_erp;                                    % ERP model
fx{2} = @spm_fx_cmc;                                    % CMC model

% indices of extrinsically coupled hidden states
%--------------------------------------------------------------------------
efferent(1,:) = [9 9 9 9];               % sources of ERP connections
afferent(1,:) = [4 8 5 8];               % targets of ERP connections

efferent(2,:) = [3 3 7 7];               % sources of CMC connections
afferent(2,:) = [2 8 4 6];               % targets of CMC connections

% scaling of afferent extrinsic connectivity (Hz)
%--------------------------------------------------------------------------
E(1,:) = [32 2 16 4]*1000;               % ERP connections      
E(2,:) = [64 4 64 8]*1000;               % CMC connections

% intrinsic delays log(ms)
%--------------------------------------------------------------------------
D(1) = 2;                                % ERP connections      
D(2) = 1;                                % CMC connections


% get model specific operators
%==========================================================================
if isvector(x)
    x = spm_unvec(x,M.x);                               % neuronal states
end

% get the neural mass models {'ERP','CMC'}
%--------------------------------------------------------------------------
n     = numel(x);
model = M.dipfit.model;
for i = 1:n
    if     strcmp(model{i},'ERP')
        nmm(i) = 1;
    elseif strcmp(model{i},'CMC')
        nmm(i) = 2;
    end
end

% synaptic activation function
%--------------------------------------------------------------------------
R     = 2/3;                      % gain of sigmoid activation function
B     = 0;                        % bias or background (sigmoid)
R     = R.*exp(P.S);
sig   = @(x,R,B)1./(1 + exp(-R*x(:) + B)) - 1/(1 + exp(B));
dSdx  = @(x,R,B)(R*exp(B - R*x(:)))./(exp(B - R*x(:)) + 1).^2;
for i = 1:n
    S{i} = sig(x{i},R,B);
end

% Extrinsic connections
%--------------------------------------------------------------------------
for i = 1:numel(P.A)
    A{i} = exp(P.A{i});
end

% detect and reduce the strength of reciprocal (lateral) connections
%--------------------------------------------------------------------------
TOL   = exp(-8);
for i = 1:numel(A)
    L    = (A{i} > TOL) & (A{i}' > TOL);
    A{i} = A{i}./(1 + 4*L);
end

% and scale of extrinsic connectivity (Hz)
%--------------------------------------------------------------------------
for i = 1:n
    for k = 1:numel(P.A)
        A{k}(i,:) = E(nmm(i),k)*A{k}(i,:);
    end
end


% assemble flow
%==========================================================================
N     = M;
for i = 1:n
    
    % intrinsic flow
    %----------------------------------------------------------------------
    N.x  = M.x{i};
    if isfield(M,'u')
        ui = u(i,:);
    else
        ui = u;
    end
    Q    = P.int{i};
    Q.C  = P.C(i,:);
    f{i} = fx{nmm(i)}(x{i},ui,Q,N);

    
    % extrinsic flow
    %----------------------------------------------------------------------
    for j = 1:n
        for k = 1:numel(P.A)
            if A{k}(i,j) > TOL
                ik       = afferent(nmm(i),k);
                jk       = efferent(nmm(j),k);
                f{i}(ik) = f{i}(ik) + A{k}(i,j)*S{j}(jk);
            end
        end
    end
end


% concatenate flow
%--------------------------------------------------------------------------
f  = spm_vec(f);

if nargout < 2; return, end

% Jacobian
%==========================================================================


for i = 1:n
    for j = 1:n
        
        J{i,j} = zeros(numel(x{i}),numel(x{j}));
        if i == j
            
            % intrinsic flow
            %--------------------------------------------------------------
            N.x    = M.x{i};
            if isfield(M,'u')
                ui = u(i,:);
            else
                ui = u;
            end
            Q      = P.int{i};
            Q.C    = P.C(i,:);
            J{i,i} = spm_diff(fx{nmm(i)},x{i},ui,Q,N,1);
            
        else
            
            % extrinsic flow
            %--------------------------------------------------------------
            for k = 1:numel(P.A)
                if A{k}(i,j) > TOL
                    ik  = afferent(nmm(i),k);
                    jk  = efferent(nmm(j),k);
                    dS  = dSdx(x{j}(jk),R,B);
                    J{i,j}(ik,jk) = J{i,j}(ik,jk) + A{k}(i,j)*dS;
                end
            end
        end
    end
end

J  = spm_cat(J);

 
if nargout < 3; return, end


% delays
%==========================================================================
% Delay differential equations can be integrated efficiently (but
% approximately) by absorbing the delay operator into the Jacobian
%
%    dx(t)/dt     = f(x(t - d))
%                 = Q(d)f(x(t))
%
%    J(d)         = Q(d)df/dx
%--------------------------------------------------------------------------
% Implement: dx(t)/dt = f(x(t - d)) = inv(1 + D.*dfdx)*f(x(t))
%                     = Q*f = Q*J*x(t)
%--------------------------------------------------------------------------

% source specific (intrinsic) delays
%--------------------------------------------------------------------------
for i = 1:n
    P.D(i,i) = P.D(i,i) + log(D(nmm(i)));
end

% N-th order Taylor approximation to delay
%--------------------------------------------------------------------------
N     = 256;
for i = 1:8
    Q = spm_dcm_delay(P,M,J,N);
    if isfinite(norm(Q,'inf')) && (norm(Q*J,'inf') < norm(J,'inf')*4)
        break
    else        
        N = N/2;
    end
end

return




