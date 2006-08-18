function opts = spm_config_slice_timing
% configuration file for slice timing
%____________________________________________________________________
% Copyright (C) 2005 Wellcome Department of Imaging Neuroscience

% Darren Gitelman
% $Id: spm_config_slice_timing.m 595 2006-08-18 13:39:46Z volkmar $

% ---------------------------------------------------------------------
scans.type = 'files';
scans.name = 'Session';
scans.tag  = 'scans';
scans.filter = 'image';
scans.num  = [2 Inf];
scans.help = {'Select images to acquisition correct.'};
% ---------------------------------------------------------------------

data.type = 'repeat';
data.name = 'Data';
data.values = {scans};
data.num  = [1 Inf];
data.help = {[...
    'Subjects or sessions. The same parameters specified below will ',...
    'be applied to all sessions.']};

% ---------------------------------------------------------------------

nslices.type = 'entry';
nslices.name = 'Number of Slices';
nslices.tag  = 'nslices';
nslices.strtype = 'n';
nslices.num  = [1 1];
nslices.help = {'Enter the number of slices'};
% ---------------------------------------------------------------------

refslice.type = 'entry';
refslice.name = 'Reference Slice';
refslice.tag  = 'refslice';
refslice.strtype = 'n';
refslice.num  = [1 1];
refslice.help = {'Enter the reference slice'};
% ---------------------------------------------------------------------

TR.type = 'entry';
TR.name = 'TR';
TR.tag  = 'tr';
TR.strtype = 'r';
TR.num  = [1 1];
TR.help = {'Enter the TR in seconds'};
% ---------------------------------------------------------------------

TA.type = 'entry';
TA.name = 'TA';
TA.tag  = 'ta';
TA.strtype = 'e';
TA.num  = [1 1];
TA.help = {['The TA (in secs) must be entered by the user. ',...
    'It is usually calculated as TR-(TR/nslices). You can simply enter ',...
    'this equation with the variables replaced by appropriate numbers.']};

% ---------------------------------------------------------------------

sliceorder.type = 'entry';
sliceorder.name = 'Slice order';
sliceorder.tag = 'so';
sliceorder.strtype = 'e';
sliceorder.num = [1 Inf];
sliceorder.help = {...
['Enter the slice order. Bottom slice = 1. Sequence types ',...
 'and examples of code to enter are given below.'],...
 '',...
 'ascending (first slice=bottom): [1:1:nslices]',...
 '',...
 'descending (first slice=top): [nslices:-1:1]',...
 '',...
 'interleaved (middle-top):',...
 '    for k = 1:nslices,',...
 '        round((nslices-k)/2 + (rem((nslices-k),2) * (nslices - 1)/2)) + 1,',...
 '    end',...
 '',...
 'interleaved (bottom -> up): [1:2:nslices 2:2:nslices]',...
 '',...
 'interleaved (top -> down): [nslices:-2:1, nslices-1:-2:1]'};
 
% ---------------------------------------------------------------------

opts.type = 'branch';
opts.name = 'Slice Timing';
opts.tag  = 'st';
opts.val  = {data,nslices,TR,TA,sliceorder,refslice};
opts.prog = @slicetiming;
opts.vfiles = @vfiles;
opts.modality = {'FMRI'};
opts.help = {...
['Correct differences in image acquisition time between slices. '...
'Slice-time corrected files are prepended with an ''a''.'],...
'',...
['Note: The sliceorder arg that specifies slice acquisition order is '...
'a vector of N numbers, where N is the number of slices per volume. '...
'Each number refers to the position of a slice within the image file. '...
'The order of numbers within the vector is the temporal order in which '...
'those slices were acquired. '...
'To check the order of slices within an image file, use the SPM Display '...
'option and move the crosshairs to a voxel co-ordinate of z=1.  This '...
'corresponds to a point in the first slice of the volume.'],...
'',...
['The function corrects differences in slice acquisition times. '...
'This routine is intended to correct for the staggered order of '...
'slice acquisition that is used during echoplanar scanning. The '...
'correction is necessary to make the data on each slice correspond '...
'to the same point in time. Without correction, the data on one '...
'slice will represent a point in time as far removed as 1/2 the TR '...
'from an adjacent slice (in the case of an interleaved sequence).'],...
'',...
['This routine "shifts" a signal in time to provide an output '...
'vector that represents the same (continuous) signal sampled '...
'starting either later or earlier. This is accomplished by a simple '...
'shift of the phase of the sines that make up the signal. '...
'Recall that a Fourier transform allows for a representation of any '...
'signal as the linear combination of sinusoids of different '...
'frequencies and phases. Effectively, we will add a constant '...
'to the phase of every frequency, shifting the data in time.'],...
'',...
['Shifter - This is the filter by which the signal will be convolved '...
'to introduce the phase shift. It is constructed explicitly in '...
'the Fourier domain. In the time domain, it may be described as '...
'an impulse (delta function) that has been shifted in time the '...
'amount described by TimeShift. '...
'The correction works by lagging (shifting forward) the time-series '...
'data on each slice using sinc-interpolation. This results in each '...
'time series having the values that would have been obtained had '...
'the slice been acquired at the same time as the reference slice. '...
'To make this clear, consider a neural event (and ensuing hemodynamic '...
'response) that occurs simultaneously on two adjacent slices. Values '...
'from slice "A" are acquired starting at time zero, simultaneous to '...
'the neural event, while values from slice "B" are acquired one '...
'second later. Without corection, the "B" values will describe a '...
'hemodynamic response that will appear to have began one second '...
'EARLIER on the "B" slice than on slice "A". To correct for this, '...
'the "B" values need to be shifted towards the Right, i.e., towards '...
'the last value.'],...
'',...
['This correction assumes that the data are band-limited (i.e. there '...
'is no meaningful information present in the data at a frequency '...
'higher than that of the Nyquist). This assumption is support by '...
'the study of Josephs et al (1997, NeuroImage) that obtained '...
'event-related data at an effective TR of 166 msecs. No physio-'...
'logical signal change was present at frequencies higher than our '...
'typical Nyquist (0.25 HZ).'],...
'',...
['Written by Darren Gitelman at Northwestern U., 1998.  '...
'Based (in large part) on ACQCORRECT.PRO from Geoff Aguirre and '...
'Eric Zarahn at U. Penn.']};


% ---------------------------------------------------------------------

function slicetiming(varargin)
job = varargin{1};
Seq = job.so;
TR  = job.tr;
TA  = job.ta;
nslices   = job.nslices;
refslice  = job.refslice;
timing(2) = TR - TA;
timing(1) = TA / (nslices -1);

for i = 1:length(job.scans)
    P   = strvcat(job.scans{i});
    spm_slice_timing(P,Seq,refslice,timing)
end
return;
% ---------------------------------------------------------------------

% ---------------------------------------------------------------------
function vf = vfiles(varargin)
job = varargin{1};
vf  = cell(numel([job.scans{:}]),1);
n = 1;
for i=1:numel(job.scans),
    for j = 1:numel(job.scans{i})
    [pth,nam,ext,num] = spm_fileparts(job.scans{i}{j});
    vf{n} = fullfile(pth,['a', nam, ext, num]);
    n = n+1;
    end
end;
return;
% ---------------------------------------------------------------------

% ---------------------------------------------------------------------
