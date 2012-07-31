function [x,M] = spm_x_cmm(P)
% initialises a state structure for a mean field model
% FORMAT [x,M] = spm_x_cmm(P)
%
% P - parameter structure
% M - model structure
%
% x        - array of states
% x(i,j,k) - k-th state of j-th population on i-th source
%
%   population: 1 - excitatory spiny stellate cells (input cells)
%               2 - superficial pyramidal cells     (forward output cells)
%               3 - inhibitory interneurons         (intrisic interneuons)
%               4 - deep pyramidal cells            (backward output cells)
%
%        state: 1 V  - voltage
%               2 gE - conductance (excitatory)
%               3 gI - conductance (inhibitory)
%
% M - model structure
%
% see also: spm_x_mfm
%__________________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging

% Karl Friston
% $Id: spm_x_cmm.m 4814 2012-07-30 19:56:05Z karl $
 

% dimensions
%--------------------------------------------------------------------------
ns   = size(P.A{1},1);                           % number of sources
np   = 4;                                        % number of populations
 
% create (initialise voltage at -70mV)
%--------------------------------------------------------------------------
x    = zeros(ns,np,3);