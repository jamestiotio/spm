function spm_defaults_edit(arg1,arg2)
% Modify defaults
% FORMAT spm_defaults_edit
%_______________________________________________________________________
%
% spm_defaults_edit allows the current defaults to be edited.
%
% These changes do not persist across sessions. SPMs startup defaults
% are specified in the first spm_defaults on the MATLABPATH.
%
% The defaults which can be modified are:
% 
% Printing Options
%     Allows a number of different printing defaults to be specified.
% 
% Miscellaneous Defaults
%     This includes:
%     * Specification of a file for logging dialogue between
%       the user and SPM.
%     * Command line input option. Rather than clicking
%       buttons on the interface, input can be typed to
%       the Matlab window.
%     * The intensity of any grid which superimposed on any
%       displayed images.
% 
% Header Defaults (for the currnet Modality - PET or fMRI)
%     The values to be taken as default when there are no Analyze
%     image headers. There are two different sets which depend on
%     the modality in which SPM is running.
%     * image size in x,y and z {voxels}
%     * voxel size in x,y and z {mm}
%     * scaling co-efficient applied to *.img data on entry
%       into SPM. 
%     * data type.  (see spm_type.m for supported types
%       and specifiers)
%     * offest of the image data in file {bytes}
%     * the voxel corresponding the [0 0 0] in the location
%       vector XYZ
%     * a string describing the nature of the image data.
% 
% Realignment & Coregistration Defaults
%     An assortment of defaults.
%
% Spatial Normalisation Defaults
%     An assortment of defaults.
%
% The 'reset' option re-loads the startup defaults from spm_defaults.m
%
%_______________________________________________________________________
% @(#)spm_defaults_edit.m	2.6 John Ashburner 99/05/18

global batch_mat iA;

global MODALITY
global PRINTSTR LOGFILE CMDLINE GRID
global UFp DIM VOX TYPE SCALE OFFSET ORIGIN DESCRIP
global PET_UFp PET_DIM PET_VOX PET_TYPE PET_SCALE PET_OFFSET ...
	PET_ORIGIN PET_DESCRIP
global fMRI_UFp fMRI_DIM fMRI_VOX fMRI_TYPE fMRI_SCALE fMRI_OFFSET ...
	fMRI_ORIGIN fMRI_DESCRIP
global fMRI_T fMRI_T0


if nargin == 0
	SPMid = spm('FnBanner',mfilename,SCCSid);
	spm('FnUIsetup','Defaults Edit');
	spm_help('!ContextHelp',mfilename)


	callbacks = str2mat(...
		'spm_defaults_edit(''Printing'');',...
		'spm_defaults_edit(''Misc'');',...
		'spm_defaults_edit(''Hdr'');',...
		'spm_realign(''Defaults'');',...
		'spm_sn3d(''Defaults'');',...
		'spm_defaults_edit(''Statistics'');',...
		'spm_defaults_edit(''Reset'');'...
		);

	a1 = spm_input('Defaults Area?',1,'m',...
		['Printing Options|'...
		 'Miscellaneous Defaults|'...
		 'Header Defaults - ',MODALITY,'|'...
		 'Realignment & Coregistration|'...
		 'Spatial Normalisation|'...
		 'Statistics - ',MODALITY,'|'...
		 'Reset All'] ...
             ); %- nargin == 0 => not called by batch 

	eval(deblank(callbacks(a1,:)));
	spm_figure('Clear','Interactive');

elseif strcmp(arg1, 'RealignCoreg')

    spm_realign('Defaults');

elseif strcmp(arg1, 'Normalisation')

    spm_sn3d('Defaults');

elseif strcmp(arg1, 'Misc')

	% Miscellaneous
	%---------------------------------------------------------------
	c = (abs(CMDLINE)>0) -1;

	if ~isempty(LOGFILE), tmp='yes'; def=1; else, tmp='no'; def=2; end
	if spm_input(['Log to file? (' tmp ')'],2*c,'y/n',[1,0],def,...
      			'batch',batch_mat,{arg1,iA},'log_to_file')
		LOGFILE = ...
			deblank(spm_input('Logfile Name:',2,'s', LOGFILE,...
         			'batch',batch_mat,...
				{arg1,iA},'log_file_name'));
	else
		LOGFILE = '';
	end

	CMDLINE = abs(CMDLINE)>0 * sign(CMDLINE);
	def = find(CMDLINE==[0,1,-1]);
	CMDLINE = spm_input('Command Line Input?',3*c,'m',...
		{	'always use GUI',...
			'always use CmdLine',...
			'GUI for files, CmdLine for input'},...
		[0,1,-1],def,...
      		'batch',batch_mat,{arg1,iA},'cmdline');

	GRID = spm_input('Grid value (0-1):', 4*c, 'e', GRID,...
      			   'batch',batch_mat,{arg1,iA},'grid');

elseif strcmp(arg1, 'Printing')

	% Printing Defaults
	%---------------------------------------------------------------
	a0 = spm_input('Printing Mode?', 2, 'm', [...
			'Postscript to File|'...
			'Postscript to Printer|'...
			'Other Format to File|'...
			'Custom'], ...
         'batch',batch_mat,{arg1,iA},'printing_mode');

	if (a0 == 1)
		fname = date; fname(find(fname=='-')) = []; fname = ['spmfig_' fname];
		fname = spm_str_manip(spm_input('Postscript filename:',3,'s',fname,...
         				'batch',batch_mat,{arg1,iA},'postscript_filename'),'rtd');

		a1    = spm_input('Postscript Type?', 4, 'm', [...
			'PostScript for black and white printers|'...
			'PostScript for colour printers|'...
			'Level 2 PostScript for black and white printers|'...
			'Level 2 PostScript for colour printers|'...
			'Encapsulated PostScript (EPSF)|'...
			'Encapsulated Colour PostScript (EPSF)|'...
			'Encapsulated Level 2 PostScript (EPSF)|'...
			'Encapsulated Level 2 Color PostScript (EPSF)|'...
			'Encapsulated                with TIFF preview|'...
			'Encapsulated Colour         with TIFF preview|'...
			'Encapsulated Level 2        with TIFF preview|'...
			'Encapsulated Level 2 Colour with TIFF preview|'],...
         			'batch',batch_mat,{arg1,iA},'postscript_type');

		prstr1 = str2mat(...
			['print(''-noui'',''-painters'',''-dps'' ,''-append'',''' fname '.ps'');'],...
			['print(''-noui'',''-painters'',''-dpsc'',''-append'',''' fname '.ps'');'],...
			['print(''-noui'',''-painters'',''-dps2'',''-append'',''' fname '.ps'');'],...
			['print(''-noui'',''-painters'',''-dpsc2'',''-append'',''' fname '.ps'');']);
		prstr1 = str2mat(prstr1,...
			['global PAGENUM;if isempty(PAGENUM),PAGENUM = 1;end;'...
			 'print(''-noui'',''-painters'',''-deps'',[''' fname '_'' num2str(PAGENUM) ''.ps'']); PAGENUM = PAGENUM + 1;'],...
			['global PAGENUM;if isempty(PAGENUM),PAGENUM = 1;end;'...
			 'print(''-noui'',''-painters'',''-depsc'',[''' fname '_'' num2str(PAGENUM) ''.ps'']); PAGENUM = PAGENUM + 1;'],...
			['global PAGENUM;if isempty(PAGENUM),PAGENUM = 1;end;'...
			 'print(''-noui'',''-painters'',''-deps2'',[''' fname '_'' num2str(PAGENUM) ''.ps'']); PAGENUM = PAGENUM + 1;'],...
			['global PAGENUM;if isempty(PAGENUM),PAGENUM = 1;end;'...
			 'print(''-noui'',''-painters'',''-depsc2'',[''' fname '_'' num2str(PAGENUM) ''.ps'']); PAGENUM = PAGENUM + 1;'],...
			['global PAGENUM;if isempty(PAGENUM),PAGENUM = 1;end;'...
			 'print(''-noui'',''-painters'',''-deps'',''-tiff'',[''' fname '_'' num2str(PAGENUM) ''.ps'']); PAGENUM = PAGENUM + 1;'],...
			['global PAGENUM;if isempty(PAGENUM),PAGENUM = 1;end;'...
			 'print(''-noui'',''-painters'',''-depsc'',''-tiff'',[''' fname '_'' num2str(PAGENUM) ''.ps'']); PAGENUM = PAGENUM + 1;'],...
			['global PAGENUM;if isempty(PAGENUM),PAGENUM = 1;end;'...
			 'print(''-noui'',''-painters'',''-deps2'',''-tiff'',[''' fname '_'' num2str(PAGENUM) ''.ps'']); PAGENUM = PAGENUM + 1;'],...
			['global PAGENUM;if isempty(PAGENUM),PAGENUM = 1;end;'...
			 'print(''-noui'',''-painters'',''-depsc2'',''-tiff'',[''' fname '_'' num2str(PAGENUM) ''.ps'']); PAGENUM = PAGENUM + 1;']);
		PRINTSTR = deblank(prstr1(a1,:));
	elseif (a0 == 2)
		printer = '';
		if (spm_input('Default Printer?', 3, 'y/n', ...
     			'batch',batch_mat,{arg1,iA},'default_printer') == 'n')
			printer = spm_input('Printer Name:',3,'s',...
         				'batch',batch_mat,{arg1,iA},'postscript_type')
			printer = [' -P' printer];
		end
		a1 = spm_input('Postscript Type:',4,'b','B & W|Colour', ...
          str2mat('-dps', '-dpsc'),...
			'batch',batch_mat,{arg1,iA},'post_type');
		PRINTSTR = ['print -noui -painters ' a1 printer];
	elseif (a0 == 3)
		fname = date; fname(find(fname=='-')) = []; fname = ['spmfig_' fname];
		fname = spm_str_manip(spm_input('Graphics filename:',3,'s', fname),'rtd','batch',batch_mat,{arg1,iA},'graphics_filename');
		a1    = spm_input('Graphics Type?', 4, 'm', [...
			'HPGL compatible with Hewlett-Packard 7475A plotter|'...
			'Adobe Illustrator 88 compatible illustration file|'...
			'M-file (and Mat-file, if necessary)|'...
			'Baseline JPEG image|'...
			'TIFF with packbits compression|'...
			'Color image format|'],...
         'batch',batch_mat,{arg1,iA},'graph_type');
		prstr1 = str2mat(...
			['global PAGENUM;if isempty(PAGENUM),PAGENUM = 1;end;'...
			 'print(''-noui'',''-painters'',''-dhpgl'',[''' fname '_'' num2str(PAGENUM) ''.hpgl'']); PAGENUM = PAGENUM + 1;'],...
			['global PAGENUM;if isempty(PAGENUM),PAGENUM = 1;end;'...
			 'print(''-noui'',''-painters'',''-dill'',[''' fname '_'' num2str(PAGENUM) ''.ill'']); PAGENUM = PAGENUM + 1;'],...
			['global PAGENUM;if isempty(PAGENUM),PAGENUM = 1;end;'...
			 'print(''-noui'',''-painters'',''-dmfile'',[''' fname '_'' num2str(PAGENUM) ''.m'']); PAGENUM = PAGENUM + 1;'],...
			['global PAGENUM;if isempty(PAGENUM),PAGENUM = 1;end;'...
			 'print(''-noui'',''-painters'',''-djpeg'',[''' fname '_'' num2str(PAGENUM) ''.jpeg'']); PAGENUM = PAGENUM + 1;'],...
			['global PAGENUM;if isempty(PAGENUM),PAGENUM = 1;end;'...
			 'print(''-noui'',''-painters'',''-dtiff'',[''' fname '_'' num2str(PAGENUM) ''.tiff'']); PAGENUM = PAGENUM + 1;'],...
			['global PAGENUM;if isempty(PAGENUM),PAGENUM = 1;end;'...
			 'print(''-noui'',''-painters'',''-dtiffnocompression'',[''' fname '_'' num2str(PAGENUM) ''.tiff'']); PAGENUM = PAGENUM + 1;']);
		PRINTSTR = deblank(prstr1(a1,:));
	else
		PRINTSTR = spm_input('Print String',3,'s',...
      'batch',batch_mat,{arg1,iA},'print_string');
	end

elseif strcmp(arg1, 'Hdr')

	% Header Defaults
	%---------------------------------------------------------------

	n = 0;
	while n ~= 3
		tmp      = spm_input('Image size {voxels}',2,'s',...
			[num2str(DIM(1)) ' ' num2str(DIM(2)) ' ' num2str(DIM(3))],...
         'batch',batch_mat,{arg1,iA},'image_size_voxels');
		[dim, n] = sscanf(tmp,'%d %d %d');
	end
	DIM = reshape(dim,1,3);

	n = 0;
	while n ~= 3
		tmp      = spm_input('Voxel Size {mm}',3,'s',...
			[num2str(VOX(1)) ' ' num2str(VOX(2)) ' ' num2str(VOX(3))],...
         'batch',batch_mat,{arg1,iA},'voxel_size_mm');
		[vox, n] = sscanf(tmp,'%g %g %g');
	end
	VOX = reshape(vox,1,3);

	SCALE = spm_input('Scaling Coefficient',4,'e',[SCALE],...
     'batch',batch_mat,{arg1,iA},'scale');

	type_val = [2 4 8 16 64];
	type_str = str2mat('Unsigned Char','Signed Short','Signed Integer',...
      'Floating Point','Double Precision');
	TYPE = spm_input(['Data Type (' deblank(type_str(find(type_val==TYPE),:)) ')'],5,'m',...
		'Unsigned Char	(8  bit)|Signed Short	(16 bit)|Signed Integer	(32 bit)|Floating Point|Double Precision',...
[2 4 8 16 64],'batch',batch_mat,{arg1,iA},'data_type');
	OFFSET = spm_input('Offset  {bytes}',6,'e',[OFFSET],...
   'batch',batch_mat,{arg1,iA},'offset');
	n = 0;
	while n ~= 3
		tmp      = spm_input('Origin {voxels}',7,'s',...
			[num2str(ORIGIN(1)) ' ' num2str(ORIGIN(2)) ' ' num2str(ORIGIN(3))],'batch',batch_mat,{arg1,iA},'origin_voxels');
		[origin, n] = sscanf(tmp,'%d %d %d');
	end
	ORIGIN = reshape(origin,1,3);
	DESCRIP = spm_input('Description',8,'s', DESCRIP,...
   'batch',batch_mat,{arg1,iA},'description');

	if strcmp(MODALITY,'PET')
		PET_DIM       = DIM;
		PET_VOX       = VOX;
		PET_TYPE      = TYPE;
		PET_SCALE     = SCALE;
		PET_OFFSET    = OFFSET;
		PET_ORIGIN    = ORIGIN;
		PET_DESCRIP   = DESCRIP;
	elseif strcmp(MODALITY,'FMRI')
		fMRI_DIM      = DIM;
		fMRI_VOX      = VOX;
		fMRI_TYPE     = TYPE;
		fMRI_SCALE    = SCALE;
		fMRI_OFFSET   = OFFSET;
		fMRI_ORIGIN   = ORIGIN;
		fMRI_DESCRIP  = DESCRIP;
	end

elseif strcmp(arg1, 'Statistics')
	UFp = spm_input('Upper tail F prob. threshold',2,'e',UFp,1, ...
  			  'batch',batch_mat,{arg1,iA},'F_threshold');
	if strcmp(MODALITY,'PET')
		PET_UFp       = UFp;
	elseif strcmp(MODALITY,'FMRI')
		fMRI_UFp      = UFp;
	end
	if strcmp(MODALITY,'FMRI'),
		fMRI_T  = spm_input('Number of Bins/TR' ,3,'n',fMRI_T,1,...
  			  'batch',batch_mat,{arg1,iA},'fMRI_T');
		fMRI_T0 = spm_input('Sampled bin',4,'n',fMRI_T0,1, fMRI_T0,...
  			  'batch',batch_mat,{arg1,iA},'fMRI_T0');
	end;


elseif strcmp(arg1, 'Reset')
	if exist('spm_defaults')==2
		spm_defaults;
	end
   	if isempty(batch_mat)	
      		spm('chmod',MODALITY);
   	else
      		spm('defaults',MODALITY);
   	end
end

