function D = spm_eeg_load(P)
% read an EEG file in SPM format. 
% FORMAT D = spm_eeg_ldata(P)
%
% P 		- filename of EEG-data file
% D			- MEEG object 
%_______________________________________________________________________
% 
% spm_eeg_load loads an MEEG file that is in SPM8 format. Importantly, the
% data is memory mapped and the struct is converted to meeg object.
%_______________________________________________________________________
% Copyright (C) 2005 Wellcome Department of Imaging Neuroscience

% Stefan Kiebel
% $Id: spm_eeg_load.m 1126 2008-01-30 14:07:02Z vladimir $


try
    P = deblank(P);
catch
    P = spm_select(1, '\.mat$', 'Select M/EEG mat file');
end

Ppath = spm_str_manip(P, 'H');
if strcmp('.', Ppath) | strcmp('..', Ppath)
    Ppath = pwd;
end

try
	load(P);
catch    
	error(sprintf('Trouble reading file %s', P));
end

spm('Pointer', 'Watch');

% check whether there is a struct D
if exist('D') ~= 1
    error('%s doesn''t contain SPM M/EEG data', P);
end


dtype = spm_type(D.data.datatype);


% save path temporarily in structure
D.path = Ppath;

D = meeg(D);

spm('Pointer', 'Arrow');
