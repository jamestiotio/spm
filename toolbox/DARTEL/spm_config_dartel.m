function job = spm_config_dartel
% Configuration file for DARTEL jobs
%_______________________________________________________________________
% Copyright (C) 2007 Wellcome Department of Imaging Neuroscience

% John Ashburner
% $Id$

if spm_matlab_version_chk('7') < 0,
    job = struct('type','const',...
                 'name','Need MATLAB 7 onwards',...
                 'tag','old_matlab',...
                 'val',...
          {{['This toolbox needs MATLAB 7 or greater.  '...
            'More recent MATLAB functionality has been used by this toolbox.']}});
    return;
end;

addpath(fullfile(spm('dir'),'toolbox','DARTEL'));
%_______________________________________________________________________

entry = inline(['struct(''type'',''entry'',''name'',name,'...
        '''tag'',tag,''strtype'',strtype,''num'',num)'],...
        'name','tag','strtype','num');

files = inline(['struct(''type'',''files'',''name'',name,'...
        '''tag'',tag,''filter'',fltr,''num'',num)'],...
        'name','tag','fltr','num');

mnu = inline(['struct(''type'',''menu'',''name'',name,'...
        '''tag'',tag,''labels'',{labels},''values'',{values})'],...
        'name','tag','labels','values');

branch = inline(['struct(''type'',''branch'',''name'',name,'...
        '''tag'',tag,''val'',{val})'],...
        'name','tag','val');

repeat = inline(['struct(''type'',''repeat'',''name'',name,''tag'',tag,'...
         '''values'',{values})'],'name','tag','values');
%_______________________________________________________________________




% IMPORTING IMAGES FOR USE WITH DARTEL
%------------------------------------------------------------------------
matname = files('Parameter Files','matnames','mat',[1 Inf]);
matname.ufilter = '.*seg_sn\.mat$';
matname.help = {...
['Select ''_sn.mat'' files containing the spatial transformation ',...
 'and segmentation parameters. '...
 'Rigidly aligned versions of the image that was segmented will '...
 'be generated. '...
 'The image files used by the segmentation may have moved. '...
 'If they have, then (so the import can find them) ensure that they are '...
 'either in the output directory, or the current working directory.']};
%------------------------------------------------------------------------
odir = files('Output Directory','odir','dir',[1 1]);
%odir.val = {'.'};
odir.help = {...
'Select the directory where the resliced files should be written.'};
%------------------------------------------------------------------------
bb      = entry('Bounding box','bb','e',[2 3]);
bb.val  = {ones(2,3)*NaN};
bb.help = {[...
'The bounding box (in mm) of the volume that is to be written ',...
'(relative to the anterior commissure). '...
'Non-finite values will be replaced by the bounding box of the tissue '...
'probability maps used in the segmentation.']};
%------------------------------------------------------------------------
vox      = entry('Voxel size','vox','e',[1 1]);
vox.val  = {1.5};
vox.help = {...
['The (isotropic) voxel sizes of the written images. '...
 'A non-finite value will be replaced by the average voxel size of '...
 'the tissue probability maps used by the segmentation.']};
%------------------------------------------------------------------------
orig = mnu('Image option','image',...
    {'Original','Bias Corrected','Skull-Stripped','Bias Corrected and Skull-stripped','None'},...
    {1,3,5,7,0});
orig.val  = {7};
orig.help = {...
['A resliced version of the original image can be produced, which may have '...
 'various procedures applied to it.  All options will rescale the images so '...
 'that the mean of the white matter intensity is set to one. '...
 'The ``skull stripped'''' versions are the images simply scaled by the sum '...
 'of the grey and white matter probabilities.']};
%------------------------------------------------------------------------
grey = mnu('Grey Matter','GM',{'Yes','No'},{1,0});
grey.val = {1};
grey.help = {'Produce a resliced version of this tissue class?'};
%------------------------------------------------------------------------
white = mnu('White Matter','WM',{'Yes','No'},{1,0});
white.val = {1};
white.help = grey.help;
%------------------------------------------------------------------------
csf = mnu('CSF','CSF',{'Yes','No'}, {1,0});
csf.val = {0};
csf.help = grey.help;
%------------------------------------------------------------------------
initial = branch('Initial Import','initial',{matname,odir,bb,vox,orig,grey,white,csf});
initial.help   = {[...
'Images first need to be imported into a form that DARTEL can work with. '...
'This involves taking the results of the segmentation (*_seg_sn.mat)/* \cite{ashburner05} */, '...
'in order to have rigidly aligned tissue class images. '...
'Typically, there would be imported grey matter and white matter images, '...
'but CSF images can also be included. '...
'The subsequent DARTEL alignment will then attempt to nonlinearly register '...
'these tissue class images together.']};
initial.prog   = @spm_dartel_import;
initial.vfiles = @vfiles_initial_import;
%------------------------------------------------------------------------




