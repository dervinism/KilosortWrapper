function ops = KilosortConfiguration(metadataFile)
% ops = KilosortConfiguration(XMLfile)
%
% Function initialises Kilosort parameters for spike sorting and is a
% helper subfunction of KilosortWrapper.
% Input: metadataFile - A character array containing the full path to the
%                       MAT or XML metadata file generated by the
%                       Neuroscope or CellExplorer, respectively. The file
%                       is used to load part of the recording metadata.
%                       This is a required parameter.
% Output: ops - a structure variable containing Kilosort parameters. To
%               understand the meaning of different fields of this
%               variable, consult StandardConfig_MOVEME.m file inside the
%               configFiles folder of Kilosort3.
%
% Adapted from the Kilosort3 configuration and master files by Martynas
% Dervinis (martynas.dervinis@gmail.com) at Petersen Lab, University of
% Copenhagen.

arguments
  metadataFile (1,:) char
end


%% Load metadata and channel map files
% Loads metadata
try
  if strcmpi(metadataFile(end-2:end),'mat') % CellExplorer
    metadata = load(metadataFile);
    sampleRate = metadata.extracellular.sr;
  else % Neuroscope
    metadata = LoadXml(metadataFile); % a subfunction of KilosortWrapper
    sampleRate = metadata.SampleRate;
  end
catch me
  warning('Failed to load metadata. Using default sampling rate of 30 kHz.')
  disp(me)
  metadata = [];
  sampleRate = 30000;
end

% Define rootpath
rootpath = fileparts(metadataFile);

% Load the channel map file
load(fullfile(rootpath,'chanMap.mat'),'connected');


%% Set up Kilosort3 parameters: Part 1
% probe recording channel map file
ops.chanMap = fullfile(rootpath,'chanMap.mat');

% sample rate
ops.fs = sampleRate;  

% frequency for high pass filtering (150)
ops.fshigh = 150;

% minimum firing rate on a "good" channel (0 to skip)
ops.minfr_goodchannels = 0.1; 

% threshold on projections (like in Kilosort1, can be different for last pass like [10 4])
ops.Th = [9 9];  

% how important is the amplitude penalty (like in Kilosort1, 0 means not used, 10 is average, 50 is a lot) 
ops.lam = 10;  

% splitting a cluster at the end requires at least this much isolation for each sub-cluster (max = 1)
ops.AUCsplit = 0.9; 

% minimum spike rate (Hz), if a cluster falls below this for too long it
% gets removed (MD: How is this different from minfr_goodchannels?)
ops.minFR = 1/50; 

% number of samples to average over (annealed from first to second value) 
ops.momentum = [20 400]; 

% spatial constant in um for computing residual variance of spike
ops.sigmaMask = 30; 

% threshold crossings for pre-clustering (in PCA projection space)
ops.ThPre = 8;


%% Set up Kilosort3 parameters: Part 2
% Danger, changing these settings can lead to fatal errors
% options for determining PCs
ops.spkTh          = -6;  % spike threshold in standard deviations (-6)
ops.reorder        = 1;   % whether to reorder batches for drift correction. 
ops.nskip          = 25;  % how many batches to skip for determining spike PCs

ops.GPU            = 1;   % has to be 1, no CPU version yet, sorry
% ops.Nfilt          = 1024;   % max number of clusters
ops.nfilt_factor   = 4;   % max number of clusters per good channel (even temporary ones)
ops.ntbuff         = 64;  % samples of symmetrical buffer for whitening and spike detection
ops.NT             = 64*1024+ops.ntbuff; % must be multiple of 32 + ntbuff. This is the batch size (try decreasing if out of memory). 
ops.whiteningRange = 32;  % number of channels to use for whitening each channel
ops.nSkipCov       = 25;  % compute whitening matrix from every N-th batch
ops.scaleproc      = 200; % int16 scaling of whitened data
ops.nPCs           = 3;   % how many PCs to project the spikes into
ops.useRAM         = 0;   % not yet available


%% Set up Kilosort3 parameters: Part 3
% These parameters were moved here from the Kilosort master file
ops.trange   = [0 Inf]; % time range to sort
ops.NchanTOT = numel(connected); % total number of channels in your recording

ops.sig      = 20;  % spatial smoothness constant for registration
ops.fshigh   = 300; % high-pass more aggresively
ops.nblocks  = 5;   % blocks for registration. 0 turns it off, 1 does rigid registration. Replaces "datashift" option.

% find the binary file
fs           = [dir(fullfile(rootpath, '*.bin')) dir(fullfile(rootpath, '*.dat'))];
ops.fbinary  = fullfile(rootpath, fs(1).name);


%% Set up extra data exporting parameters
% Saving xml content to ops strucuture
ops.metadata = metadata;

% Specify if the output should be exported to Phy and/or Neurosuite
ops.export.phy = 1;
ops.export.neurosuite = 0;