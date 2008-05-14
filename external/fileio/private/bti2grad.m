function [grad] = bti2grad(hdr);

% 4D2GRAD converts a CTF header to a gradiometer structure that can be
% understood by FieldTrip and Robert Oostenveld's low-level forward and
% inverse routines. This function only works for headers that have been
% read using the READ_4D_HDR function.
%
% Use as:
%   [hdr]  = read_4d_hdr(filename);
%   [grad] = 4d2grad(hdr);
%
% This function only computes the hardware magnetometer
% definition for the 4D system. This function is based on ctf2grad and
% Gavin Paterson's code, which was adapted from Eugene Kronberg's code
%
% See also NIMH2GRAD, FIF2GRAD, CTF2GRAD

% Copyright (C) 2008, Jan-Mathijs Schoffelen 
%
% $Log: bti2grad.m,v $
% Revision 1.4  2008/05/14 08:02:40  jansch
% transposed grad.tra (was initially incorrect)
%
% Revision 1.3  2008/05/08 11:10:20  jansch
% implementation in analogy with ctf2grad
%

% for backward compatibility issues FIXME check whether anyone actually uses this code
if isfield(hdr, 'Meg_pos'),

grad     = [];
grad.pnt = hdr.Meg_pos;
grad.ori = hdr.Meg_dir;
for i=1:size(grad.pnt,1)
  % grad.label{i} = sprintf('MEG%03d', i);
  grad.label{i} = sprintf('A%d', i); % according to BTi convention
end
grad.label = grad.label(:);
grad.tra = sparse(eye(size(grad.pnt,1)));
   
else


% it seems as if there is information about the channels at 2 places of
% the original header. 
% hdr.channel_data contains info about the actual recorded channels 
% hdr.config.channel_data contains more important info about ALL 
%   channels such as position and orientation. 
% hdr.channel_data maps to hdr.config.channel_data through 
% hdr.channel_data.chan_no

type    = double([hdr.config.channel_data.type]');
chan_no = double([hdr.config.channel_data.chan_no]');
name    = {hdr.config.channel_data.name}'; 

selMEG = chan_no(find(type==1));
selREF = chan_no(find(type==3));
selMEG = selMEG(:)';
selREF = selREF(:)';
numMEG = length(selMEG);
numREF = length(selREF);

%sort magnetometers and references

%sortrows does not work here
for k = 1:length(selMEG)
  n(k) = str2num(name{selMEG(k)}(2:end));
end
[srt, ind] = sort(n);
selMEG     = selMEG(ind);

[srt, ind] = sortrows(char(name{selREF}));
selREF     = selREF(ind);
%first gradiometer refs, then magnetometer refs, alphabetical sorting

selALL = [selMEG selREF];
numALL = length(selALL);

totalcoils = 0;
numcoils   = zeros(length(type),1);
for i=1:numALL
  numcoils(selALL(i)) = hdr.config.channel_data(selALL(i)).device_data.total_loops;
end
totalcoils = sum(numcoils);

% start with empty gradiometer
grad       = [];
grad.pnt   = zeros(totalcoils, 3);
grad.ori   = zeros(totalcoils, 3);
grad.tra   = zeros(numALL, totalcoils);
grad.label = cell(numALL,1);

% combine the coils of each MEG channel if necessary
% FIXME find a description of gradiometer system
cnt = 0;
for i=1:numMEG
  n   = selMEG(i);
  pos = cat(2,hdr.config.channel_data(n).device_data.loop_data.position)';
  ori = cat(2,hdr.config.channel_data(n).device_data.loop_data.direction)';
  % determine the number of coils for this channel
  if numcoils(n) ~= size(pos,1)
    error('number of coils does not correspond with number of coil positions');
  end
  % add the coils of this channel to the gradiometer array
  grad.tra(i, cnt+1:cnt+numcoils(n)) = 1;
  for k=1:numcoils(n)
    cnt = cnt+1;
    grad.pnt(cnt,   :) = pos(k,:);
    grad.ori(cnt,   :) = ori(k,:);
  end
  grad.label(i)          = name(n); 
end

% combine the coils of each reference channel if necessary
for i=1:numREF
  n   = selREF(i);
  pos = cat(2,hdr.config.channel_data(n).device_data.loop_data.position)';
  ori = cat(2,hdr.config.channel_data(n).device_data.loop_data.direction)';
  % determine the number of coils for this channel
  if numcoils(n) ~= size(pos,1)
    error('number of coils does not correspond with number of coil positions');
  end
  % add the coils of this channel to the gradiometer array
  grad.tra(numMEG+i, cnt+1:cnt+numcoils(n)) = 1; %FIXME check whether ori is OK for gradiometers
  for k=1:numcoils(n)
    cnt                = cnt+1;
    grad.pnt(cnt,   :) = pos(k,:);
    grad.ori(cnt,   :) = ori(k,:);
  end
  grad.label(numMEG+i) = {hdr.config.channel_data(n).name}; 
end

grad.unit  = 'm';
%TODO remove redundant rows in tra matrix, since some coils are used twice
end