% RUNNING DARTEL TO MATCH A COMMON MEAN TO THE INDIVIDUAL IMAGES
%------------------------------------------------------------------------
iits = mnu('Inner Iterations','its',...
    {'1','2','3','4','5','6','7','8','9','10'},...
    {1,2,3,4,5,6,7,8,9,10});
iits.val = {3};
iits.help = {[...
'The number of Gauss-Newton iterations to be done within this '...
'outer iteration. After this, new average(s) are created, '...
'which the individual images are warped to match.']};
%------------------------------------------------------------------------
template = files('Template','template','nifti',[1 1]);
template.val = {};
template.help = {[...
'Select template. Smoother templates should be used '...
'for the early iterations. '...
'Note that the template should be a 4D file, with the 4th dimension '...
'equal to the number of sets of images.']};
%------------------------------------------------------------------------
rparam = entry('Reg params','rparam','e',[1 3]);
rparam.val = {[0.1 0.01 0.001]};
rparam.help = {...
['For linear elasticity, the parameters are mu, lambda and id. ',...
 'For membrane and bending energy, the parameters are lambda, unused and id.',...
 'id is a term for penalising absolute displacements, '...
 'and should therefore be small.'],...
['Use more regularisation for the early iterations so that the deformations '...
 'are smooth, and then use less for the later ones so that the details can '...
 'be better matched.']};
%------------------------------------------------------------------------
K = mnu('Time Steps','K',{'1','2','4','8','16','32','64','128','256','512'},...
    {0,1,2,3,4,5,6,7,8,9});
K.val = {6};
K.help = {...
['The number of time points used for solving the '...
 'partial differential equations.  A single time point would be '...
 'equivalent to a small deformation model. '...
 'Smaller values allow faster computations, but are less accurate in terms '...
 'of inverse consistancy and may result in the one-to-one mapping '...
 'breaking down.  Earlier iteration could use fewer time points, '...
 'but later ones should use about 64 '...
 '(or fewer if the deformations are very smooth).']};
%------------------------------------------------------------------------
slam = mnu('Smoothing Parameter','slam',{'None','0.5','1','2','4','8','16','32'},...
       {0,0.5,1,2,4,8,16,32});
slam.val = {1};
slam.help = {...
['A LogOdds parameterisation of the template is smoothed using a multigrid '...
 'scheme.  The amount of smoothing is determined by this parameter.']};
%------------------------------------------------------------------------
lmreg = entry('LM Regularisation','lmreg','e',[1 1]);
lmreg.val = {0.01};
lmreg.help = {...
['Levenberg-Marquardt regularisation.  Larger values increase the '...
 'the stability of the optimisation, but slow it down.  A value of '...
 'zero results in a Gauss-Newton strategy, but this is not recomended '...
 'as it may result in instabilities in the FMG.']};
%------------------------------------------------------------------------
cycles = mnu('Cycles','cyc',{'1','2','3','4','5','6','7','8'},...
    {1,2,3,4,5,6,7,8});
cycles.val = {3};
cycles.help = {[...
'Number of cycles used by the full multigrid matrix solver. '...
'More cycles result in higher acuracy, but slow down the algorithm. '...
'See Numerical Recipes for more information on multigrid methods.']};
%------------------------------------------------------------------------
its = mnu('Iterations','its',{'1','2','3','4','5','6','7','8'},...
    {1,2,3,4,5,6,7,8});
