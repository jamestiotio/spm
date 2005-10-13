function D = spm_eeg_weight_channels(S)
% function used for multiplying epoching EEG/MEG data with a user-specified
% channel-specific weighting function
% FORMAT D = spm_eeg_weight_channels(S)
% 
% S		    - optional input struct
% (optional) fields of S:
% D			- filename of EEG mat-file
% W         - mixing matrix
%_______________________________________________________________________
% Copyright (C) 2005 Wellcome Department of Imaging Neuroscience

% Stefan Kiebel
% $Id: spm_eeg_weight_channels.m 253 2005-10-13 15:31:34Z guillaume $

[Finter,Fgraph,CmdLine] = spm('FnUIsetup','EEG weighting setup',0);

try
    D = S.D;
catch
    D = spm_select(1, 'mat', 'Select EEG mat file');
end

P = spm_str_manip(D, 'H');

try
	D = spm_eeg_ldata(D);
catch    
	error(sprintf('Trouble reading file %s', D));
end

try
    W = S.W;
catch
        W = spm_input('Mixing matrix', -1, 'r', '', [D.Nchannels D.Nchannels]);
end

spm('Pointer', 'Watch');drawnow;

% Prepare for writing data
D.fnamedat = ['w' D.fnamedat];
fpd = fopen(fullfile(P, D.fnamedat), 'w');

% treat continuous and epoched data differently because of different
% scaling method

D.scale.dim = [1 3];
D.scale.values = zeros(D.Nchannels, D.Nevents);

spm_progress_bar('Init', D.Nevents, 'Events mixed'); drawnow;
if D.Nevents > 100, Ibar = floor(linspace(1, D.Nevents,100));
else, Ibar = [1:D.Nevents]; end

for i = 1:D.Nevents
    d = squeeze(D.data(:, :, i));
    d = W*d;
    D.scale.values(:, i) = spm_eeg_write(fpd, d, 2, D.datatype);
    if ismember(i, Ibar)
        spm_progress_bar('Set', i); drawnow;
    end

end

spm_progress_bar('Clear');

fclose(fpd);

D.Wchannels = W;
D.data = [];
D.fname = ['w' D.fname];

if str2num(version('-release'))>=14
    save(fullfile(P, D.fname), '-V6', 'D');
else
    save(fullfile(P, D.fname), 'D');
end

spm('Pointer', 'Arrow');
