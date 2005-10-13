function s1 = resize_scales(s0,dim,args)
% Resize scalefactors 
% _________________________________________________________________________________
% Copyright (C) 2005 Wellcome Department of Imaging Neuroscience

%
% $Id: resize_scales.m 253 2005-10-13 15:31:34Z guillaume $

args1 = cell(1,numel(args));
for i=1:numel(args),
    if max(args{i})>dim(i) || min(args{i})<1,
        error('Index exceeds matrix dimensions (1).');
    end;

    if size(s0,i)==1,
        args1{i} = ones(size(args{i}));
    else
        args1{i} = args{i};
    end;
end;

s1 = s0(args1{:});