its.val = {3};
its.help = {[...
'Number of relaxation iterations performed in each multigrid cycle. '...
'More iterations are needed if using ``bending energy'''' regularisation, '...
'because the relaxation scheme only runs very slowly. '...
'See the chapter on solving partial differential equations in '...
'Numerical Recipes for more information about relaxation methods.']};
%------------------------------------------------------------------------
fmg = branch('Optimisation Settings','optim',{lmreg,cycles,its});
fmg.help = {[...
'Settings for the optimisation.  If you are unsure about them, '...
'then leave them at the default values.  '...
'Optimisation is by repeating a number of Levenberg-Marquardt '...
'iterations, in which the equations are solved using a '...
'full multi-grid (FMG) scheme. '...
'FMG and Levenberg-Marquardt are both described in '...
'Numerical Recipes (2nd edition).']};
%------------------------------------------------------------------------
param = branch('Outer Iteration','param',{iits,rparam,K,slam});
param.help = {...
['Different parameters can be specified for each '...
 'outer iteration. '...
 'Each of them warps the images to the template, and then regenerates '...
 'the template from the average of the warped images. '...
 'Multiple outer iterations should be used for more accurate results, '...
 'beginning with a more coarse registration (more regularisation) '...
 'then ending with the more detailed registration (less regularisation).']};
%------------------------------------------------------------------------
params = repeat('Outer Iterations','param',{param});
params.help = {[...
'The images are averaged, and each individual image is warped to '...
'match this average.  This is repeated a number of times.']};
params.num = [1 Inf];

param.val{1}.val{1} = 3; % iits
param.val{2}.val{1} = [4 2 1e-6]; % rparam
param.val{3}.val{1} = 0; % K
param.val{4}.val{1} = 16;
params.val{1} = param;
param.val{1}.val{1} = 3; % iits
param.val{2}.val{1} = [2 1 1e-6]; % rparam
param.val{3}.val{1} = 0; % K
param.val{4}.val{1} = 8;
params.val{2} = param;
param.val{1}.val{1} = 3; % iits
param.val{2}.val{1} = [1 0.5 1e-6]; % rparam
param.val{3}.val{1} = 0; % K
param.val{4}.val{1} = 4;
params.val{3} = param;
param.val{1}.val{1} = 3; % iits
param.val{2}.val{1} = [0.5 0.25 1e-6]; % rparam
param.val{3}.val{1} = 2; % K
param.val{4}.val{1} = 2;
params.val{4} = param;
param.val{1}.val{1} = 3; % iits
param.val{2}.val{1} = [0.25 0.125 1e-6]; % rparam
param.val{3}.val{1} = 4; % K
param.val{4}.val{1} = 1;
params.val{5} = param;
param.val{1}.val{1} = 3; % iits
param.val{2}.val{1} = [0.125 0.0625 1e-6]; % rparam
param.val{3}.val{1} = 6; % K
param.val{4}.val{1} = 0.5;
params.val{6} = param;

%------------------------------------------------------------------------
data = files('Images','images','image',[1 Inf]);
data.ufilter = '^r.*';
data.help = {...
['Select a set of imported images of the same type '...
 'to be registered by minimising '...
 'a measure of difference from the template.']};
%------------------------------------------------------------------------
data = repeat('Images','images',{data});
data.num = [1 Inf];
data.help = {...
['Select the images to be warped together. '...
 'Multiple sets of images can be simultaneously registered. '...
 'For example, the first set may be a bunch of grey matter images, '...
 'and the second set may be the white matter images of the same subjects.']};
%------------------------------------------------------------------------
code      = mnu('Objective function','code',{'Sum of squares','Multinomial'},{0,2});
code.val  = {2};
code.help = {...
['The objective function of the registration is specified here. '...
 'Multinomial is preferred for matching binary images to an average tissue probability map. '...
 'Sums of squares is more appropriate for regular images.']};
%------------------------------------------------------------------------
form  = mnu('Regularisation Form','rform',...
    {'Linear Elastic Energy','Membrane Energy','Bending Energy'},{0,1,2});
form.val = {0};
form.help = {[...
'The registration is penalised by some ``energy'''' term.  Here, the form '...
'of this energy term is specified. '...
'Three different forms of regularisation can currently be used.']};
%------------------------------------------------------------------------
settings  = branch('Settings','settings',{code,form,params,fmg});
settings.help = {[...
'Various settings for the optimisation. '...
'The default values should work reasonably well for aligning tissue '...
'class images together.']};
%------------------------------------------------------------------------
warp = branch('Run DARTEL (create Templates)','warp',{data,settings});
warp.prog   = @spm_dartel_template;
warp.check  = @check_runjob;
warp.vfiles = @vfiles_runjob;
warp.help   = {[...
'Run the DARTEL nonlinear image registration procedure. '...
'This involves iteratively matching all the selected images to '...
'a template generated from their own mean. '...
'A series of Template*.nii files are generated, which become increasingly '...
'crisp as the registration proceeds. '...
'/* An example is shown in figure \ref{Fig:averages}.'...
'\begin{figure} '...
'\begin{center} '...
'\epsfig{file=averages,width=140mm} '...
'\end{center} '...
'\caption{ '...
'This figure shows the intensity averages of grey (left) and '...
'white (right) matter images after different numbers of iterations. '...
'The top row shows the average after initial rigid-body alignment. '...
'The middle row shows the images after three iterations, '...
'and the bottom row shows them after 18 iterations. '...
'\label{Fig:averages}} '...
'\end{figure}*/']};
%------------------------------------------------------------------------




