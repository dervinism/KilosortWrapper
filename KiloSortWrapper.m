function savepath = KiloSortWrapper(varargin)
% savepath = KiloSortWrapper(basepath=value, basename=value, GPU_id=value, procPath=value, createSubdirectory=value, performAutoCluster=value, config=value, acqBoard=value, probe=value)
%
% This function is a Kilosort3 wrapper. Execute inside the data folder.
%
% Briefly, it runs Kilosort, creates a channel map file, and writes output
% data in the Phy and Neurosuite formats. All parameters are optional and
% have to be passed as name-value pairs.
%
% Dependencies: KiloSort3 (https://github.com/MouseLand/Kilosort).
%               Git (Kilosort3 dependecy realy which is not listed by
%                    Kilosort3; https://git-scm.com/download).
%               Phy (https://github.com/cortex-lab/phy).
%
% The AutoClustering requires CCGHeart to be compiled. Go to the private
% folder of the wrapper and type:
% mex -O CCGHeart.c
%
% Input: basepath - a character array with the path to the data folder. By
%                   default uses the current working directory.
%        basename - a character array with the data filename. Default is
%                   the last data folder in the path which is typically
%                   'continuous'.
%        GPU_id - a scalar with GPU ID. Default is 1.
%        procPath - a character array with a path to the folder for storing
%                   intermediate processing results. This folder should
%                   typically reside on an SSD on your computer. Make it an
%                   empty character array to use the basepath (or raw data
%                   directory) for storing intermediate processing data
%                   (default).
%        createSubdirectory - a logical for creating an output directory.
%                             If set to true, will put ptocessed Kilosort
%                             data into a subfolder within basepath
%                             (default).
%        performAutoCluster - a logical that if set to true, will perform
%                             PhyAutoCluster once Kilosort is complete when
%                             exporting to Phy (default). For more info,
%                             type help PhyAutoClustering.
%        config - a character array specifying the full name of the custom
%                 Kilosort configuration file to use instead of the default
%                 Kilosort settings used by this Kilosort wrapper. The file
%                 should be located inside the ConfigurationFiles folder.
%                 The settings file should follow the same structure used
%                 by KilosortConfiguration.m (type edit
%                 KilosortConfiguration to inspect the file). Default is
%                 empty, meaning using the default settings.
%        phyPath - a character array specifying the full path to where you
%                  installed your Phy environment. It is a good idea to
%                  specify it because by default or if left empty, the
%                  wrapper will assume it is located inside the folder phy
%                  within the current working directory.
%        acqBoard - a character array with the name of the acquisition
%                   board, eg., 'OpenEphys'. Currently supports only
%                   'OpenEphys' (default).
%        probe - a character array with the name of the probe used to
%                acquire the ecephys data. For Neuropixels use
%                'Neuropixels1_checkerboard' or 'Neuropixels2'. For all
%                other probes use 'other'. Default is an empty character
%                array in which case the wrapper will attempt to load the
%                probe info from the metadata file.
% Output: savepath - a character array with a path to the output directory.
%
% Examples:
%   (1) The easiest way to execute this function is to use no input
%       variables and call it from within the data folder:
%         KiloSortWrapper
%       In this case the default values will be used.
%   (2) Alternatively, you can specify every input variable, like:
%         basepath = cd;
%         basename = 'continuous';
%         GPU_id = 1;
%         procPath = '';
%         createSubdirectory = true;
%         performAutoCluster = true;
%         config = '';
%         phyPath = 'C:\Users\Martynas\Python_environments\phy';
%         acqBoard = 'OpenEphys';
%         probe = 'Neuropixels1_checkerboard';
%         savepath = KiloSortWrapper(basepath=basepath, basename=basename, ...
%           GPU_id=GPU_id, procPath=procPath, createSubdirectory=createSubdirectory, ...
%           performAutoCluster=performAutoCluster, config=config, phyPath=phyPath, ...
%           acqBoard=acqBoard, probe=probe);
%
% The current version of the function has been modified by Martynas
% Dervinis (martynas.dervinis@gmail.com) at Petersen Lab, University of
% Copenhagen.
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.


%% Parse inputs
savepath = ''; %#ok<NASGU>
rootFolder = cd;
p = inputParserFunc(varargin{:});
parse(p,varargin{:})

basepath = p.Results.basepath;
basename = p.Results.basename;
GPU_id = p.Results.GPU_id;
procPath = p.Results.procPath;
createSubdirectory = p.Results.createSubdirectory;
performAutoCluster = p.Results.performAutoCluster;
config = p.Results.config;
phyPath = p.Results.phyPath;
acqBoard = p.Results.acqBoard;
probe = p.Results.probe;


%% Check if acquisition parameters are valid
if ~strcmpi(acqBoard,'OpenEphys')
  error('Only OpenEphys recording setup is currently supported')
end
if contains(probe,'Neuropixels') && ~contains(basepath,'Neuropix')
  basepath = [basepath filesep 'Neuropix-PXI-100.0'];
else
  probe = 'other'; % Only 'Neuropixels1_checkerboard' or 'other'
end


%% Check if required files and folders exist
if ~exist(fullfile(basepath,[basename,'.xml']), 'file') && ~exist(fullfile(basepath,[basename,'.mat']), 'file')
  error('%s.session.mat and %s.xml files are not in path %s',basename,basename,basepath);
elseif ~exist(fullfile(basepath,[basename,'.dat']), 'file')
  error('%s.dat file not in path %s',basename,basepath)
elseif ~isempty(procPath) && ~exist(procPath, 'dir')
  error('%s folder does not exist',procPath)
elseif ~isempty(config) && ~exist(config, 'file')
  error('%s file does not exist',config)
elseif ~exist(phyPath, 'dir')
  error('%s folder with Phy Python environment installation does not exist',phyPath)
end


%% Check the processing folder for sufficient space
if isempty(procPath)
  processingFolder = fullfile(basepath,'temp_wh.dat');
else
  FileObj = java.io.File(procPath);
  freeBytes = FileObj.getFreeSpace;
  dat_file = dir(fullfile(basepath,[basename,'.dat']));
  if dat_file.bytes*1.1<freeBytes
    disp('Creating a temporary dat file on the processing folder')
    processingFolder = fullfile(procPath, [basename,'_temp_wh.dat']);
  else
    warning('Not sufficient space in your processing folder. Creating local dat file instead')
    processingFolder = fullfile(basepath,'temp_wh.dat');
  end
end


%% Create a channel map file
disp('Creating ChannelMapFile')
if exist(fullfile(basepath,[basename,'.session.mat']), 'file')
  metadataFilePath = fullfile(basepath, [basename '.session.mat']);
else
  metadataFilePath = fullfile(basepath, [basename '.xml']);
end
if ~isempty(probe)
  [~, probe] = createChannelMapFile_KSW(basepath, '', probe); % a subfunction of KilosortWrapper
else
  [~, probe] = createChannelMapFile_KSW(basepath, metadataFilePath);
end


%% Configure Kilosort
if isempty(config)
  disp('Configuring Kilosort using standard settings')
  ops = KilosortConfiguration(metadataFilePath); % a subfunction of KilosortWrapper
else
  disp('Configuring Kilosort using custom settings')
  addpath('ConfigurationFiles')
  configFuncHandle = str2func(config);
  ops = configFuncHandle(metadataFilePath); % a handle of a custom subfunction of KilosortWrapper
  clear configFuncHandle;
end
ops.fproc = processingFolder;
ops.datatype = acqBoard;
ops.probe = probe;


%% Initialise GPU (will erase any existing GPU arrays)
if ops.GPU
  disp('Initializing GPU')
  gpudev = gpuDevice(GPU_id);
end


%% Convert raw data to binary format (only for data saved in OpenEphys data format)
if strcmp(ops.datatype , 'openEphys')
  ops = convertOpenEphysToRawBInary(ops); % a subfunction of Kilosort
end


%% Run Kilosort
disp('Running Kilosort pipeline')
rez            = preprocessDataSub(ops); % All functions used in this cell are Kilosort subfunctions
rez            = datashift2(rez, 1);
[rez, st3, tF] = extract_spikes(rez);
rez            = template_learning(rez, tF, st3);
[rez, st3, tF] = trackAndSort(rez);
rez            = final_clustering(rez, tF, st3); % rez.cProj is generated here
rez            = find_merges(rez, 1);


%% Save Kilosort output
if createSubdirectory
  timestamp = ['Kilosort_' datestr(clock,'yyyy-mm-dd_HHMMSS')]; %#ok<DATST,CLOCK> 
  savepath = fullfile(basepath, timestamp);
  mkdir(savepath);
  copyfile(fullfile(basepath,[basename '.xml']),savepath);
else
  savepath = fullfile(basepath);
end
rez.ops.basepath = basepath;
rez.ops.basename = basename;
rez.ops.savepath = savepath;
disp('Saving Kilosort''s rez file')
save(fullfile(savepath, 'rez.mat'), 'rez', '-v7.3');


%% Export Kilosort spikesorting results for use in Phy
if ops.export.phy
  disp('Converting to Phy format')
  rezToPhy2_KSW(rez, savepath); % a subfunction of KilosortWrapper

  % Extract cluster features
  cd(savepath);
  if ispc
    system_cmd = [phyPath filesep 'Scripts' filesep 'activate & phy extract-waveforms params.py'];
    system(system_cmd);
  elseif ismac
    warning('Feature extraction is currently not supported on macOS.')
  elseif isunix
    warning('Feature extraction is currently not supported on Linux.')
  end

  % AutoClustering the Phy output
%   if performAutoCluster
%     PhyAutoClustering(savepath);
%   end
end


%% Export Neurosuite files
if ops.export.neurosuite
    disp('Converting to Klusters format')
    Kilosort2Neurosuite(rez);
end


%% Remove the temporary file and reset the GPU
delete(ops.fproc);
cd(rootFolder);
reset(gpudev);
gpuDevice([]);
disp('Kilosort processing complete')




%% Local functions
function p = inputParserFunc(varargin)
% Parse input variables

p = inputParser;
basepath = cd;
[~,basename] = fileparts(basepath);

addParameter(p,'basepath',basepath,@ischar)                % path to the folder containing the data
addParameter(p,'basename',basename,@ischar)                % file basenames (of the dat and xml files)
addParameter(p,'GPU_id',1,@isnumeric)                      % Specify the GPU_id
addParameter(p,'procPath','',@ischar)                      % Path to the intermediate processing folder (located on SSD). Make it empty to disable SSD
addParameter(p,'createSubdirectory',true,@islogical)       % Puts the Kilosort output into a subfolder
addParameter(p,'performAutoCluster',true,@islogical)       % Performs PhyAutoCluster once Kilosort is complete when exporting to Phy.
addParameter(p,'config','',@ischar)                        % Specify a configuration file to use from the ConfigurationFiles folder.
addParameter(p,'phyPath',fullfile(basepath,'phy'),@ischar) % Path to your Phy environment installation folder.
addParameter(p,'acqBoard','OpenEphys',@ischar)             % Specify acquisition board, e.g., 'OpenEphys'
addParameter(p,'probe','',@ischar)                         % Specify the probe used: 'Neuropixels1_checkerboard', 'other', or ''.

parse(p,varargin{:})
