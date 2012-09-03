function varargout = spm_select(varargin)
% File selector
% FORMAT [t,sts] = spm_select(n,typ,mesg,sel,wd,filt,frames)
% n      - number of files [Default: Inf)
%          A single value or a range.  e.g.
%          1       - Select one file
%          Inf     - Select any number of files
%          [1 Inf] - Select 1 to Inf files
%          [0 1]   - select 0 or 1 files
%          [10 12] - select from 10 to 12 files
% typ    - file type [Default: 'any']
%          'any'   - all files
%          'image' - Image files (".img" and ".nii")
%                    Note that it gives the option to select
%                    individual volumes of the images.
%          'mesh'  - Surface mesh files (".gii" or ".mat")
%          'xml'   - XML files
%          'mat'   - MATLAB .mat files or .txt files (assumed to contain
%                    ASCII representation of a 2D-numeric array)
%          'batch' - SPM batch files (.m, .mat and XML)
%          'dir'   - select a directory
%          Other strings act as a filter to regexp. This means that
%          e.g. DCM*.mat files should have a typ of '^DCM.*\.mat$'
% mesg   - a prompt [Default: 'Select files...']
% sel    - list of already selected files [Default: {}]
% wd     - directory to start off in [Default: pwd]
% filt   - value for user-editable filter [Default: '.*']
% frames - image frame numbers to include [Default: '1']
%
% t      - selected files
% sts    - status (1 means OK, 0 means window quit)
%
% FORMAT cpath = spm_select('CPath',path,cwd)
% Canonicalise paths: prepend cwd to relative paths, process '..' & '.'
% directories embedded in path.
% path   - string matrix containing path name
% cwd    - current working directory [default '.']
% cpath  - canonicalised paths, in same format as input path argument
%
% FORMAT [files,dirs] = spm_select('List',direc,filt)
% Return files matching the filter 'filt' and directories within 'direc'
% direc  - directory to search
% filt   - filter to select files with (see regexp) e.g. '^w.*\.img$'
% files  - files matching 'filt' in directory 'direc'
% dirs   - subdirectories of 'direc'
%
% FORMAT [files,dirs] = spm_select('ExtList',direc,filt,frames)
% As above, but for selecting frames of 4D NIfTI files
% frames - vector of frames to select (defaults to 1, if not
%            specified). If the frame number is Inf, all frames for the
%            matching images are listed. 
%
% FORMAT [files,dirs] = spm_select('FPList',direc,filt)
% FORMAT [files,dirs] = spm_select('ExtFPList',direc,filt,frames)
% As above, but return files with full paths (i.e. prefixes 'direc' to each)
%
% FORMAT [files,dirs] = spm_select('FPListRec',direc,filt)
% FORMAT [files,dirs] = spm_select('ExtFPListRec',direc,filt,frames)
% As above, but return files with full paths (i.e. prefixes 'direc' to
% each) and search through sub directories recursively.
%__________________________________________________________________________
%
% For developers:
%
% FORMAT [t,ind] = spm_select('Filter',files,typ,filt,frames)
% filter the list of files (cell or char array) in the same way as the
% GUI would do. There is an additional typ 'extimage' which will match
% images with frame specifications, too. Also, there is a typ 'extdir',
% which will match canonicalised directory names. The 'frames' argument
% is currently ignored, i.e. image files will not be filtered out if
% their frame numbers do not match.
% t returns the filtered list (cell or char array, depending on input),
% ind an index array, such that t = files{ind}, or t = files(ind,:).
%
% FORMAT spm_select('prevdirs',dir)
% Add directory dir to list of previous directories.
% FORMAT dirs = spm_select('prevdirs')
% Retrieve list of previous directories.
%__________________________________________________________________________
% Copyright (C) 2005-2011 Wellcome Trust Centre for Neuroimaging

% John Ashburner
% $Id: spm_select.m 4886 2012-09-03 14:15:20Z volkmar $

if ~isdeployed && ~exist('cfg_getfile','file')
    addpath(fullfile(spm('dir'),'matlabbatch'));
end

% commands that are not passed to cfg_getfile
local_cmds = {'spm_regfilters'};

if ischar(varargin{1}) && any(strcmpi(varargin{1},local_cmds))
    switch lower(varargin{1})
        case 'spm_regfilters'
            % Regexp based filters without special handlers
            cfg_getfile('regfilter','mesh',{'\.gii$','\.mat$'});
            cfg_getfile('regfilter','gifti',{'\.gii$'});
            cfg_getfile('regfilter','nifti',{'\.nii$'});
            % Filter for 3D images that handles frame expansion
            frames = cfg_entry;
            frames.name    = 'Frames';
            frames.tag     = 'frames';
            frames.strtype = 'n';
            frames.num     = [1 Inf];
            frames.val     = {1};
            cfg_getfile('regfilter', 'image',...
                        {'.*\.nii(,\d+){0,2}$','.*\.img(,\d+){0,2}$'},...
                        false, @spm_select_image, {frames});
    end
else
    % cfg_getfile expects and returns cellstr arguments for multi-line strings
    if nargin > 0 && ischar(varargin{1}) && ...
            strcmpi(varargin{1},'filter') && ischar(varargin{2})
        varargin{2} = cellstr(varargin{2});
    end
    
    [t, sts] = cfg_getfile(varargin{:});
    
    % cfg_getfile returns cell arrays, convert to char arrays
    if nargin > 0 && ischar(varargin{1})
        switch lower(varargin{1})
            case {'filter','cpath'}
                if ischar(varargin{2})
                    t = char(t);
                end
            case {'list','fplist','extlist','extfplist'}
                t = char(t);
                sts = char(sts);
        end
    else
        t = char(t);
    end

    varargout{1} = t;
    if nargout > 1
        varargout{2} = sts;
    end
end
%--------------------------------------------------------------------------
% Local functions
%--------------------------------------------------------------------------
function varargout = spm_select_image(cmd, varargin)
% Implements extended filtering for NIfTI images (including 3D frame
% selection)
switch lower(cmd)
    case 'list'
        dr     = varargin{1};
        files  = varargin{2};
        prms   = varargin{3};
        frames = prms.frames;
        ii = cell(1,numel(files));
        if (numel(frames)~=1 || frames(1)~=1),
            %     if domsg
            %         msg(ob,['Reading headers of ' num2str(numel(f)) ' images...']);
            %     end
            for i=1:numel(files)
                try
                    ni = nifti(fullfile(dr,files{i}));
                    dm = [ni.dat.dim 1 1 1 1 1];
                    d4 = (1:dm(4))';
                catch
                    d4 = 1;
                end
                if all(isfinite(frames))
                    ii{i} = intersect(d4, frames);
                else
                    ii{i} = d4;
                end
            end
        elseif (numel(frames)==1 && frames(1)==1),
            [ii{:}] = deal(1);
        end

        %         if domsg
        %             msg(ob,['Listing ' num2str(numel(f)) ' files...']);
        %         end

        % Combine filename and frame number(s)
        nii      = cellfun(@numel, ii);
        cfiles   = cell(sum(nii),1);
        fi       = cell(numel(files),1);
        for k = 1:numel(fi)
            fi{k} = k*ones(1,nii(k));
        end
        ii = [ii{:}];
        fi = [fi{:}];
        for i=1:numel(cfiles),
            cfiles{i} = sprintf('%s,%d', files{fi(i)}, ii(i));
        end;
        varargout{1} = cfiles;
    case 'filter'
        % Do not filter for frame numbers
        varargout{1} = varargin{1};
        varargout{2} = 1:numel(varargout{1});
end