% RUNNING DARTEL TO MATCH A PRE-EXISTING TEMPLATE TO THE INDIVIDUALS
%------------------------------------------------------------------------
params1  = params;
params1.help = {[...
'The images are warped to match a sequence of templates. '...
'Early iterations should ideally use smoother templates '...
'and more regularisation than later iterations.']};
params1.values{1}.val{4} = template;
hlp = {[...
'Different parameters and templates can be specified '...
'for each outer iteration.']};
hlp1={[...
'The number of Gauss-Newton iterations to be done '...
'within this outer iteration.']};
params1.values{1}.help        = hlp;
params1.values{1}.val{1}.help = hlp1;
for i=1:numel(params1.val),
    params1.val{i}.val{4}      = template;
    params1.val{i}.val{1}.help = hlp1;
    params1.val{i}.help        = hlp;
end
settings1 = settings;
settings1.val{3} = params1;
warp1        = branch('Run DARTEL (existing Templates)','warp1',{data,settings1});
warp1.prog   = @spm_dartel_warp;
warp1.check  = @check_runjob;
warp1.vfiles = @vfiles_runjob1;
warp1.help   = {[...
'Run the DARTEL nonlinear image registration procedure to match '...
'individual images to pre-existing template data. '...
'Start out with smooth templates, and select crisp templates for '...
'the later iterations.']};




% WARPING IMAGES TO MATCH TEMPLATES
%------------------------------------------------------------------------
K = mnu('Time Steps','K',{'1','2','4','8','16','32','64','128','256','512'},...
    {0,1,2,3,4,5,6,7,8,9});
K.val = {6};
K.help = {...
['The number of time points used for solving the '...
 'partial differential equations.  Note that Jacobian determinants are not '...
 'very accurate for very small numbers of time steps (less than about 16).']};
%------------------------------------------------------------------------
%------------------------------------------------------------------------
ffields = files('Flow fields','flowfields','nifti',[1 Inf]);
ffields.ufilter = '^u_.*';
ffields.help = {...
['The flow fields store the deformation information. '...
 'The same fields can be used for both forward or backward deformations '...
 '(or even, in principle, half way or exaggerated deformations).']};
%------------------------------------------------------------------------
data = files('Images','images','nifti',[1 Inf]);
data.help = {...
['Select images to be warped. Note that there should be the same number '...
 'of images as there are flow fields, such that each flow field '...
 'warps one image.']};
%------------------------------------------------------------------------
data = repeat('Images','images',{data});
data.num = [1 Inf];
data.help = {...
['The flow field deformations can be applied to multiple images. '...
 'At this point, you are chosing how many images each flow field '...
 'should be applied to.']};
%------------------------------------------------------------------------
interp.type = 'menu';
interp.name = 'Interpolation';
interp.tag  = 'interp';
interp.labels = {'Nearest neighbour','Trilinear','2nd Degree B-spline',...
'3rd Degree B-Spline ','4th Degree B-Spline ','5th Degree B-Spline',...
'6th Degree B-Spline','7th Degree B-Spline'};
interp.values = {0,1,2,3,4,5,6,7};
interp.val = {1};
interp.help = {...
['The method by which the images are sampled when being written in a ',...
'different space.'],...
['    Nearest Neighbour: ',...
'    - Fastest, but not normally recommended.'],...
['    Bilinear Interpolation: ',...
'    - OK for PET, or realigned fMRI.'],...
['    B-spline Interpolation: ',...
'    - Better quality (but slower) interpolation/* \cite{thevenaz00a}*/, especially ',...
'      with higher degree splines.  Do not use B-splines when ',...
'      there is any region of NaN or Inf in the images. '],...
};
%------------------------------------------------------------------------
jactransf = mnu('Modulation','jactransf',...
    {'No modulation','Modulation','Sqrt Modulation'},...
    {0,1,0.5});
