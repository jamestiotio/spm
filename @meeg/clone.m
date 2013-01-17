function new = clone(this, fnamedat, dim, reset)
% Creates a copy of the object with a new, empty data file,
% possibly changing dimensions
% FORMAT new = clone(this, fnamedat, dim, reset)
% reset - 0 (default) do not reset channel or trial info unless dimensions
%          change, 1 - reset channels only, 2 - trials only, 3 both
% Note that when fnamedat comes with a path, the cloned meeg object uses
% it. Otherwise, its path is by definition that of the meeg object to be
% cloned.
% _________________________________________________________________________
% Copyright (C) 2008-2012 Wellcome Trust Centre for Neuroimaging

% Stefan Kiebel, Vladimir Litvak
% $Id: clone.m 5190 2013-01-17 15:32:45Z vladimir $

if nargin < 4
    reset = 0;
end

if nargin < 3
   dim = size(this);
end

% if number of channels is modified, throw away montages
if dim(1) ~= nchannels(this)
    this = montage(this,'remove',1:montage(this,'getnumber'));
    disp('Changing the number of channels, so discarding online montages.');
end

new = unlink(this);

% check file path first
[pth, fname] = fileparts(fnamedat);
if isempty(pth)
    pth = this.path;
end

newFileName = [fullfile(pth, fname),'.dat'];

% copy the file_array
d = this.data; % 
d.fname = newFileName;
dim_o = d.dim;

% This takes care of an issue specific to int data files which are not
% officially supported in SPM8.
if ~strncmpi(d.dtype, 'float', 5) && ...
        dim(1)>dim_o(1) && length(d.scl_slope)>1
    % adding channel and scl_slope defined -> need to increase scl_slope
    v_slope = mode(d.scl_slope);
    if length(v_slope)>1
        warning('Trying to guess the scaling factor for new channels. This might be wrong.');        
    end
    d.scl_slope = [d.scl_slope' ones(1,dim(1)-dim_o(1))*v_slope]';
end
d.dim = dim;

% physically initialise file
if length(dim) == 3
    d(end, end, end) = 0;
    nsampl = dim(2);
    ntrial = dim(3);
    new = transformtype(new, 'time');
elseif length(dim) == 4
    d(end, end, end, end) = 0;
    nsampl = dim(3);
    ntrial = dim(4);
    
    if ~strncmpi(transformtype(new), 'TF',2)
        new = transformtype(new, 'TF');
        % This assumes that the frequency axis will be set correctly after
        % cloning and is neccesary to avoid an inconsistent state
        new.transform.frequencies =  1:dim(2);
    end        
else
   error('Dimensions different from 3 or 4 are not supported.');
end

% change filenames
new.fname = [fname,'.mat'];
new.path = pth;

% ensure consistency 
if (dim(1) ~= nchannels(this)) || ismember(reset, [1 3])
    new.channels = [];
    for i = 1:dim(1)
        new.channels(i).label = ['Ch' num2str(i)];
    end
end

if ntrial ~= ntrials(this) || ismember(reset, [2 3])
    new.trials = repmat(struct('label', 'Undefined'), 1, ntrial);
end
    
if (nsampl ~= nsamples(this))
    new.Nsamples = nsampl;
end

new = check(new);

% link into new meeg object
new = link(new, d.fname, d.dtype, d.scl_slope, d.offset);

save(new);