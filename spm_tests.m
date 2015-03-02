function results = spm_tests(varargin)
% Unit Testing Framework
% FORMAT results = spm_tests(name,value,...)
% name,value  - pairs of optional parameter names and values:
%     verbose:  verbosity level of test run progress report [default: 2]
%     display:  display test results [default: false]
%     coverage: display code coverage [default: false]
%     tap:      save a Test Anything Protocol (TAP) file [default: false]
% 
% results     - TestResult array containing information describing the
%               result of running the test suite.
%__________________________________________________________________________
% Copyright (C) 2015 Wellcome Trust Centre for Neuroimaging

% Guillaume Flandin
% $Id: spm_tests.m 6352 2015-02-27 18:30:35Z guillaume $


SVNid = '$Rev: 6352 $';
SPMid = spm('FnBanner',mfilename,SVNid);

%-Input parameters
%--------------------------------------------------------------------------
options = struct('verbose',2, 'display',false, 'coverage',false, 'tap',false);
if nargin
    if isstruct(varargin{1})
        fn = fieldnames(varargin{1});
        for i=1:numel(fn)
            options.(fn{i}) = varargin{1}.(fn{i});
        end
    else
        for i=1:2:numel(varargin)
            options.(varargin{i}) = varargin{i+1};
        end
    end
end

%-Unit tests
%==========================================================================
import matlab.unittest.TestSuite;
import matlab.unittest.TestRunner;
import matlab.unittest.plugins.TAPPlugin;
import matlab.unittest.plugins.ToFile;
import matlab.unittest.plugins.CodeCoveragePlugin;

%-Create a TestSuite
%--------------------------------------------------------------------------
tests = fullfile(spm('Dir'),'tests');
suite = TestSuite.fromFolder(tests, 'IncludingSubfolders', true);
%suite.selectIf('ParameterProperty', '*')

%-Create a TestRunner
%--------------------------------------------------------------------------
if ~options.verbose
    runner = TestRunner.withNoPlugins;
else
    runner = TestRunner.withTextOutput('Verbosity',options.verbose);
end

if options.coverage
    plugin = CodeCoveragePlugin.forFolder(spm('Dir'));
    runner.addPlugin(plugin);
end

if options.tap
    d = getenv('WORKSPACE');
    if isempty(d), d = spm('Dir'); end
    tapFile = fullfile(d,'spm_tests.tap');
    plugin = TAPPlugin.producingOriginalFormat(ToFile(tapFile));
    runner.addPlugin(plugin);
end

%-Run tests
%--------------------------------------------------------------------------
results = runner.run(suite);

%-Display test results
%--------------------------------------------------------------------------
if options.display
    fprintf(['Totals (%d tests):\n\t%d Passed, %d Failed, %d Incomplete.\n' ...
        '\t%f seconds testing time.\n\n'],numel(results),nnz([results.Passed]),...
        nnz([results.Failed]),nnz([results.Incomplete]),sum([results.Duration]));
    
    disp(table(results));
end