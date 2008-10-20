function [status] = hastoolbox(toolbox, autoadd, silent)

% HASTOOLBOX tests whether an external toolbox is installed. Optionally
% it will try to determine the path to the toolbox and install it
% automatically.
% 
% Use as
%   [status] = hastoolbox(toolbox, autoadd, silent)

% Copyright (C) 2005-2008, Robert Oostenveld
%
% $Log: hastoolbox.m,v $
% Revision 1.20  2008/10/20 16:31:15  roboos
% fixed problem in case with dash "-" in the directory
%
% Revision 1.19  2008/09/29 09:00:19  roboos
% implemented smart handling of previously seen toolboxes using a persistent variable
% this should speed up fieldtrip and fileio (e.g. read_data checks the presence of ctf for every trial)
%
% Revision 1.18  2008/09/24 15:43:00  roboos
% added read_data and read_sens for fileio, should solve problem for MEEGfileio in spm5
%
% Revision 1.17  2008/09/22 19:42:09  roboos
% added option for silent processing
%
% Revision 1.16  2008/08/11 16:11:19  roboos
% also automatically add to path for fieldtrip code and external modules
%
% Revision 1.15  2008/06/20 07:25:56  roboos
% added check for presence of BCI2000 load_bcidat mex file
%
% Revision 1.14  2008/05/15 10:52:29  roboos
% added ctf
%
% Revision 1.13  2008/03/17 08:29:40  roboos
% changed some contact addresses
%
% Revision 1.12  2008/03/14 10:20:29  roboos
% added denoise
%
% Revision 1.11  2008/03/05 10:59:14  roboos
% added fileio and forwinv
%
% Revision 1.10  2007/05/06 09:10:07  roboos
% added spm5
%
% Revision 1.9  2007/02/26 13:41:07  roboos
% made small change to fastica detection (suggested by Sameer)
%
% Revision 1.8  2007/02/13 17:22:27  roboos
% added MRI from eeg.sf.net
%
% Revision 1.7  2007/02/13 14:01:26  roboos
% added brainstorm
%
% Revision 1.6  2007/02/12 19:43:23  roboos
% added fastica, optim
%
% Revision 1.5  2007/01/17 17:05:34  roboos
% added matlab signal processing toolbox
%
% Revision 1.4  2007/01/04 12:25:19  roboos
% added SON2
%
% Revision 1.3  2007/01/03 17:01:15  roboos
% added 4d-version toolbox
%
% Revision 1.2  2006/06/07 10:48:02  roboos
% changed the "see xxx" string
%
% Revision 1.1  2006/06/07 09:28:41  roboos
% renamed fieldtrip/private/checktoolbox into misc/hastoolbox
%
% Revision 1.8  2006/06/06 14:18:22  roboos
% added neuroshare, eeprobe, yokogawa
%
% Revision 1.7  2006/05/31 08:56:24  roboos
% implemented detection of toolbox in users ~/matlab/toolboxname
%
% Revision 1.6  2006/05/23 10:20:46  roboos
% added beowulf and mentat toolboxes
%
% Revision 1.5  2006/04/26 11:37:22  roboos
% added besa toolbox
%
% Revision 1.4  2006/02/07 20:01:39  roboos
% aded biosig and meg-pd (neuromag)
%
% Revision 1.3  2006/01/17 14:05:54  roboos
% added GLNA64 for mentat000
%
% Revision 1.2  2006/01/06 11:39:23  roboos
% added copyrigth and cvs logging, changed some comments
%

% this function is called many times in FieldTrip and associated toolboxes
% use efficient handling if the same toolbox has been investigated before
persistent previous
if isempty(previous)
  previous = struct;
elseif isfield(previous, fixname(toolbox)) 
  status = previous.(fixname(toolbox));
  return
end

