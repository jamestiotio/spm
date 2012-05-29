function varargout = optim_compat(bc,varargin)
% Compatibility function for optimN and optimNn
% FORMAT varargout = optim_compat(bc,varargin)
% bc - boundary condition (0=circulant, 1-Neumann)
%
% Calls the new optimN_mex function via the old API of the
% optimN and optimNn functions.
%
%_______________________________________________________________________
% Copyright (C) 2012 Wellcome Trust Centre for Neuroimaging

% John Ashburner
% $Id$

if nargin>1 && isa(varargin{1},'char')
    obc = optimN_mex('boundary'); % Old boundary condition
    optimN_mex('boundary',bc);    % Circulant boundary condition

    switch varargin{1},
    case 'fmg',
        param0 = varargin{4};
        switch param0(1),
        case 1,
            param = [param0(7) param0(5) 0 ];
        case 2,
            param = [param0(7) param0(6) param0(5)];
        otherwise
            error('Incorrect usage.');
        end
        param = [param0(2:4) param param0(8:end)];
        vi    = varargin;
        vi{4} = param;
        [varargout{1:nargout}] = optimN_mex(vi{:});

    case 'vel2mom',
        param0 = varargin{3};
        switch param0(1),
        case 1,
            param = [param0(7) param0(5) 0 ];
        case 2,
            param = [param0(7) param0(6) param0(5)];
        otherwise
            error('Incorrect usage.');
        end
        param = [param0(2:4) param param0(8:end)];
        vi    = varargin;
        vi{3} = param;
        [varargout{1:nargout}] = optimN_mex(vi{:});

    otherwise
        optimN_mex('boundary',obc);
        error('Incorrect usage.');
    end
    optimN_mex('boundary',obc);
else
    [varargout{1:nargout}] = optim_compat(bc,'fmg',varargin{:});
end

