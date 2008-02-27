function [L] = spm_erp_L(P,M)
% returns [projected] lead field L as a function of position and moments
% FORMAT [L] = spm_erp_L(P,M)
% P  - model parameters
% M  - model specification
% L  - lead field
%__________________________________________________________________________
%
% The lead field (L) is constructed using the specific parameters in P and,
% where necessary information in the dipole structure M.dipfit. For ECD
% models P.Lpos and P.L encode the position and moments of the ECD. The
% field M.dipfit.type:
%
%    'ECD (EEG)'
%    'ECD (EEG)'
%    'Imaging'
%    'LFP'
%
% determines whether the data are MEG or EEG. For imaging reconstructions
% the paramters P.L are a (m x n) matrix of coefficients that scale the
% contrition of n sources to m = M.dipfit.Nm modes encoded in M.dipfit.G.
%
% For LFP models (the default) P.L (1 x n) vector simply encodes the
% electrode gain for each of n sources.
%
% see; Kiebel et al. (2006) NeuroImage
%__________________________________________________________________________
% Copyright (C) 2005 Wellcome Trust Centre for Neuroimaging

% Karl Friston
% $Id: spm_erp_L.m 1174 2008-02-27 20:22:30Z karl $

% Create a persient variable that rembers the last locations
%--------------------------------------------------------------------------
persistent LastLpos LastL

% output
%==========================================================================

% number of sources - n
%--------------------------------------------------------------------------
try
    n = size(P.Lpos,2);
catch
    try
        n = size(P.L,2);
    end
end

% type of spatial model
%--------------------------------------------------------------------------
try
    type = M.dipfit.type;
catch
    type = 'LFP';
end


switch type

    % parameterised lead field ECD/EEG
    %----------------------------------------------------------------------
    case{'ECD (EEG)'}

        % re-compute lead field only if any dipoles changed
        %------------------------------------------------------------------
        try
            Id = find(any(LastLpos ~= P.Lpos));
        catch
            Id = 1:n;
        end

        % record new spatial parameters
        %--------------------------------------------------------------
        LastLpos = P.Lpos;

        % note that in all DCM code, EEG coordinates are in MNI
        % space-orientation. Transform here to POL space and add
        % translation to relate coordinates to centre of sphere
        %--------------------------------------------------------------
        iMt  = M.dipfit.Mmni2polsphere;
        iSt  = iMt; iSt(1:3,4) = 0;

        Lpos = iMt*[P.Lpos; ones(1,n)];
        Lmom = iSt*[P.L   ; ones(1,n)];
        Lpos = Lpos(1:3,:);
        Lmom = Lmom(1:3,:);

        for i = Id
            Lf = fieldtrip_eeg_leadfield4(Lpos(:,i), M.dipfit.elc, M.dipfit.vol);
            LastL(:,:,i) = Lf*1000;
        end
        for i = 1:n
            L(:,i) = LastL(:,:,i)*Lmom(:,i);
        end


    % parameterised lead field ECD/MEG
    %----------------------------------------------------------------------
    case{'ECD (MEG)'}

        % re-compute lead field only if any dipoles changed
        %------------------------------------------------------------------
        try
            Id = find(any(LastLpos ~= P.Lpos));
        catch
            Id = 1:n;
        end

        % record new locations and compute new lead field components
        %------------------------------------------------------------------
        LastLpos = P.Lpos;

        for i = Id
            Lf = fieldtrip_meg_leadfield(P.Lpos(:,i)', M.grad, M.dipfit.vol);
            LastL(:,:,i) = Lf(M.dipfit.Ic,:)*1000;
        end
        for i = 1:n
            L(:,i) = LastL(:,:,i)*P.L(:,i);
        end

    % Imaging solution {specified in M.dipfit.G}
    %----------------------------------------------------------------------
    case{'Imaging'}
        
        % re-compute lead field only if any coeficients have changed
        %------------------------------------------------------------------
        try
            Id = find(any(LastLpos ~= P.L));
        catch
            Id = 1:n;
        end
        for i = Id
            LastL(:,i) = M.dipfit.G{i}*P.L(:,i);
        end
        
        % record new spatial parameters
        %--------------------------------------------------------------
        LastLpos = P.L;
        L        = LastL;

    % LFP or sources - no lead feild required
    %----------------------------------------------------------------------
    case{'LFP'}

        L = sparse(diag(P.L));

    otherwise
        warndlg('unknown type of lead field')
end