% this points the user to the website where he/she can download the toolbox
url = {
  'AFNI'       'see http://afni.nimh.nih.gov'
  'DSS'        'see http://www.cis.hut.fi/projects/dss'
  'EEGLAB'     'see http://www.sccn.ucsd.edu/eeglab'
  'NWAY'       'see http://www.models.kvl.dk/source/nwaytoolbox'
  'SPM2'       'see http://www.fil.ion.ucl.ac.uk/spm'
  'SPM5'       'see http://www.fil.ion.ucl.ac.uk/spm'
  'MEG-PD'     'see http://www.kolumbus.fi/kuutela/programs/meg-pd'
  'MEG-CALC'   'this is a commercial toolbox from Neuromag, see http://www.neuromag.com'
  'BIOSIG'     'see http://biosig.sourceforge.net'
  'EEG'        'see http://eeg.sourceforge.net'
  'EEGSF'      'see http://eeg.sourceforge.net'  % alternative name
  'MRI'        'see http://eeg.sourceforge.net'  % alternative name
  'NEUROSHARE' 'see http://www.neuroshare.org'
  'BESA'       'see http://www.megis.de, or contact Karsten Hoechstetter'
  'EEPROBE'    'see http://www.ant-neuro.com, or contact Maarten van der Velde'
  'YOKOGAWA'   'see http://www.yokogawa.co.jp, or contact Nobuhiko Takahashi'
  'BEOWULF'    'see http://oostenveld.net, or contact Robert Oostenveld'
  'MENTAT'     'see http://oostenveld.net, or contact Robert Oostenveld'
  'SON2'       'see http://www.kcl.ac.uk/depsta/biomedical/cfnr/lidierth.html, or contact Malcolm Lidierth' 
  '4D-VERSION' 'contact Christian Wienbruch'
  'SIGNAL'     'see http://www.mathworks.com/products/signal'
  'OPTIM'      'see http://www.mathworks.com/products/optim'
  'FASTICA'    'see http://www.cis.hut.fi/projects/ica/fastica'
  'BRAINSTORM' 'see http://neuroimage.ucs.edu/brainstorm'
  'FILEIO'     'see http://www2.ru.nl/fcdonders/fieldtrip/doku.php?id=fieldtrip:development:fileio'
  'FORWINV'    'see http://www2.ru.nl/fcdonders/fieldtrip/doku.php?id=fieldtrip:development:forwinv'
  'DENOISE'    'see http://lumiere.ens.fr/Audition/adc/meg, or contact Alain de Cheveigne'
  'BCI2000'    'see http://bci2000.org'
};

if nargin<2
  % default is not to add the path automatically
  autoadd = 0;
end

if nargin<3
  % default is not to be silent
  silent = 0;
end

