function results = spm_preproc8(obj)
% Combined Segmentation and Spatial Normalisation
%
% FORMAT results = spm_preproc8(obj)
%
% obj is a structure, and must have the following fields...
%    image    - a structure (array) of handles of individual scans,
%               of the sort returned by spm_vol.  Data can be
%               multispectral, with N channels, but files must be in
%               voxel-for-voxel alignment.
%    biasfwhm - FWHM of bias field(s). There are N elements, one for
%               each channel.
%    biasreg  - Regularisation of bias field estimation. N elements.
%    tpm      - Tissue probability map data, as generated by
%               spm_load_priors.  This would represent Kb different
%               tissue classes - including air (background).
%    lkp      - A lookup table indicating which Gaussians should be used
%               with each of the Kb tissue probability maps.  For example,
%               if there are 6 tissue types, with two Gaussians to
%               represent each, except the 5th, which uses 4 Gaussians,
%               then lkp=[1,1,2,2,3,3,4,4,5,5,5,5,6,6].
%    Affine   - a 4x4 affine transformation matrix, such that the mapping
%               from voxels in the individual to those in the template
%               is by tpm.M\Affine*obj.image(1).mat.
%    reg      - Regularisation for the nonlinear registration of the
%               template (tissue probability maps) to the individual.
%    samp     - The distance (mm) between samples.  In order to achieve
%               a reasonable speed, not all voxels in the images are
%               used for the parameter estimation.  Better segmentation
%               would be expected if all were used, but this would be
%               extremely slow.
%    fwhm     - A smoothness estimate for computing a fudge factor that
%               tries to account for spatial covariance in the noise.
%
% obj also has some optional fields...
%    mg       - a 1xK vector (where K is the lengrh of obj.lkp). This
%               represents the mixing proportions within each tissue.
%    mn       - an NxK matrix containing the means of the Gaussians.
%    vr       - an NxNxK matrix containing the covariances of each of
%               the Gaussians.
%    Tbias    - a cell array encoding the parameterisation of each bias
%               field.
%    Twarp    - the encoding of the nonlinear deformation field.
%
% Various estimated parameters are saved as fields of the results
% structure.  Some of these are taken from the input, whereas others
% are estimated or optimised...
%    results.image  = obj.image;
%    results.tpm    = obj.tpm.V;
%    results.Affine = obj.Affine;
%    results.lkp    = obj.lkp;
%    results.MT     = an affine transform used in conjunction with the
%                     parameterisation of the warps.
%    results.Twarp  = obj.Twarp;
%    results.Tbias  = obj.Tbias;
%    results.mg     = obj.mg;
%    results.mn     = obj.mn;
%    results.vr     = obj.vr;
%    results.ll     = Log-likelihood.
%
%_______________________________________________________________________
% The general principles are described in the following paper, but some
% technical details differ.  These include a different parameterisation
% of the deformations, the ability to use multi-channel data and the
% use of a fuller set of tissue probability maps.  The way the mixing
% proportions are dealt with is also slightly different.
%
% Ashburner J & Friston KJ. "Unified segmentation".
% NeuroImage 26(3):839-851 (2005).
%_______________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging

% John Ashburner
% $Id: spm_preproc8.m 7320 2018-05-29 10:19:49Z john $

wp_reg    = 1; % Bias wp towards 1

Affine    = obj.Affine;
tpm       = obj.tpm;
V         = obj.image;
M         = tpm.M\Affine*V(1).mat;
d0        = V(1).dim(1:3);
vx        = sqrt(sum(V(1).mat(1:3,1:3).^2));
sk        = max([1 1 1],round(obj.samp*[1 1 1]./vx));
[x0,y0,o] = ndgrid(1:sk(1):d0(1),1:sk(2):d0(2),1);
z0        = 1:sk(3):d0(3);
tiny      = eps*eps;
lkp       = obj.lkp;
if isempty(lkp)
    K       = 2000;
    Kb      = numel(tpm.dat);
    use_mog = false;
else
    K       = numel(obj.lkp);
    Kb      = max(obj.lkp);
    use_mog = true;
end

kron = @(a,b) spm_krutil(a,b);

% Some random numbers are used, so initialise random number generators to
% give the same results each time.
%rng('default');

% These will eventually need changing
% because using character strings to control RAND and RANDN is deprecated.
randn('state',0);
rand('state',0);

% Fudge Factor - to (approximately) account for non-independence of voxels.
% Note that variances add, and that Var[a*x + b*y] = a^2*Var[x] + b^2*Var[y]
% Therefore the variance of i.i.d. noise after Gaussian smoothing is equal
% to the sum of the Gaussian function squared times the original variance.
% A Gaussian is given by g=sqrt(2*pi*s^2)^(-1/2)*exp(-0.5*x.^2/s^2);
% After squaring, this is (2*pi*s^2)^(-1)*exp(-x.^2/s^2), which is a scaled
% Gaussian. Letting s2 = 2/sqrt(2), this is equal to
% (4*pi*s^2)^(-1/2)*(2*pi*s2^2)^(-1/2)*exp(-0.5*x.^2/s2^2), from which
% the (4*pi*s^2)^(-1/2) factor comes from.
fwhm = obj.fwhm;                            % FWHM of image smoothness
vx   = sqrt(sum(V(1).mat(1:3,1:3).^2));     % Voxel size
fwhm = fwhm+mean(vx); 
s    = fwhm/sqrt(8*log(2));                 % Standard deviation
ff   = prod(4*pi*(s./vx./sk).^2 + 1)^(1/2); 


