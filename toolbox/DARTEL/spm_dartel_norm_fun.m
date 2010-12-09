function out = spm_dartel_norm_fun(job)
% Spatially normalise and smooth fMRI/PET data to MNI space, using DARTEL flow fields
% FORMAT out = spm_dartel_norm_fun(job)
% job - a structure generated by the configuration file
%   job.template - DARTEL template for aligning to MNI space
%   job.subj(n)  - Subject n
%       subj(n).flowfield - DARTEL flow field
%       subj(n).images    - Images for this subject
%   job.vox      - Voxel sizes for spatially normalised images
%   job.bb       - Bounding box for spatially normalised images
%   job.preserve - How to transform
%                  0 = preserve concentrations
%                  1 = preserve integral (cf "modulation")
%
% Normally, DARTEL generates warped images that align with the average-
% shaped template.  This routine includes an initial affine regisration
% of the template (the final one generated by DARTEL), with the TPM data
% released with SPM.
%
% "Smoothed" (blurred) spatially normalised images are generated in such a
% way that the original signal is preserved. Normalised images are
% generated by a "pushing" rather than a "pulling" (the usual) procedure.
% Note that trilinear interpolation is used, and no masking is done.  It
% is therefore essential that the images are realigned and resliced
% before they are spatially normalised.  Alternatively, contrast images
% generated from unsmoothed native-space fMRI/PET data can be spatially
% normalised for a 2nd level analysis.
%
% Two "preserve" options are provided.  One of them should do the
% equavalent of generating smoothed "modulated" spatially normalised
% images.  The other does the equivalent of smoothing the modulated
% normalised fMRI/PET, and dividing by the smoothed Jacobian determinants.
%
%__________________________________________________________________________
% Copyright (C) 2009 Wellcome Trust Centre for Neuroimaging

% John Ashburner
% $Id: spm_dartel_norm_fun.m 4136 2010-12-09 22:22:28Z guillaume $

% Hard coded stuff, that should maybe be customisable
K    = 6;
tpm  = fullfile(spm('Dir'),'toolbox','Seg','TPM.nii');
Mmni = spm_get_space(tpm);

% DARTEL template
if ~isempty(job.template{1})
    Nt     = nifti(job.template{1});
    do_aff = true;
else
    Nt     = nifti(tpm);
    do_aff = false;
end

% Deal with desired bounding box and voxel sizes.
%--------------------------------------------------------------------------
bb   = job.bb;
vox  = job.vox;
Mt   = Nt.mat;
dimt = size(Nt.dat);

if any(isfinite(bb(:))) || any(isfinite(vox)),
    [bb0,vox0] = bbvox(Mt,dimt);

    msk = ~isfinite(vox); vox(msk) = vox0(msk);
    msk = ~isfinite(bb);   bb(msk) =  bb0(msk);

    bb  = sort(bb);
    vox = abs(vox);

    % Adjust bounding box slightly - so it rounds to closest voxel.
    bb(:,1) = round(bb(:,1)/vox(1))*vox(1);
    bb(:,2) = round(bb(:,2)/vox(2))*vox(2);
    bb(:,3) = round(bb(:,3)/vox(3))*vox(3);
    dim = round(diff(bb)./vox+1);
    of  = -vox.*(round(-bb(1,:)./vox)+1);
    mat = [vox(1) 0 0 of(1) ; 0 vox(2) 0 of(2) ; 0 0 vox(3) of(3) ; 0 0 0 1];
    if det(Mt(1:3,1:3)) < 0,
        mat = mat*[-1 0 0 dim(1)+1; 0 1 0 0; 0 0 1 0; 0 0 0 1];
    end
else
    dim = dimt(1:3);
    mat = Mt;
end

if isfield(job.data,'subj') || isfield(job.data,'subjs'),
    if do_aff
        [pth,nam,ext] = fileparts(Nt.dat.fname);
        if exist(fullfile(pth,[nam '_2mni.mat']))
            load(fullfile(pth,[nam '_2mni.mat']),'mni');
        else
            % Affine registration of DARTEL Template with MNI space.
            %--------------------------------------------------------------------------
            fprintf('** Affine registering "%s" with MNI space **\n', nam);
            clear mni
            mni.affine = Mmni/spm_klaff(Nt,tpm);
            mni.code   = 'MNI152';
            save(fullfile(pth,[nam '_2mni.mat']),'mni');
        end
        M = mat\mni.affine/Mt;
        %M = mat\Mmni*inv(spm_klaff(Nt,tpm))*inv(Mt);
        mat_intent = mni.code;
    else
        M = mat\eye(4);
        mat_intent = 'Aligned';
    end
    fprintf('\n');

    if isfield(job.data,'subjs')
        % Re-order data
        %--------------------------------------------------------------------------
        subjs = job.data.subjs;
        subj  = struct('flowfield',cell(numel(subjs.flowfields),1),...
                       'images',   cell(numel(subjs.flowfields),1));
        for i=1:numel(subj)
            subj(i).flowfield = {subjs.flowfields{i}};
            subj(i).images    = cell(numel(subjs.images),1);
            for j=1:numel(subjs.images),
                subj(i).images{j} = subjs.images{j}{i};
            end
        end
    else
        subj = job.data.subj;
    end

    % Loop over subjects
    %--------------------------------------------------------------------------
    out = cell(1,numel(subj));
    for i=1:numel(subj),
        % Spatially normalise data from this subject
        [pth,nam,ext] = fileparts(subj(i).flowfield{1});
        fprintf('** "%s" **\n', nam);
        out{i} = deal_with_subject(subj(i).flowfield,subj(i).images,K, mat,dim,M,job.preserve,job.fwhm,mat_intent);
    end

    if isfield(job.data,'subjs'),
        out1 = out;
        out  = cell(numel(subj),numel(subjs.images));
        for i=1:numel(subj),
            for j=1:numel(subjs.images),
                out{i,j} = out1{i}{j};
            end
        end
    end