% determine whether the toolbox is installed
toolbox = upper(toolbox);
switch toolbox
  case 'AFNI'
    status = (exist('BrikLoad') && exist('BrikInfo'));
  case 'DSS'
    status = exist('dss', 'file') && exist('dss_create_state', 'file');
  case 'EEGLAB'
    status = exist('runica', 'file');
  case 'NWAY'
    status = exist('parafac', 'file');
  case 'SPM2'
    status = exist('spm_vol') && exist('spm_write_vol') && exist('spm_normalise');
  case 'SPM5'
    status = exist('spm_vol') && exist('spm_write_vol') && exist('spm_normalise') && exist('spm_vol_nifti');
  case 'MEG-PD'
    status = (exist('rawdata') && exist('channames'));
  case 'MEG-CALC'
    status = (exist('megmodel') && exist('megfield') && exist('megtrans'));
  case 'BIOSIG'
    status = (exist('sopen') && exist('sread'));
  case 'EEG'
    status = (exist('ctf_read_res4') && exist('ctf_read_meg4'));
  case 'EEGSF'  % alternative name
    status = (exist('ctf_read_res4') && exist('ctf_read_meg4'));
  case 'MRI'    % other functions in the mri section
    status = (exist('avw_hdr_read') && exist('avw_img_read'));
  case 'NEUROSHARE'
    status  = (exist('ns_OpenFile') && exist('ns_SetLibrary') && exist('ns_GetAnalogData'));
  case 'BESA'
    status = (exist('readBESAtfc') && exist('readBESAswf'));
  case 'EEPROBE'
    status  = (exist('read_eep_avr') && exist('read_eep_cnt'));
  case 'YOKOGAWA'
    status  = (exist('GetMeg160ChannelInfoM') && exist('GetMeg160ContinuousRawDataM'));
  case 'BEOWULF'
    status = (exist('evalwulf') && exist('evalwulf') && exist('evalwulf'));
  case 'MENTAT'
    status  = (exist('pcompile') && exist('pfor') && exist('peval'));
  case 'SON2'
    status  = (exist('SONFileHeader') && exist('SONChanList') && exist('SONGetChannel'));
  case '4D-VERSION'
    status  = (exist('read4d') && exist('read4dhdr'));
  case 'SIGNAL'
    status = exist('medfilt1');
  case 'OPTIM'
    status  = (exist('fmincon') && exist('fminunc'));
  case 'FASTICA'
    status  = exist('fastica', 'file');
  case 'BRAINSTORM'
    status  = exist('bem_xfer');
  case 'FILEIO'
    status  = (exist('read_header') && exist('read_data') && exist('read_event') && exist('read_sens'));
  case 'FORWINV'
    status  = (exist('compute_leadfield') && exist('prepare_vol_sens'));
  case 'DENOISE'
    status  = (exist('tsr') && exist('sns'));
  case 'CTF'
    status  = (exist('getCTFBalanceCoefs') && exist('getCTFdata'));
  case 'BCI2000'
    status  = exist('load_bcidat');
  otherwise
    if ~silent, warning(sprintf('cannot determine whether the %s toolbox is present', toolbox)); end
    status = 0;
end

% it should be a boolean value
status = (status~=0);

% try to determine the path of the requested toolbox
if autoadd && ~status

  % for core fieldtrip modules
  prefix = fileparts(which('preprocessing'));
  if ~status
    status = myaddpath(fullfile(prefix, lower(toolbox)), silent);
  end

  % for external fieldtrip modules
  prefix = fullfile(fileparts(which('preprocessing')), 'external');
  if ~status
    status = myaddpath(fullfile(prefix, lower(toolbox)), silent);
  end

  % for linux computers in the F.C. Donders Centre
  prefix = '/home/common/matlab';
  if ~status && (strcmp(computer, 'GLNX86') || strcmp(computer, 'GLNXA64'))
    status = myaddpath(fullfile(prefix, lower(toolbox)), silent);
  end

  % for windows computers in the F.C. Donders Centre
  prefix = 'h:\common\matlab';
  if ~status && strcmp(computer, 'PCWIN')
    status = myaddpath(fullfile(prefix, lower(toolbox)), silent);
  end

  % use the matlab subdirectory in your homedirectory, this works on unix and mac
  prefix = [getenv('HOME') '/matlab'];
  if ~status 
    status = myaddpath(fullfile(prefix, lower(toolbox)), silent);
  end

 if ~status
    % the toolbox is not on the path and cannot be added
    sel = find(strcmp(url(:,1), toolbox));
    if ~isempty(sel)
      msg = sprintf('the %s toolbox is not installed, %s', toolbox, url{sel, 2});
    else
      msg = sprintf('the %s toolbox is not installed', toolbox);
    end
    error(msg);
  end
end

% this function is called many times in FieldTrip and associated toolboxes
% use efficient handling if the same toolbox has been investigated before
previous.(fixname(toolbox)) = status;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% helper function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function status = myaddpath(toolbox, silent)
if exist(toolbox, 'dir')
  if ~silent, warning(sprintf('adding %s toolbox to your Matlab path', toolbox)); end
  addpath(toolbox);
  status = 1;
else
  status = 0;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% helper function
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function out = fixname(toolbox)
out = lower(toolbox);
out(out=='-') = '_';

