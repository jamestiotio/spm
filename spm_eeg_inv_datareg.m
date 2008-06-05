function M1 = spm_eeg_inv_datareg(S)
% Co-registration of two setse of fiducials according to sets of
% corresponding points and (optionally) headshapes.
% rigid co-registration
%           1: fiducials based (3 landmarks: nasion, left ear, right ear)
%           2: surface matching between sensor mesh and headshape
%           (starts with a type 1 registration)
%
% FORMAT M1 = spm_eeg_inv_datareg(S)
%
% Input:
%
% S  - input struct
% fields of S:
%
% S.sourcefid  - EEG fiducials (struct)
% S.targetfid = MRI fiducials
% S.template  - 1 - input is a template (for EEG)
%               0 - input is an individual head model
%               2 - input is a template (for MEG) - enforce uniform scaling
%
% S.useheadshape - 1 use headshape matching 0 - don't
%
%
% Output:
% M1 = homogenous transformation matrix
%
% If a template is used, the senor locations are transformed using an
% affine (rigid body) mapping.  If headshape locations are supplied
% this is generalized to a full twelve parameter affine mapping (n.b.
% this might not be appropriate for MEG data).
%__________________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging

% Jeremie Mattout
% $Id: spm_eeg_inv_datareg.m 1794 2008-06-05 16:17:39Z vladimir $


if nargin == 0 || ~isstruct(S)
    error('Input struct is required');
end

if ~isfield(S, 'targetfid')
    error('Target fiducials are missing');
else
    targetfid = forwinv_convert_units(S.targetfid, 'mm');
    nfid = size(targetfid.fid.pnt, 1);
end

if ~isfield(S, 'sourcefid')
    error('Source are missing');
else
    sourcefid = forwinv_convert_units(S.sourcefid, 'mm');
    sourcefid.fid.pnt = sourcefid.fid.pnt(1:nfid, :);
    sourcefid.fid.label = sourcefid.fid.label(1:nfid);
end

if ~isfield(S, 'template')
    S.template = 0;
end


% Estimate-apply rigid body transform to sensor space
%--------------------------------------------------------------------------
M1 = spm_eeg_inv_rigidreg(targetfid.fid.pnt', sourcefid.fid.pnt');

sourcefid = forwinv_transform_headshape(M1, sourcefid);

if S.template

    % constatined affine transform
    %--------------------------------------------------------------------------
    aff   = S.template;
    for i = 1:64

        % scale
        %----------------------------------------------------------------------
        M       = pinv(sourcefid.fid.pnt(:))*targetfid.fid.pnt(:);
        M       = sparse(1:4,1:4,[M M M 1]);

        sourcefid = forwinv_transform_headshape(M, sourcefid);

        M1      = M*M1;

        % and move
        %----------------------------------------------------------------------
        M       = spm_eeg_inv_rigidreg(targetfid.fid.pnt', sourcefid.fid.pnt');

        sourcefid = forwinv_transform_headshape(M, sourcefid);

        M1      = M*M1;
  
        if (norm(M)-1)< eps
            break;
        end
    end
else
    aff = 0;
end


% Surface matching between the scalp vertices in MRI space and
% the headshape positions in data space
%--------------------------------------------------------------------------
if  ~isempty(sourcefid.pnt) && S.useheadshape

    headshape = sourcefid.pnt;
    scalpvert = targetfid.pnt;

    % load surface locations from sMRI
    %----------------------------------------------------------------------
    if size(headshape,2) > size(headshape,1)
        headshape = headshape';
    end
    if size(scalpvert,2) > size(scalpvert,1)
        scalpvert = scalpvert';
    end

    % intialise plot
    %----------------------------------------------------------------------
    h    = spm_figure('GetWin','Graphics');
    clf(h); figure(h)
    set(h,'DoubleBuffer','on','BackingStore','on');
    Fmri = plot3(scalpvert(:,1),scalpvert(:,2),scalpvert(:,3),'ro','MarkerFaceColor','r');
    hold on;
    Fhsp = plot3(headshape(:,1),headshape(:,2),headshape(:,3),'bs','MarkerFaceColor','b');
    axis off image
    drawnow

    % nearest point registration
    %----------------------------------------------------------------------
    M    = spm_eeg_inv_icp(scalpvert',headshape',targetfid.fid.pnt',sourcefid.fid.pnt',Fmri,Fhsp,aff);

    % transform headshape and eeg fiducials
    %----------------------------------------------------------------------
    sourcefid = forwinv_transform_headshape(M, sourcefid);
    M1        = M*M1;
end
