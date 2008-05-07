function D = spm_eeg_bc(D, time)
% 'baseline correction' for data in D: subtract average baseline from all
% M/EEG and EOG channels
% FORMAT d = spm_eeg_bc(D, time)
%
% D:    meeg object
% time: 2-element vector with start and end of baseline period [ms]
%_______________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging

% Stefan Kiebel
% $Id: spm_eeg_bc.m 1560 2008-05-07 12:18:58Z stefan $

t(1) = D.indsample(time(1));
t(2) = D.indsample(time(2));

indchannels = [D.meegchannels D.eogchannels];

switch(transformtype(D))
    case 'TF'
        for i = indchannels
            for j = 1 : D.nfrequencies
                for k = 1: D.ntrials
                    tmp = mean(D(i, j, t(1):t(2), k), 3);
                    D(i, j, :, k) = D(i, j, :, k) - tmp;
                end
            end
        end
    case 'time'
        spm_progress_bar('Init', D.ntrials, 'trials baseline-corrected'); drawnow;
        if D.ntrials > 100, Ibar = floor(linspace(1, D.ntrials, 100));
        else Ibar = [1:D.ntrials]; end

        for k = 1: D.ntrials
            tmp = mean(D(indchannels, t(1):t(2), k), 2);
            D(indchannels, :, k) = D(indchannels, :, k) - repmat(tmp, 1, D.nsamples);
            
            if ismember(k, Ibar)
                spm_progress_bar('Set', k);
                drawnow;
            end

        end

        spm_progress_bar('Clear');

    otherwise
        error('Unknown transform type');

end
