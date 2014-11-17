function [f] = spm_lotka_volterra(x,v,P)
% equations of motion for Lotka-Volterra dynamics
% FORMAT [f] = spm_lotka_volterra(x,v,P)
% FORMAT [f] = spm_lotka_volterra(x,v)
% FORMAT [f] = spm_lotka_volterra(n)
%
% [x.]x - hidden states
% [x.]v - exogenous inputs
% v     - parameter of P.f
% P.f   - lateral connectivity
% P.k   - rate = 1/dt [default 1]
%
% returns f = dx/dt = P.f*S(x) - x/8 + 1;
%              S(x) = 1./(1 + exp(-x))
%
% where P.f determines the order of unstable fixed points visited in the
% stable heteroclinic channel. If P.f is not specified it will be computed
% using v. If x is a scalar P.f is returned (with v = 1).
%
%__________________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging

% Karl Friston
% $Id: spm_lotka_volterra.m 6263 2014-11-17 13:48:36Z karl $


% intialise
%==========================================================================
try, k = P.k; catch, k = 1; end
try, l = P.l; catch, l = 1; end
try, v      ; catch, v = 1; end

% just return connectivity
%--------------------------------------------------------------------------
if nargin == 1 && isscalar(x)
    n  = x;
    f  = spm_speye(n,n,-1) - spm_speye(n,n,1); f(n,1) = -1; f(1,n) = 1;
    f  = f + speye(n,n) - 1;
    return
else
    x  = spm_vec(x);
end


% check for parameters of succession
%--------------------------------------------------------------------------
try
    P.f;
catch
    n   = length(x);
    P.f = spm_speye(n,n,-1) - spm_speye(n,n,1); P.f(n,1) = -1; P.f(1,n) = 1;
    P.f = v*P.f + speye(n,n) - 1;
end


% flow
%==========================================================================
try
    
    % SHC states
    %----------------------------------------------------------------------
    f   = P.f*(1./(1 + exp(-x))) - x/8 + 1;
    f   = k*f;
    
catch
    
    % SHC states (x.x and x.v) and flow to point attractors in P.g
    %----------------------------------------------------------------------
    x.e = exp(x.x);
    f.x = P.f*(1./(1 + exp(-x.x))) - x.x/8 + 1;
    f.v = P.g*x.e - x.v*sum(x.e);
    
    f.x = k*f.x;
    f.v = l*f.v;
    
end