end
%__________________________________________________________________________

%__________________________________________________________________________
function out = deal_with_subject(Pu,PI,K,mat,dim,M,jactransf,fwhm,mat_intent)

% Generate deformation, which is the inverse of the usual one (it is for "pushing"
% rather than the usual "pulling"). This deformation is affine transformed to
% allow for different voxel sizes and bounding boxes, and also to incorporate
% the affine mapping between MNI space and the population average shape.
%--------------------------------------------------------------------------
NU  = nifti(Pu{1});
M   = M*NU.mat;
y0  = spm_dartel_integrate(NU.dat,[0 1], K);
y   = zeros(size(y0),'single');
y(:,:,:,1) = M(1,1)*y0(:,:,:,1) + M(1,2)*y0(:,:,:,2) + M(1,3)*y0(:,:,:,3) + M(1,4);
y(:,:,:,2) = M(2,1)*y0(:,:,:,1) + M(2,2)*y0(:,:,:,2) + M(2,3)*y0(:,:,:,3) + M(2,4);
y(:,:,:,3) = M(3,1)*y0(:,:,:,1) + M(3,2)*y0(:,:,:,2) + M(3,3)*y0(:,:,:,3) + M(3,4);
y0 = y;
clear y

odm = zeros(1,3);
oM  = zeros(4,4);
out = cell(1,numel(PI));
for m=1:numel(PI),

    % Generate headers etc for output images
    %----------------------------------------------------------------------
    [pth,nam,ext,num] = spm_fileparts(PI{m});
    NI = nifti(fullfile(pth,[nam ext]));
    NO = NI;
    if jactransf,
        NO.dat.fname=fullfile(pth,['smw' nam ext]);
        NO.dat.scl_slope = 1.0;
        NO.dat.scl_inter = 0.0;
        NO.dat.dtype     = 'float32-le';
    else
        NO.dat.fname=fullfile(pth,['sw' nam ext]);
    end
    NO.dat.dim = [dim NI.dat.dim(4:end)];
    NO.mat  = mat;
    NO.mat0 = mat;
    NO.mat_intent  = mat_intent;
    NO.mat0_intent = mat_intent;
    NO.descrip = sprintf('Smoothed (%gx%gx%g) DARTEL normed',fwhm);
    out{m} = NO.dat.fname;
    NO.extras = [];
    create(NO);

    % Smoothing settings
    vx  = sqrt(sum(mat(1:3,1:3).^2));
    krn = max(fwhm./vx,0.1);

    % Loop over volumes within the file
    %----------------------------------------------------------------------
    fprintf('%s',nam); drawnow;
    for j=1:size(NI.dat,4),

        % Check if it is a DARTEL "imported" image to normalise
        if sum(sum((NI.mat  - NU.mat ).^2)) < 0.0001 && ...
           sum(sum((NI.mat0 - NU.mat0).^2)) < 0.0001,
            % No affine transform necessary
            M  = eye(4);
            dm = [size(NI.dat),1,1,1,1];
            y  = y0;
        else
            % Need to resample the mapping by an affine transform
            % so that it maps from voxels in the native space image
            % to voxels in the spatially normalised image.
            %--------------------------------------------------------------
            M0 = NI.mat;
            if isfield(NI,'extras') && isfield(NI.extras,'mat'),
                M1 = NI.extras.mat;
                if size(M1,3) >= j && sum(sum(M1(:,:,j).^2)) ~=0,
                    M0 = M1(:,:,j);
                end
            end

            M   = NU.mat0\M0;
            dm  = [size(NI.dat),1,1,1,1];
            if ~all(dm(1:3)==odm) || ~all(M(:)==oM(:)),
                % Generate new deformation (if needed)
                y   = zeros([dm(1:3),3],'single');
                for d=1:3,
                    yd = y0(:,:,:,d);
                    for x3=1:size(y,3),
                        y(:,:,x3,d) = single(spm_slice_vol(yd,M*spm_matrix([0 0 x3]),dm(1:2),[1 NaN]));
                    end
                end
            end
        end
        odm = dm(1:3);
        oM  = M;

        % Write the warped data for this time point.
        %------------------------------------------------------------------
        for k=1:size(NI.dat,5),
            for l=1:size(NI.dat,6),
                f  = single(NI.dat(:,:,:,j,k,l));
                if ~jactransf,
                    % Unmodulated - note the slightly novel procedure
                    [f,c] = dartel3('push',f,y,dim);
                    spm_smooth(f,f,krn); % Side effects
                    spm_smooth(c,c,krn); % Side effects
                    f = f./(c+0.001); % I don't like it, but it may stop a few emails.
                else
                    % Modulated, by pushing
                    scal = abs(det(NI.mat(1:3,1:3))/det(NO.mat(1:3,1:3))); % Account for vox sizes
                    f    = dartel3('push',f,y,dim)*scal;
                    spm_smooth(f,f,krn); % Side effects
                end
                NO.dat(:,:,:,j,k,l) = f;
                fprintf('\t%d,%d,%d', j,k,l); drawnow;
            end
        end
    end
    fprintf('\n'); drawnow;
end
%__________________________________________________________________________

%__________________________________________________________________________
function [bb,vx] = bbvox(M,dim)
vx = sqrt(sum(M(1:3,1:3).^2));
if det(M(1:3,1:3))<0, vx(1) = -vx(1); end;
o  = M\[0 0 0 1]';
o  = o(1:3)';
bb = [-vx.*(o-1) ; vx.*(dim(1:3)-o)];
return;
 
