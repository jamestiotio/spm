function spm_eeg_convert_ui(S)
% User interface for M/EEG conversion function
% FORMAT spm_eeg_convert(S)
% S - existing configuration struct (optional)
% _______________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging

% Vladimir Litvak
% $Id: spm_eeg_convert_ui.m 1267 2008-03-28 12:12:14Z vladimir $
if nargin == 0
    S=[];
end

[Finter,Fgraph,CmdLine] = spm('FnUIsetup','MEEG data conversion ',0);

if ~isfield(S, 'dataset')
    S.dataset = spm_select(1, '\.*', 'Select M/EEG data file');
end

if spm_input('Define settings?','+1','yes|just read',[1 0], 0);

    if ~isfield(S, 'continuous')
        S.continuous = spm_input('How to read?','+1','continuous|trials',[1 0], 1);
    end

    if S.continuous
        readall = spm_input('Read everything?','+1','yes|no',[1 0]);

        if ~isfield(S, 'timewindow')
            S.timewindow = [];
        end

        if ~readall  &&  isempty(S.timewindow);
            S.timewindow = spm_input('Input time window ([start end] in sec)', '+1', 'r');
        end
    else
        res = spm_input('Where to look for trials?','+1','data|define|file',[1 2 3], 1);

        switch res
            case 1
                S.usetrials = 1;
            case 2
                S.usetrials = 0;
                [S.trl, S.conditionlabels] = spm_eeg_definetrial(S);
            case 3
                S.usetrials = 0;
                if  ~isfield(S, 'trlfile')
                    S.trlfile = spm_select(1, '\.mat$', 'Select a trial definition file');
                end
        end
    end

    if ~isfield(S, 'allchannels')
        S.allchannels = spm_input('Read all channels?','+1','yes|no',[1 0], 1);
    end

    if ~S.allchannels && ~isfield(S, 'chanfile')
        S.chanfile = spm_select(1, '\.mat$', 'Select a channel selection file');
    end

    if ~isfield(S, 'outfile')
        if S.continuous
            prefix = '';
        else
            prefix = 'e';
        end
        S.outfile = spm_input('SPM EEG file name', '+1', 's', [prefix spm_str_manip(S.dataset,'tr')]);
    end
    
end

spm_eeg_convert(S);
