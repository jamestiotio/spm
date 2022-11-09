function [L,yhat,st] = mci_pb_like (P,M,U,Y)
% Log-likelihood for Preece-Baines model 
% FORMAT [L,yhat,st] = mci_pb_like (P,M,U,Y)
%
% P         parameters
% M,U,Y     as usual
%__________________________________________________________________________

% Will Penny
% Copyright (C) 2015 Wellcome Trust Centre for Neuroimaging

% Status flag (only used for dynamic systems)
st=[];

T=length(Y);
yhat = mci_pb_gen (P,M,U);
E=sum(sum((Y-yhat).^2));

L = M.logdet_Ce - 0.5*T*log(2*pi);
L = L - 0.5*M.iCe*E;