spm_diffeo('boundary',1);

% Initialise Deformation
%-----------------------------------------------------------------------
% This part is fiddly because of the regularisation of the warps.
% The fact that displacement fields are only parameterised every few
% voxels means that the functions in spm_diffeo need tweaking to
% account for the difference between the units of displacement and
% the separation of the voxels (if that makes sense).

% More work/thought is needed in terms of adjusting regularisation to
% account for different voxel sizes.  I'm still not satisfied that
% this (rescaling the regularisaiton by prod(vx.*sk)) is optimal.
% The same thing applies to all the nonlinear warping code in SPM.
param  = [sk.*vx prod(vx.*sk)*ff*obj.reg]; % FIX THIS (remove "prod(vx.*sk)")

% Mapping from indices of subsampled voxels to indices of voxels in image(s).
MT     = [sk(1) 0 0 (1-sk(1));0 sk(2) 0 (1-sk(2)); 0 0 sk(3) (1-sk(3));0 0 0 1];

% For multiplying and dividing displacements to map from the subsampled voxel indices
% and the actual image voxel indices.
sk4    = reshape(sk,[1 1 1 3]);

d      = [size(x0) length(z0)];
if isfield(obj,'Twarp')
    Twarp = obj.Twarp;
    llr   = -0.5*sum(sum(sum(sum(Twarp.*bsxfun(@times,spm_diffeo('vel2mom',bsxfun(@times,Twarp,1./sk4),param),1./sk4)))));
else
    Twarp = zeros([d,3],'single');
    llr   = 0;
end


% Initialise bias correction
%-----------------------------------------------------------------------
N    = numel(V);
cl   = cell(N,1);
args = {'C',cl,'B1',cl,'B2',cl,'B3',cl,'T',cl,'ll',cl};
if use_mog
    chan = struct(args{:});
else
    chan = struct(args{:},'hist',cl,'lik',cl,'alph',cl,'grad',cl,'lam',cl,'interscal',cl);
end