jactransf.val = {0};
jactransf.help = {...
['This allows the spatiallly normalised images to be rescaled by the '...
 'Jacobian determinants of the deformations. '...
 'Note that the rescaling is only approximate for deformations generated '...
 'using smaller numbers of time steps. '...
 'The square-root modulation is for special applications, so can be '...
 'ignored in most cases.']};
%------------------------------------------------------------------------
nrm = branch('Create Warped','crt_warped',{ffields,data,jactransf,K,interp});
nrm.prog   = @spm_dartel_norm;
nrm.check  = @check_norm;
nrm.vfiles = @vfiles_norm;
nrm.help = {...
['This allows spatially normalised images to be generated. '...
 'Note that voxel sizes and bounding boxes can not be adjusted, '...
 'and that there may be strange effects due to the boundary conditions used '...
 'by the warping. '...
 'Also note that the warped images are not in Talairach or MNI space. '...
 'The coordinate system is that of the average shape and size of the '...
 'subjects to which DARTEL was applied. '...
 'In order to have MNI-space normalised images, then the Deformations '...
 'Utility can be used to compose the individual DARTEL warps, '...
 'with a deformation field that matches (e.g.) the Template grey matter '...
 'generated by DARTEL, with one of the grey matter volumes '...
 'released with SPM.']};
%------------------------------------------------------------------------




% GENERATING JACOBIAN DETERMINANT FIELDS
%------------------------------------------------------------------------
jac = branch('Jacobian determinants','jacdet',{ffields,K});
jac.help   = {'Create Jacobian determinant fields from flowfields.'};
jac.prog   = @spm_dartel_jacobian;
jac.vfiles = @vfiles_jacdet;



% WARPING TEMPLATES TO MATCH IMAGES
%------------------------------------------------------------------------
data = files('Images','images','nifti',[1 Inf]);
data.help = {...
['Select the image(s) to be inverse normalised.  '...
 'These should be in alignment with the template image generated by the '...
 'warping procedure.']};
%------------------------------------------------------------------------
inrm = branch('Create Inverse Warped','crt_iwarped',{ffields,data,K,interp});
inrm.prog   = @spm_dartel_invnorm;
inrm.vfiles = @vfiles_invnorm;
inrm.help = {...
['Create inverse normalised versions of some image(s). '...
 'The image that is inverse-normalised should be in alignment with the '...
 'template (generated during the warping procedure). '...
 'Note that the results have the same dimensions as the ``flow fields'''', '...
 'but are mapped to the original images via the affine transformations '...
 'in their headers.']};
%------------------------------------------------------------------------



% KERNEL UTILITIES FOR PATTERN RECOGNITION
%------------------------------------------------------------------------
templ   = files('Template','template','nifti',[0 1]);
templ.ufilter = '^Template.*';
templ.help = {[...
    'Residual differences are computed between the '...
    'warped images and template, and these are scaled by '...
    'the square root of the Jacobian determinants '...
    '(such that the sum of squares is the same as would be '...
    'computed from the difference between the warped template '...
    'and individual images).']};
%------------------------------------------------------------------------
data = files('Images','images','nifti',[1 Inf]);
data.ufilter = '^r.*c';
data.help = {'Select tissue class images (one per subject).'};

%------------------------------------------------------------------------
data = repeat('Images','images',{data});
data.num = [1 Inf];
data.help = {...
['Multiple sets of images are used here. '...
 'For example, the first set may be a bunch of grey matter images, '...
 'and the second set may be the white matter images of the '...
 'same subjects.  The number of sets of images must be the same '...
 'as was used to generate the template.']};

fwhm = mnu('Smoothing','fwhm',{'None',' 2mm',' 4mm',' 6mm',' 8mm','10mm','12mm','14mm','16mm'},{0,2,4,6,8,10,12,14,16});
fwhm.val  = {4};
fwhm.help = {[...
'The residuals can be smoothed with a Gaussian to reduce dimensionality. '...
'More smoothing is recommended if there are fewer training images.']};

flowfields = files('Flow fields','flowfields','nifti',[1 Inf]);
flowfields.ufilter = '^u_.*';
flowfields.help = {...
    'Select the flow fields for each subject.'};
res     = branch('Generate Residuals','resids',{data,flowfields,templ,K,fwhm});
res.help = {[...
    'Generate residual images in a form suitable for computing a '...
    'Fisher kernel. In principle, a Gaussian Process model can '...
    'be used to determine the optimal (positive) linear combination '...
    'of kernel matrices.  The idea would be to combine the kernel '...
    'from the residuals, with a kernel derived from the flow-fields. '...
    'Such a combined kernel should then encode more relevant information '...
    'than the individual kernels alone.']};
res.prog   = @spm_dartel_resids;
res.check  = @check_resids;
res.vfiles = @vfiles_resids;
%------------------------------------------------------------------------
lam = entry('Reg param','rparam','e',[1 1]);
lam.val = {0.1};
logodds = branch('Generate LogOdds','LogOdds',{data,flowfields,K,lam});
logodds.help = {'See Kilian Pohl''s recent work.'};
logodds.prog = @spm_dartel_logodds;

%------------------------------------------------------------------------
data = files('Data','images','nifti',[1 Inf]);
data.help = {'Select images to generate dot-products from.'};
kname = entry('Dot-product Filename','dotprod','s',[1,Inf]);
kname.help = {['Enter a filename for results (it will be prefixed by '...
    '``dp_'''' and saved in the current directory.']};
