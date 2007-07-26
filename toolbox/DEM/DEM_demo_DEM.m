% Triple estimation of states, parameters and hyperparameters:
% This demo focuses esimating both the osates and paramters ti furish a
% compleet systemn idenfication given only the form of the system and its
% repeonses to unkown input (c.f., DEM_demo_EM, which uses kown inotus)
%==========================================================================

clear M
 
% get basic convolution model
%==========================================================================
M       = spm_DEM_M('convolution model');

% free parameters
%--------------------------------------------------------------------------
P       = M(1).pE;                            % true parameters
ip      = [2 5];                              % free parameters
pE      = spm_vec(P);
pE(ip)  = 0;
pE      = spm_unvec(pE,P);
pC      = sparse(ip,ip,exp(8),np,np);
M(1).pE = pE;
M(1).pC = pC;
 
% free hyperparameters
%--------------------------------------------------------------------------
M(1).Q  = {speye(M(1).l,M(1).l)};
M(1).R  = {speye(M(1).n,M(1).n)};
 
 
% generate data and invert
%==========================================================================
M(1).E.nN = 32;                                % DEM-steps
N         = 32;                                % length of data sequence
U         = exp(-([1:N] - 12).^2/(2.^2));      % this is the Gaussian cause
DEM       = spm_DEM_generate(M,U,{P},{8,32},{32});
DEM       = spm_DEM(DEM);

% overlay true values
%--------------------------------------------------------------------------
subplot(2,2,2)
hold on
plot([1:N],DEM.pU.x{1},'linewidth',2,'color',[1 1 1]/2)
hold off
 
subplot(2,2,3)
hold on
plot([1:N],DEM.pU.v{2},'linewidth',2,'color',[1 1 1]/2)
hold off

% parameters
%--------------------------------------------------------------------------
qP    = spm_vec(DEM.qP.P);
qP    = qP(ip);
tP    = spm_vec(DEM.pP.P);
tP    = tP(ip);
 
subplot(2,2,4)
bar([tP qP])
axis square
legend('true','DEM')
title('parameters')
 
cq    = 1.64*sqrt(diag(DEM.qP.C(ip,ip)));
hold on
for i = 1:length(qP)
    plot([i i] + 1/8,qP(i) + [-1 1]*cq(i),'LineWidth',8,'color','r')
end
hold off