for n=1:N
    % GAUSSIAN REGULARISATION for bias correction
    fwhm    = obj.biasfwhm(n);
    biasreg = obj.biasreg(n);
    vx      = sqrt(sum(V(n).mat(1:3,1:3).^2));
    d0      = V(n).dim;
    sd      = vx(1)*d0(1)/fwhm; d3(1) = ceil(sd*2); krn_x   = exp(-(0:(d3(1)-1)).^2/sd.^2)/sqrt(vx(1));
    sd      = vx(2)*d0(2)/fwhm; d3(2) = ceil(sd*2); krn_y   = exp(-(0:(d3(2)-1)).^2/sd.^2)/sqrt(vx(2));
    sd      = vx(3)*d0(3)/fwhm; d3(3) = ceil(sd*2); krn_z   = exp(-(0:(d3(3)-1)).^2/sd.^2)/sqrt(vx(3));
    Cbias   = kron(krn_z,kron(krn_y,krn_x)).^(-2)*biasreg*ff;
    chan(n).C   = sparse(1:length(Cbias),1:length(Cbias),Cbias,length(Cbias),length(Cbias));

    % Basis functions for bias correction
    chan(n).B3  = spm_dctmtx(d0(3),d3(3),z0);
    chan(n).B2  = spm_dctmtx(d0(2),d3(2),y0(1,:)');
    chan(n).B1  = spm_dctmtx(d0(1),d3(1),x0(:,1));

    % Initial parameterisation of bias field
    if isfield(obj,'Tbias') && ~isempty(obj.Tbias{n})
        chan(n).T = obj.Tbias{n};
    else
        chan(n).T   = zeros(d3);
    end
end


ll     = -Inf;
tol1   = 1e-4; % Stopping criterion.  For more accuracy, use a smaller value

if isfield(obj,'msk') && ~isempty(obj.msk)
    VM = spm_vol(obj.msk);
    if sum(sum((VM.mat-V(1).mat).^2)) > 1e-6 || any(VM.dim(1:3) ~= V(1).dim(1:3))
        error('Mask must have the same dimensions and orientation as the image.');
    end
end

% Load the data
%-----------------------------------------------------------------------
nm      = 0; % Number of voxels

% For integer data types, add a tiny amount of random noise to prevent aliasing
% effects due to "bias" correction.
scrand = zeros(N,1);
for n=1:N
    if spm_type(V(n).dt(1),'intt')
        scrand(n) = V(n).pinfo(1);
    end
end

% Overall moments used later for regularising via a ``Wishart-style prior''
mom0 = zeros(1,N);
mom1 = zeros(1,N);
mom2 = zeros(1,N);

cl   = cell(length(z0),1);
buf  = struct('msk',cl,'nm',cl,'f',cl,'dat',cl,'bf',cl);
for z=1:length(z0)
   % Load only those voxels that are more than 5mm up
   % from the bottom of the tissue probability map.  This
   % assumes that the affine transformation is pretty close.

   %x1  = M(1,1)*x0 + M(1,2)*y0 + (M(1,3)*z0(z) + M(1,4));
   %y1  = M(2,1)*x0 + M(2,2)*y0 + (M(2,3)*z0(z) + M(2,4));
    z1  = M(3,1)*x0 + M(3,2)*y0 + (M(3,3)*z0(z) + M(3,4));
    e   = sqrt(sum(tpm.M(1:3,1:3).^2));
    e   = 5./e; % mm from edge of TPM
    buf(z).msk = z1>e(3);

    % Initially load all the data, but prepare to exclude
    % locations where any of the images is not finite, or
    % is zero.  We want this to work for skull-stripped
    % images too. The -3924 and -1500 options have been
    % added for CT data.
    fz = cell(1,N);
    for n=1:N
        fz{n}      = spm_sample_vol(V(n),x0,y0,o*z0(z),0);
        buf(z).msk = buf(z).msk & isfinite(fz{n}) & (fz{n}~=0) & (fz{n}~=-3024) & (fz{n}~=-1500);
    end

    if isfield(obj,'msk') && ~isempty(obj.msk)
        % Exclude any voxels to be masked out
        msk        = spm_sample_vol(VM,x0,y0,o*z0(z),0);
        buf(z).msk = buf(z).msk & msk;
    end

    % Eliminate unwanted voxels
    buf(z).nm  = sum(buf(z).msk(:));
    nm         = nm + buf(z).nm;
    for n=1:N
        if scrand(n)
            % Data is an integer type, so to prevent aliasing in the histogram, small
            % random values are added.  It's not elegant, but the alternative would be
            % too slow for practical use.
            buf(z).f{n}  = single(fz{n}(buf(z).msk)+rand(buf(z).nm,1)*scrand(n)-scrand(n)/2);
        else
            buf(z).f{n}  = single(fz{n}(buf(z).msk));
        end
        mom0(n) = mom0(n) + buf(z).nm;
        mom1(n) = mom1(n) + sum(buf(z).f{n});
        mom2(n) = mom2(n) + sum(buf(z).f{n}.^2);
    end

    % Create a buffer for tissue probability info
    buf(z).dat = zeros([buf(z).nm,Kb],'single');
end

% Construct a ``Wishart-style prior'' (vr0)
vr0 = diag(mom2./mom0 - (mom1./mom0).^2)/Kb^2;


% Create initial bias field
%-----------------------------------------------------------------------
llrb = 0;
for n=1:N
    B1 = chan(n).B1;
    B2 = chan(n).B2;
    B3 = chan(n).B3;
    C  = chan(n).C;
    T  = chan(n).T;
    chan(n).ll = double(-0.5*T(:)'*C*T(:));
    for z=1:numel(z0)
        bf           = transf(B1,B2,B3(z,:),T);
        tmp          = bf(buf(z).msk);
        chan(n).ll   = chan(n).ll + double(sum(tmp));
        buf(z).bf{n} = single(exp(tmp));
    end
    llrb = llrb + chan(n).ll;
    clear B1 B2 B3 T C
end

spm_plot_convergence('Init','Initialising','Log-likelihood','Iteration');
if isfield(obj,'wp')
    wp = obj.wp;
else
    wp = ones(1,Kb)/Kb;
end
for iter=1:30

    % Load the warped prior probability images into the buffer
    %------------------------------------------------------------
    for z=1:length(z0)
        if ~buf(z).nm, continue; end
        [x1,y1,z1] = defs(Twarp,z,x0,y0,z0,M,buf(z).msk);
        b          = spm_sample_priors8(tpm,x1,y1,z1);
        for k1=1:Kb
            buf(z).dat(:,k1) = b{k1};
        end
    end

    if iter==1
        % Starting estimates for intensity distribution parameters
        %-----------------------------------------------------------------------
        if use_mog
            % Starting estimates for Gaussian parameters
            %-----------------------------------------------------------------------
            if isfield(obj,'mg') && isfield(obj,'mn') && isfield(obj,'vr')
                mg = obj.mg;
                mn = obj.mn;
                vr = obj.vr;
            else
                % Begin with moments:
                K   = Kb;
                lkp = 1:Kb;
                mm0 = zeros(Kb,1);
                mm1 = zeros(N,Kb);
                mm2 = zeros(N,N,Kb);
                for z=1:length(z0)
                    cr = zeros(size(buf(z).f{1},1),N);
                    for n=1:N
                        cr(:,n)  = double(buf(z).f{n}.*buf(z).bf{n});
                    end
                    for k1=1:Kb, % Moments
                        b           = double(buf(z).dat(:,k1));
                        mm0(k1)     = mm0(k1)     + sum(b);
                        mm1(:,k1)   = mm1(:,k1)   + (b'*cr)';
                        mm2(:,:,k1) = mm2(:,:,k1) + (repmat(b,1,N).*cr)'*cr;
                    end
                    clear cr
                end

                % Use moments to compute means and variances, and then use these
                % to initialise the Gaussians
                mn = zeros(N,Kb);
                vr = zeros(N,N,Kb);
                vr1 = zeros(N,N);
                for k1=1:Kb
                    mn(:,k1)   = mm1(:,k1)/(mm0(k1)+tiny);
                    vr1        = vr1 + (mm2(:,:,k1) - mm1(:,k1)*mm1(:,k1)'/mm0(k1));
                end
                vr1 = (vr1+N*vr0)/(sum(mm0)+N);
                for k1=1:Kb
                    vr(:,:,k1) = vr1;
                end
                mg = ones(Kb,1);
            end
        else
            % Starting estimates for histograms
            %-----------------------------------------------------------------------
            for n=1:N
                maxval = -Inf;
                minval =  Inf;
                for z=1:length(z0)
                    if ~buf(z).nm, continue; end
                    maxval = max(max(buf(z).f{n}),maxval);
                    minval = min(min(buf(z).f{n}),minval);
                end
                maxval = max(maxval*1.5,-minval*0.05); % Account for bias correction effects
                minval = min(minval*1.5,-maxval*0.05);
                chan(n).interscal = [1 minval; 1 maxval]\[1;K];
                h0     = zeros(K,Kb);
                for z=1:length(z0)
                    if ~buf(z).nm, continue; end
                    cr       = round(buf(z).f{n}.*buf(z).bf{n}*chan(n).interscal(2) + chan(n).interscal(1));
                    cr       = min(max(cr,1),K);
                    for k1=1:Kb
                        h0(:,k1) = h0(:,k1) + accumarray(cr,buf(z).dat(:,k1),[K,1]);
                    end
                end
                chan(n).hist = h0;
            end
        end
    end

    for iter1=1:8
        if use_mog
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Estimate cluster parameters
            %------------------------------------------------------------
            for subit=1:20
                oll  = ll;
                mom0 = zeros(K,1)+tiny; % Initialise moments
                mom1 = zeros(N,K);
                mom2 = zeros(N,N,K);
                mgm  = zeros(1,Kb);
                ll   = llr+llrb;
                for z=1:length(z0)
                    if ~buf(z).nm, continue; end
                    B   = double(buf(z).dat);
                    s   = 1./(B*wp');
                    mgm = mgm + s'*B;
                    [q,dll] = latent(buf(z).f,buf(z).bf,mg,mn,vr,B,lkp,wp);
                    ll  = ll + dll;

                    cr  = zeros(size(q,1),N);
                    for n=1:N
                        cr(:,n)  = double(buf(z).f{n}.*buf(z).bf{n});
                    end
                    for k=1:K, % Update moments
                        q(:,k)      = q(:,k);
                        mom0(k)     = mom0(k)     + sum(q(:,k));
                        mom1(:,k)   = mom1(:,k)   + (q(:,k)'*cr)';
                        mom2(:,:,k) = mom2(:,:,k) + (repmat(q(:,k),1,N).*cr)'*cr;
                    end
                    clear cr
                end
                my_fprintf('MOG:\t%g\t%g\t%g\n', ll,llr,llrb);

                % Mixing proportions, Means and Variances from moments
                for k=1:K
                    tmp       = mom0(lkp==lkp(k));
                    mg(k)     = (mom0(k)+tiny)/sum(tmp+tiny);  % US eq. 27 (partly)
                    mn(:,k)   = mom1(:,k)/(mom0(k)+tiny);      % US eq. 23
                    vr(:,:,k) = (mom2(:,:,k) - mom1(:,k)*mom1(:,k)'/mom0(k) + N*vr0)/(mom0(k)+N); % US eq. 25
                end
                for k1=1:Kb
                    wp(k1) = (sum(mom0(lkp==k1)) + wp_reg*1)/(mgm(k1) + wp_reg*Kb); % bias the solution towards 1
                end
                wp = wp/sum(wp);

                if subit>1 || iter>1
                    spm_plot_convergence('Set',ll);
                end
                if subit>1 && ll-oll<tol1*nm
                    % Improvement is small, so go to next step
                    break;
                end
            end
        else
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Estimate histogram parameters
            %------------------------------------------------------------

            % Compute regularisation for histogram smoothing
            for n=1:N
               %x = (1:K)';
                for k1=1:Kb
                   %mom0 = sum(chan(n).hist(:,k1)) + eps;
                   %mom1 = sum(chan(n).hist(:,k1).*x) + eps;
                   %chan(n).lam(k1) = sum(chan(n).hist(:,k1).*(x-mom1./mom0).^2+1)/(mom0+1)+1;
                    chan(n).lam(k1) = Kb^2*double(vr0(N,N)*chan(n).interscal(2)^2);
                end
            end

            for subit=1:20
                oll  = ll;
                ll   = llr+llrb;
                for n=1:N
                    chan(n).lik  = spm_smohist(chan(n).hist,chan(n).lam);
                    chan(n).lik  = chan(n).lik*chan(n).interscal(2);
                    chan(n).alph = log(chan(n).lik+eps);
                    chan(n).hist = zeros(K,Kb);
                end
                mgm  = zeros(1,Kb);
                for z=1:length(z0)
                    B   = double(buf(z).dat);
                    s   = 1./(B*wp');
                    mgm = mgm + s'*B;

                    [q,dll] = latent_nonpar(buf(z).f,buf(z).bf,chan,buf(z).dat,wp);
                    ll      = ll + dll;

                    cr  = cell(N,1);
                    for n=1:N
                        tmp   = buf(z).f{n}.*buf(z).bf{n}*chan(n).interscal(2) + chan(n).interscal(1);
                        cr{n} = min(max(round(tmp),1),K);
                    end
                    for k1=1:Kb
                        for n=1:N
                            chan(n).hist(:,k1) = chan(n).hist(:,k1) + accumarray(cr{n},q(:,k1),[K,1]);
                        end
                    end
                    clear cr
                end
                wp = (sum(chan(1).hist)+wp_reg*1)./(mgm+wp_reg*Kb);
                wp = wp/sum(wp);

                my_fprintf('Hist:\t%g\t%g\t%g\n', ll,llr,llrb);

                if subit>1 || iter>1
                    spm_plot_convergence('Set',ll);
                end
                if subit>1 && ll-oll<tol1*nm
                    % Improvement is small, so go to next step
                    break;
                end
            end
            for n=1:N
                chan(n).lik  = spm_smohist(chan(n).hist,chan(n).lam);
                chan(n).lik  = chan(n).lik*chan(n).interscal(2);
                chan(n).alph = log(chan(n).lik+eps);
                chan(n).grad1 = convn(chan(n).alph,[0.5 0 -0.5]'*chan(n).interscal(2),  'same');
                chan(n).grad2 = convn(chan(n).alph,[1  -2  1  ]'*chan(n).interscal(2)^2,'same');
            end
        end
 
        if iter1 > 1 && ~((ll-ooll)>2*tol1*nm), break; end
        ooll = ll;


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Estimate bias
        % Note that for multi-spectral data, the covariances among
        % channels are not computed as part of the second derivatives.
        % The aim is to save memory, and maybe make the computations
        % faster.
        %------------------------------------------------------------

        if use_mog
            pr = zeros(size(vr)); % Precisions
            for k=1:K, pr(:,:,k) = inv(vr(:,:,k)); end
        end

        for subit=1:1
            for n=1:N
                d3  = numel(chan(n).T);
                if d3>0
                    % Compute objective function and its 1st and second derivatives
                    Alpha = zeros(d3,d3); % Second derivatives
                    Beta  = zeros(d3,1);  % First derivatives
                    %ll    = llr+llrb;
                    for z=1:length(z0)
                        if ~buf(z).nm, continue; end

                        if use_mog
                            q  = latent(buf(z).f,buf(z).bf,mg,mn,vr,buf(z).dat,lkp,wp);
                            cr = cell(N,1);
                            for n1=1:N, cr{n1} = double(buf(z).f{n1}).*double(buf(z).bf{n1}); end
      
                            w1 = zeros(buf(z).nm,1);
                            w2 = zeros(buf(z).nm,1);
                            for k=1:K
                                qk  = q(:,k);
                                w0  = zeros(buf(z).nm,1);
                                for n1=1:N
                                    w0 = w0 + pr(n1,n,k)*(mn(n1,k) - cr{n1});
                                end
                                w1  = w1 + qk.*w0;
                                w2  = w2 + qk*pr(n,n,k);
                            end
                            wt1   = zeros(d(1:2));
                            wt1(buf(z).msk) = -(1 + cr{n}.*w1); % US eq. 34 (gradient)
                            wt2   = zeros(d(1:2));
                            wt2(buf(z).msk) = cr{n}.*cr{n}.*w2 + 1; % Simplified Hessian of US eq. 34
                            clear cr
                        else
                            q   = latent_nonpar(buf(z).f,buf(z).bf,chan,buf(z).dat,wp);
                            cr0 = buf(z).f{n}.*buf(z).bf{n};
                            cr  = cr0*chan(n).interscal(2) + chan(n).interscal(1);
                            cr  = min(max(round(cr),1),K);
                            wt1 = zeros(d(1:2)); 
                            wt2 = zeros(d(1:2));
                            for k1=1:Kb
                                qk  = q(:,k1);
                                gr1 = chan(n).grad1(:,k1);
                                gr1 = gr1(cr);
                                gr2 = chan(n).grad2(:,k1);
                                gr2 = min(gr2(cr),0); % Regularise
                                wt1(buf(z).msk) = wt1(buf(z).msk) - qk.*(gr1.*cr0 + 1);
                               %wt2(buf(z).msk) = wt2(buf(z).msk) - qk.*(gr1.*cr0 + gr2.*cr0.^2);
                                wt2(buf(z).msk) = wt2(buf(z).msk) + qk.*(1 - gr2.*cr0.^2);
                            end
                        end

                        b3    = chan(n).B3(z,:)';
                        Beta  = Beta  + kron(b3,spm_krutil(wt1,chan(n).B1,chan(n).B2,0));
                        Alpha = Alpha + kron(b3*b3',spm_krutil(wt2,chan(n).B1,chan(n).B2,1));
                        clear wt1 wt2 b3
                    end

                    oll     = ll;        % Previous log-likelihood - for checking improvements
                    C       = chan(n).C; % Inverse covariance of priors
                    oldT    = chan(n).T;

                    % Gauss-Newton update of bias field parameters
                    Update  = reshape((Alpha + C)\(Beta + C*chan(n).T(:)),size(chan(n).T));
                    clear Alpha Beta

                    armijo = 1.0;
                    for line_search=1:12
                        chan(n).T = chan(n).T - armijo*Update; % Backtrack if necessary

                        % Re-generate bias field, and compute terms of the objective function
                        chan(n).ll = double(-0.5*chan(n).T(:)'*C*chan(n).T(:));
                        for z=1:length(z0)
                            if ~buf(z).nm, continue; end
                            bf           = transf(chan(n).B1,chan(n).B2,chan(n).B3(z,:),chan(n).T);
                            tmp          = bf(buf(z).msk);
                            chan(n).ll   = chan(n).ll + double(sum(tmp));
                            buf(z).bf{n} = single(exp(tmp));
                        end
                        llrb = 0;
                        for n1=1:N, llrb = llrb + chan(n1).ll; end
                        ll   = llr+llrb;
                        for z=1:length(z0)
                            if ~buf(z).nm, continue; end
                            if use_mog
                                [q,dll] = latent(buf(z).f,buf(z).bf,mg,mn,vr,buf(z).dat,lkp,wp);
                                ll      = ll + dll;
                            else
                                [q,dll] = latent_nonpar(buf(z).f,buf(z).bf,chan,buf(z).dat,wp);
                                ll      = ll + dll;
                            end
                            clear q
                        end

                        % Decide whether to accept new estimates
                        if ll>=oll
                            spm_plot_convergence('Set',ll);
                            my_fprintf('Bias-%d:\t%g\t%g\t%g :o)\n', n, ll, llr,llrb);
                            break;
                        else
                            ll        = oll;
                            chan(n).T = oldT;
                            armijo    = armijo*0.5;
                            my_fprintf('Bias-%d:\t%g\t%g\t%g :o(\n', n, ll, llr,llrb);
                        end 
                    end
                    clear oldT
                end
            end
            if subit > 1 && ~(ll-oll>tol1*nm)
                % Improvement is only small, so go to next step
                break;
            end
        end

        if iter==1 && iter1==1
            % Most of the log-likelihood improvements are in the first iteration.
            % Show only improvements after this, as they are more clearly visible.
            spm_plot_convergence('Clear');
            spm_plot_convergence('Init','Processing','Log-likelihood','Iteration');

           if use_mog && numel(obj.lkp) ~= numel(lkp)
                mn1 = mn;
                vr1 = vr;
                lkp = obj.lkp;
                K   = numel(lkp);
                Kb  = max(lkp);

                % Use moments to compute means and variances, and then use these
                % to initialise the Gaussians
                mg = ones(K,1)/K;
                mn = ones(N,K);
                vr = zeros(N,N,K);

                for k1=1:Kb
                    % A crude heuristic to replace a single Gaussian by a bunch of Gaussians
                    % If there is only one Gaussian, then it should be the same as the
                    % original distribution.
                    kk  = sum(lkp==k1);
                    w   = 1./(1+exp(-(kk-1)*0.25))-0.5;
                    mn(:,lkp==k1)   = sqrtm(vr1(:,:,k1))*randn(N,kk)*w + repmat(mn1(:,k1),[1,kk]);
                    vr(:,:,lkp==k1) = repmat(vr1(:,:,k1)*(1-w),[1,1,kk]);
                    mg(lkp==k1)     = 1/kk;
                end
            end
        end
    end



    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Estimate deformations
    %------------------------------------------------------------
    ll_const = 0;
    ll       = llr+llrb;
    if use_mog
        % Compute likelihoods, and save them in buf.dat
        for z=1:length(z0)
            if ~buf(z).nm, continue; end
            q        =  zeros(buf(z).nm,Kb);
            qt       = log_likelihoods(buf(z).f,buf(z).bf,mg,mn,vr);
            max_qt   = max(qt,[],2);
            ll_const = ll_const + sum(max_qt);
            B        = bsxfun(@times,double(buf(z).dat),wp);
            B        = bsxfun(@times,B,1./sum(B,2));
            for k1=1:Kb
                for k=find(lkp==k1)
                    q(:,k1) = q(:,k1) + exp(qt(:,k)-max_qt);
                end
                buf(z).dat(:,k1) = single(q(:,k1));
            end
            ll = ll + sum(log(sum(q.*B+tiny,2)));
        end
        ll = ll + ll_const;
    else
        % Compute likelihoods, and save them in buf.dat
        for z=1:length(z0)
            if ~buf(z).nm, continue; end
            q        = log_likelihoods_nonpar(buf(z).f,buf(z).bf,chan);
            max_q    = max(q,[],2);
            ll_const = ll_const + sum(max_q);
            q        = exp(bsxfun(@minus,q,max_q));
            B        = bsxfun(@times,double(buf(z).dat),wp);
            B        = bsxfun(@times,B,1./sum(B,2));
            ll       = ll + sum(log(sum(q.*B+tiny,2)),1);
            buf(z).dat = single(q);
        end
        ll = ll + ll_const;
    end

    oll = ll;
    for subit=1:3
        Alpha  = zeros([size(x0),numel(z0),6],'single');
        Beta   = zeros([size(x0),numel(z0),3],'single');
        for z=1:length(z0)
            if ~buf(z).nm, continue; end

            % Deformations from parameters
            [x1,y1,z1]      = defs(Twarp,z,x0,y0,z0,M,buf(z).msk);

            % Tissue probability map and spatial derivatives
            [b,db1,db2,db3] = spm_sample_priors8(tpm,x1,y1,z1);
            clear x1 y1 z1

            % Adjust for tissue weights
            s   = zeros(size(b{1}));
            ds1 = zeros(size(b{1}));
            ds2 = zeros(size(b{1}));
            ds3 = zeros(size(b{1}));
            for k1=1:Kb
                b{k1}   = wp(k1)*b{k1};
                db1{k1} = wp(k1)*db1{k1};
                db2{k1} = wp(k1)*db2{k1};
                db3{k1} = wp(k1)*db3{k1};
                s       =  s  + b{k1};
                ds1     = ds1 + db1{k1};
                ds2     = ds2 + db2{k1};
                ds3     = ds3 + db3{k1};
            end
            for k1=1:Kb
                b{k1}   = b{k1}./s;
                db1{k1} = (db1{k1}-b{k1}.*ds1)./s;
                db2{k1} = (db2{k1}-b{k1}.*ds2)./s;
                db3{k1} = (db3{k1}-b{k1}.*ds3)./s;
            end
            clear s ds1 ds2 ds3

            % Rotate gradients (according to initial affine registration) and
            % compute the sums of the tpm and its gradients, times the likelihoods
            % (from buf.dat).
            p   = zeros(buf(z).nm,1)+eps;
            dp1 = zeros(buf(z).nm,1);
            dp2 = zeros(buf(z).nm,1);
            dp3 = zeros(buf(z).nm,1);
            MM  = M*MT; % Map from sampled voxels to atlas data
            for k1=1:Kb
                pp  = double(buf(z).dat(:,k1));
                p   = p   + pp.*b{k1};
                dp1 = dp1 + pp.*(MM(1,1)*db1{k1} + MM(2,1)*db2{k1} + MM(3,1)*db3{k1});
                dp2 = dp2 + pp.*(MM(1,2)*db1{k1} + MM(2,2)*db2{k1} + MM(3,2)*db3{k1});
                dp3 = dp3 + pp.*(MM(1,3)*db1{k1} + MM(2,3)*db2{k1} + MM(3,3)*db3{k1});
            end
            clear b db1 db2 db3

            % Compute first and second derivatives of the matching term.  Note that
            % these can be represented by a vector and tensor field respectively.
            tmp             = zeros(d(1:2));
            tmp(buf(z).msk) = dp1./p; dp1 = tmp;
            tmp(buf(z).msk) = dp2./p; dp2 = tmp;
            tmp(buf(z).msk) = dp3./p; dp3 = tmp;

            Beta(:,:,z,1)   = -dp1;     % First derivatives
            Beta(:,:,z,2)   = -dp2;
            Beta(:,:,z,3)   = -dp3;

            Alpha(:,:,z,1)  = dp1.*dp1; % Second derivatives
            Alpha(:,:,z,2)  = dp2.*dp2;
            Alpha(:,:,z,3)  = dp3.*dp3;
            Alpha(:,:,z,4)  = dp1.*dp2;
            Alpha(:,:,z,5)  = dp1.*dp3;
            Alpha(:,:,z,6)  = dp2.*dp3;
            clear tmp p dp1 dp2 dp3
        end

        % Heavy-to-light regularisation
        if ~isfield(obj,'Twarp')
            scal   = 2^max(10-iter,0);
            prm    = param;
           %prm([5 7 8]) = param([5 7 8])*scal;
            prm(6)       = param(6)*scal^2;
        else
            prm = [param(1:3)   param(4:8)];
        end

        % Add in the first derivatives of the prior term
        Beta   = Beta  + spm_diffeo('vel2mom',bsxfun(@times,Twarp,1./sk4),prm);

        % Gauss-Newton increment
        Update = bsxfun(@times,spm_diffeo('fmg',Alpha,Beta,[prm 2 2]),sk4);

        % Line search to ensure objective function improves
        armijo = 1.0;
        for line_search=1:12
            Twarp1 = Twarp - armijo*Update; % Backtrack if necessary

            % Recompute objective function
            llr1   = -0.5*sum(sum(sum(sum(Twarp1.*bsxfun(@times,spm_diffeo('vel2mom',bsxfun(@times,Twarp1,1./sk4),prm),1./sk4)))));
            ll1    = llr1+llrb+ll_const;
            for z=1:length(z0)
                if ~buf(z).nm, continue; end
                [x1,y1,z1] = defs(Twarp1,z,x0,y0,z0,M,buf(z).msk);
                b          = spm_sample_priors8(tpm,x1,y1,z1);
                clear x1 y1 z1
                s   = zeros(size(b{1}));
                for k1=1:Kb, b{k1} = b{k1}*wp(k1); s = s + b{k1}; end
                for k1=1:Kb, b{k1} = b{k1}./s; end

                sq = zeros(buf(z).nm,1);
                for k1=1:Kb
                    sq = sq + double(buf(z).dat(:,k1)).*double(b{k1});
                end
                clear b
                ll1 = ll1 + sum(log(sq));
                clear sq
            end

            if ll1<ll
                % Still not better, so keep searching inwards.
                my_fprintf('Warp:\t%g\t%g\t%g :o(\t(%g)\n', ll1, llr1,llrb,armijo);
                armijo = armijo*0.75;
            else
                % Better.  Accept the new solution.
                spm_plot_convergence('Set',ll1);
                my_fprintf('Warp:\t%g\t%g\t%g :o)\t(%g)\n', ll1, llr1,llrb,armijo);
                ll     = ll1;
                llr    = llr1;
                Twarp  = Twarp1;
                break
            end
        end
        clear Alpha Beta

        if ~((ll-oll)>tol1*nm)
            % Registration no longer helping, so move on
            break
        end
        oll = ll;
    end

    if iter>=10 && ~((ll-ooll)>2*tol1*nm)
        % Finished
        break
    end
end
% spm_plot_convergence('Clear');

% Save the results
results.image  = obj.image;
results.tpm    = tpm.V;
results.Affine = Affine;
results.lkp    = lkp;
results.MT     = MT;
results.Twarp  = Twarp;
results.Tbias  = {chan(:).T};
results.wp     = wp;
if use_mog
    results.mg     = mg;
    results.mn     = mn;
    results.vr     = vr;
else
    for n=1:N
        results.intensity(n).lik       = chan(n).lik;
        results.intensity(n).interscal = chan(n).interscal;
    end
end
results.ll      = ll;
return;
%=======================================================================

%=======================================================================
function t = transf(B1,B2,B3,T)
if ~isempty(T)
    d2 = [size(T) 1];
    t1 = reshape(reshape(T, d2(1)*d2(2),d2(3))*B3', d2(1), d2(2));
    t  = B1*t1*B2';
else
    t  = zeros(size(B1,1),size(B2,1));
end
return;
%=======================================================================

%=======================================================================
function [x1,y1,z1] = defs(Twarp,z,x0,y0,z0,M,msk)
x1a = x0    + double(Twarp(:,:,z,1));
y1a = y0    + double(Twarp(:,:,z,2));
z1a = z0(z) + double(Twarp(:,:,z,3));
if nargin>=7
    x1a = x1a(msk);
    y1a = y1a(msk);
    z1a = z1a(msk);
end
x1  = M(1,1)*x1a + M(1,2)*y1a + M(1,3)*z1a + M(1,4);
y1  = M(2,1)*x1a + M(2,2)*y1a + M(2,3)*z1a + M(2,4);
z1  = M(3,1)*x1a + M(3,2)*y1a + M(3,3)*z1a + M(3,4);
return;
%=======================================================================

%=======================================================================
function L = log_likelihoods(f,bf,mg,mn,vr)
K  = numel(mg);
N  = numel(f);
M  = numel(f{1});
cr = zeros(M,N);
for n=1:N
    cr(:,n) = double(f{n}(:)).*double(bf{n}(:));
end
L  = zeros(numel(f{1}),K);
for k=1:K
    C      = chol(vr(:,:,k));
    d      = bsxfun(@minus,cr,mn(:,k)')/C;
    L(:,k) = log(mg(k)) - (N/2)*log(2*pi) - sum(log(diag(C))) - 0.5*sum(d.*d,2);
end
%=======================================================================

%=======================================================================
function L = log_likelihoods_nonpar(f,bf,chan)
K  = size(chan(1).lik,1);
Kb = size(chan(1).lik,2);
N  = numel(chan);
L  = zeros(numel(f{1}),Kb);
for n=1:N
    tmp     = f{n}.*bf{n}*chan(n).interscal(2) + chan(n).interscal(1);
    tmp     = min(max(round(tmp),1),K);
    loglik  = chan(n).alph;
    for k1=1:Kb
        L(:,k1) = L(:,k1)+loglik(tmp,k1);
    end
end
%=======================================================================

%=======================================================================
function B = log_spatial_priors(B,wp)
B   = bsxfun(@times,B,wp);
B   = log(bsxfun(@times,B,1./sum(B,2)));
%=======================================================================

%=======================================================================
function [Q,ll] = safe_softmax(Q)
maxQ = max(Q,[],2);
Q    = exp(bsxfun(@minus,Q,maxQ));
sQ   = sum(Q,2);
ll   = sum(log(sQ)+maxQ);
Q    = bsxfun(@rdivide,Q,sQ);
%=======================================================================

%=======================================================================
function [Q,ll] = latent(f,bf,mg,mn,vr,B,lkp,wp)
B   = log_spatial_priors(B,wp);
Q   = log_likelihoods(f,bf,mg,mn,vr);
Kb  = max(lkp);
for k1=1:Kb
    for k=find(lkp==k1)
        Q(:,k) = Q(:,k) + B(:,k1);
    end
end
[Q,ll] = safe_softmax(Q);
%=======================================================================

%=======================================================================
function [Q,ll] = latent_nonpar(f,bf,chan,B,wp)
B      = log_spatial_priors(B,wp);
Q      = log_likelihoods_nonpar(f,bf,chan);
Q      = Q + B;
[Q,ll] = safe_softmax(Q);
%=======================================================================

%=======================================================================
function count = my_fprintf(varargin)
verbose = false;
if verbose
    count = fprintf(varargin{:});
else
    count = 0;
end
%=======================================================================

%=======================================================================