reskern = branch('Kernel from Resids','reskern',{data,kname});
reskern.help = {['Generate a kernel matrix from residuals. '...
    'In principle, this same function could be used for generating '...
    'kernels from any image data (e.g. ``modulated'''' grey matter). '...
    'If there is prior knowledge about some region providing more '...
    'predictive information (e.g. the hippocampi for AD), '...
    'then it is possible to weight the generation of the kernel '...
    'accordingly.  You''ll need to write your own code to do this though, '...
    'as this function does not allow that (yet). '...
    'The matrix of dot-products is saved in a variable ``Phi'''', '...
    'which can be loaded from the dp_*.mat file. '...
    'The ``kernel trick'''' can be used to convert these dot-products '...
    'into distance measures for e.g. radial basis-function approaches.']};
reskern.prog = @spm_dartel_dotprods;
%------------------------------------------------------------------------
flowfields = files('Flow fields','flowfields','nifti',[1 Inf]);
flowfields.ufilter = '^u_.*';
flowfields.help = {'Select the flow fields for each subject.'};
kname = entry('Dot-product Filename','dotprod','s',[1,Inf]);
kname.help = {['Enter a filename for results (it will be prefixed by '...
    '``dp_'''' and saved in the current directory.']};
rform  = mnu('Regularisation Form','rform',...
    {'Linear Elastic Energy','Membrane Energy','Bending Energy'},{0,1,2});
rform.val = {0};
rform.help = {[...
'The registration is penalised by some ``energy'''' term.  Here, the '...
'form of this energy term is specified. '...
'Three different forms of regularisation can currently be used.']};
rparam = entry('Reg params','rparam','e',[1 3]);
rparam.val = {[0.25 0.125 1e-6]};
rparam.help = {...
['For linear elasticity, the parameters are `mu'', `lambda'' and `id''. ',...
 'For membrane and bending energy, '...
 'the parameters are `lambda'', unused and `id''. ',...
 'The term `id'' is for penalising absolute displacements, '...
 'and should therefore be small.']};
flokern = branch('Kernel from Flows' ,'flokern',{flowfields,rform,rparam,kname});
flokern.help = {['Generate a kernel from flow fields. '...
    'The dot-products are saved in a variable ``Phi'''' '...
    'in the resulting dp_*.mat file.']};
flokern.prog = @spm_dartel_kernel;
%------------------------------------------------------------------------
kernfun = repeat('Kernel Utilities','kernfun',{res,reskern,flokern});
kernfun.help = {[...
    'DARTEL can be used for generating Fisher kernels for '...
    'various kernel pattern-recognition procedures. '...
    'The idea is to use both the flow fields and residuals '...
    'to generate two seperate Fisher kernels (see the work of '...
    'Jaakkola and Haussler for more information). '...
    'Residual images need first to be generated in order to compute '...
    'the latter kernel, prior to the dot-products being computed.'],[...
    'The idea of applying pattern-recognition procedures is to obtain '...
    'a multi-variate characterisation of the anatomical differences among '...
    'groups of subjects. These characterisations can then be used to '...
    'separate (eg) healthy individuals from particular patient populations. '...
    'There is still a great deal of methodological work to be done, '...
    'so the types of kernel that can be generated here are unlikely to '...
    'be the definative ways of proceeding.  They are only just a few ideas '...
    'that may be worth trying out. '...
    'The idea is simply to attempt a vaguely principled way to '...
    'combine generative models with discriminative models '...
    '(see the ``Pattern Recognition and Machine Learning'''' book by '...
    'Chris Bishop for more ideas). Better ways (higher predictive accuracy) '...
    'will eventually emerge.'],[...
    'Various pattern recognition algorithms are available freely over the '...
    'internet. Possible approaches include Support-Vector Machines, '...
    'Relevance-Vector machines and Gaussian Process Models. '...
    'Gaussian Process Models probably give the most accurate probabilistic '...
    'predictions, and allow kernels generated from different pieces of '...
    'data to be most easily combined.']};





% THE ENTRY POINT FOR DARTEL STUFF
%------------------------------------------------------------------------
job = repeat('DARTEL Tools','dartel',{initial,warp,warp1,nrm,jac,inrm,kernfun});
job.help = {...
['This toolbox is based around the ``A Fast Diffeomorphic Registration '...
 'Algorithm'''' paper /* \cite{ashburner07} */. '...
 'The idea is to register images by computing a ``flow field'''', '...
 'which can then be ``exponentiated'''' to generate both forward and '...
 'backward deformations. '...
 'Currently, the software only works with images that have isotropic '...
 'voxels, identical dimensions and which are in approximate alignment '...
 'with each other. '...
 'One of the reasons for this is that the approach assumes circulant '...
 'boundary conditions, which makes modelling global rotations impossible. '...
 'Another reason why the images should be approximately aligned is because '...
 'there are interactions among the transformations that are minimised by '...
 'beginning with images that are already almost in register. '...
 'This problem could be alleviated by a time varying flow field, '...
 'but this is currently computationally impractical.'],...
['Because of these limitations, images should first be imported. '...
 'This involves taking the ``*_seg_sn.mat'''' files produced by the segmentation '...
 'code of SPM5, and writing out rigidly transformed versions of '...
 'the tissue class images, '...
 'such that they are in as close alignment as possible with the tissue '...
 'probability maps. '...
 'Rigidly transformed original images can also be generated, '...
 'with the option to have skull-stripped versions.'],...
['The next step is the registration itself.  This can involve matching '...
 'single images together, or it can involve the simultaneous registration '...
 'of e.g. GM with GM, WM with WM and 1-(GM+WM) with 1-(GM+WM) '...
 '(when needed, the 1-(GM+WM) class is generated implicitly, so there is '...
 'no need to include this class yourself). '...
 'This procedure begins by creating a mean of all the images, '...
 'which is used as an initial template. '...
 'Deformations from this template to each of the individual images '...
 'are computed, and the template is then re-generated by applying '...
 'the inverses of the deformations to the images and averaging. '... 
 'This procedure is repeated a number of times.'],...
['Finally, warped versions of the images (or other images that are '...
 'in alignment with them) can be generated. '],[],[...
 'This toolbox is not yet seamlessly integrated into the SPM package. '...
 'Eventually, the plan is to use many of the ideas here as the default '...
 'strategy for spatial normalisation. The toolbox may change with future '...
 'updates.  There will also be a number of '...
 'other (as yet unspecified) extensions, which may include '...
 'a variable velocity version (related to LDDMM). '...
 'Note that the Fast Diffeomorphism paper only describes a sum of squares '...
 'objective function. '...
 'The multinomial objective function is an extension, '...
 'based on a more appropriate model for aligning binary data to a template.']};

return;
%_______________________________________________________________________

%_______________________________________________________________________
function vf = vfiles_initial_import(job)
opt  = [job.GM, job.WM, job.CSF];
odir = job.odir{1};
matnames = job.matnames;

vf = {};
for i=1:numel(matnames),
    vf1 = {};
    [pth,nam,ext] = fileparts(matnames{i});
    nam = nam(1:(numel(nam)-7));
    if job.image,
        fname = fullfile(odir,['r',nam, '.nii' ',1']);
        vf1   = {fname};
    end
    for k1=1:numel(opt),
        if opt(k1),
            fname   = fullfile(odir,['r','c', num2str(k1), nam, '.nii' ',1']);
            vf1     = {vf1{:},fname};
        end
    end
    vf = {vf{:},vf1{:}};
end
%_______________________________________________________________________

%_______________________________________________________________________
function chk = check_runjob(job)
n1 = numel(job.images);
n2 = numel(job.images{1});
chk = '';
for i=1:n1,
    if numel(job.images{i}) ~= n2,
        chk = 'Incompatible number of images';
        break;
    end;
end;
%_______________________________________________________________________

%_______________________________________________________________________
function vf = vfiles_runjob(job)
vf = {};
n1 = numel(job.images);
n2 = numel(job.images{1});
[tdir,nam,ext] = fileparts(job.images{1}{1});
for it=0:numel(job.settings.param),
    fname    = fullfile(tdir,['Template' num2str(it) '.nii' ',1']);
    vf       = {vf{:},fname};
end
for j=1:n2,
    [pth,nam,ext,num] = spm_fileparts(job.images{1}{j});
    fname             = fullfile(pth,['u_' nam '.nii' ',1']);
    vf = {vf{:},fname};
end;
%_______________________________________________________________________

%_______________________________________________________________________
function vf = vfiles_runjob1(job)
vf = {};
n1 = numel(job.images);
n2 = numel(job.images{1});
for j=1:n2,
    [pth,nam,ext,num] = spm_fileparts(job.images{1}{j});
    fname             = fullfile(pth,['u_' nam '.nii' ',1']);
    vf = {vf{:},fname};
end;
%_______________________________________________________________________

%_______________________________________________________________________
function chk = check_norm(job)
chk = '';
PU = job.flowfields;
PI = job.images;
n1 = numel(PU);
for i=1:numel(PI),
    if numel(PI{i}) ~= n1,
        chk = 'Incompatible number of images';
        break;
    end
end
%_______________________________________________________________________

%_______________________________________________________________________
function vf = vfiles_norm(job)
vf = {};
PU = job.flowfields;
PI = job.images;
jactransf = job.jactransf;

for i=1:numel(PU),
    for m=1:numel(PI),
        [pth,nam,ext,num] = spm_fileparts(PI{m}{i});
        if jactransf,
            fname = fullfile(pth,['mw' nam ext ',1']);
        else
            fname = fullfile(pth,['w' nam ext ',1']);
        end;
        vf = {vf{:},fname};
    end
end
%_______________________________________________________________________

%_______________________________________________________________________
function vf = vfiles_invnorm(job)
vf = {};
PU    = job.flowfields;
PI    = job.images;
for i=1:numel(PU),
    [pth1,nam1,ext1,num1] = spm_fileparts(PU{i});
    for m=1:numel(PI),
        [pth2,nam2,ext2,num2] = spm_fileparts(PI{m});
        fname = fullfile(pth1,['w' nam2 '_' nam1 ext2 ',1']);
        vf = {vf{:},fname};
    end
end
%_______________________________________________________________________

%_______________________________________________________________________
function vf = vfiles_jacdet(job)
vf = {};
PU = job.flowfields;
for i=1:numel(PU),
    [pth,nam,ext] = fileparts(PU{i});
    fname = fullfile(pth,['jac_' nam(3:end) ext ',1']);
    vf    = {vf{:},fname};
end;
%_______________________________________________________________________

%_______________________________________________________________________
function chk = check_resids(job)
chk = '';
PU = job.flowfields;
PI = job.images;
n1 = numel(PU);
for i=1:numel(PI),
    if numel(PI{i}) ~= n1,
        chk = 'Incompatible number of images';
        break;
    end
end
%_______________________________________________________________________

%_______________________________________________________________________
function vf = vfiles_resids(job)
vf = {};
PI = job.images{1};
for i=1:numel(PI),
    [pth,nam,ext] = fileparts(PI{i});
    fname = fullfile(pwd,['resid_' nam '.nii',',1']);
    vf    = {vf{:},fname};
end
%_______________________________________________________________________




