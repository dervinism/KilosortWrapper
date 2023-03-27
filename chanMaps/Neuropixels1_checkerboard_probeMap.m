classdef Neuropixels1_checkerboard_probeMap
  
  properties
    productId (1,:) char = 'Neuropixels1_checkerboard' % Product name identifying unique configuration.
    layout (1,:) char {ismember(layout, {'linear', 'staggered', 'edge', 'tetrode', 'poly2', 'poly3', 'poly4', 'poly5', 'checkerboard', 'other', 'unknown'})} = 'checkerboard' % Probe layout.
    nChannels (1,1) {mustBeNumeric} = 384         % Number of probe recording channels.
    nShanks (1,1) {mustBeNumeric} = 1             % Number of probe shanks.
    shankSpacing (1,1) {mustBeNumeric} = 0        % Spacing between shanks (µm).
    shankFullLength (1,1) {mustBeNumeric} = 10000 % Length of shanks measured from the tip to the base of the probe (larger than shankLength; µm).
    shankRecLength (1,1) {mustBeNumeric} = 3840   % Length of shanks typically measured from the lowermost to the uppermost channel (the largest dimension; µm).
    shankWidth (1,2) {mustBeNumeric} = [70 70]    % An array containing the shank width at the recording site closest to the tip of the probe (1st element) and at the site closest to the base of the probe (2nd element) (middle dimension, µm).
    shankThickness (1,1) {mustBeNumeric} = 24     % Thickness of shanks (the smallest dimension, µm)
    siteArea (1,1) {mustBeNumeric} = 144          % Area (size) of electrode sites (µm^2)
    horizontalSpacing (1,1) {mustBeNumeric} = 16  % Horizontal spacing between sites or pitches (µm)
    verticalSpacing (1,1) {mustBeNumeric} = 20    % Vertical spacing between sites or pitches (µm)
    uniformLayout (1,1) logical = true            % Uniform layout meaning whether the same recording site layout is used for all shanks.
    customDesign (1,1) logical = false            % Custom design
    source (1,:) char = 'bottomLeftBoardCorner'   % Coordinate reference point. A common value would be 'bottomLeftCh'.
                                                  % However, for Neuropixels probes it is the bottom left corner of the checkerboard layout
                                                  % assuming the bottom left recording site to be centred at (11,20) x-y coordinate
                                                  % so that all sites are packaged within the 3840-by-70 µm board. This gives 4 site locations
                                                  % on the x-axis: 11, 27, 43, and 59 µm.
  end


  methods
    function [probeMap, siteMap, conf, params] = get_native_map(self)
      % [probeMap, siteMap, conf, params] = get_native_map()
      %
      % Returns three native probe channel maps and computing parameters.
      %
      % Args:
      %   None
      %
      % Returns:
      %   probeMap (containers.Map): Returns a containers.Map Matlab
      %     object, which for each channel gives its x,y (horizontal,
      %     vertical) probe position in micrometers. For a more thorough
      %     documentation of containers.Map object type `doc
      %     containers.Map`.
      %   siteMap (cell | double): A simple recording site map that serves
      %     as a graphical representation of probe channel layout. This
      %     could be a shape-(K, L) cell array or a shape-(M, N) double
      %     array containing probe channels organised geometrically. NaNs
      %     can be used to represent probe locations without a recording
      %     site.
      %   conf (struct): a shape-(1, 1) Matlab structure containing the
      %     probe configuration with the following fields:
      %     probe (char): a shape-(1, I) string containing the name of the
      %       probe.
      %     chanMap (double): a shape-(1, J) array with the channel map
      %       organisation (1-indexed).
      %     chanMap0ind (double): a shape-(1, J) array with the channel map
      %       organisation (0-indexed).
      %     connected (double): a shape-(1, J) array of ones and zeros for
      %       connected and unconnected channels.
      %     shankInd (double): a shape-(1, J) array of shank indices
      %       corresponding to individual channels (1-indexed).
      %     xcoords (double): a shape-(1, J) array of probe x (horizontal)
      %       coordinates corresponding to individual channels (um).
      %     ycoords (double): a shape-(1, J) array of probe y (vertical)
      %       coordinates corresponding to individual channels (um).
      %   conf (struct): a shape-(1, 1) Matlab structure containing
      %     parameters used to compute the native probe channel maps.
      %     Parameters can be unique to a particular probe. They are
      %     provided as an output in case where furthe computations are
      %     needed. For the meaning of these parameters inspect the
      %     function code.

      % Parameters and the compute part
      nSites = self.nChannels;
      sites = 1:nSites;
      connectedSites = ones(size(sites));
      % unconnectedSites = [37 76 113 152 189 228 265 304 341 380];
      % connectedSites(unconnectedSites) = zeros(size(unconnectedSites));

      siteIDs = sites;
      siteIDs(~connectedSites) = NaN;
      hDim = 4;
      vDim = round(nSites/2);
      basicMotive = [1 0 1 0 0 1 0 1];
      eMapExt = repmat(basicMotive,1,vDim/2);
      eMap1(logical(eMapExt)) = siteIDs';
      eMap1(~logical(eMapExt)) = NaN;
      eMap1 = reshape(eMap1,hDim,vDim);
      eMap1 = rot90(eMap1',2);
      %eMap2 = eMap1(:,[2 1 4 3]);
      eMap3 = fliplr(eMap1);
      %eMap4 = fliplr(eMap2);
      siteMap = eMap3;

      hStart = 11; % um
      hDist = self.horizontalSpacing; % um
      hMotive = [hStart+0*hDist hStart+2*hDist hStart+1*hDist hStart+3*hDist];
      xCoords = repmat(hMotive', round(nSites/hDim), 1);
      vDist = self.verticalSpacing; % um
      vMotive = 0.5:1:vDim;
      yCoords = zeros(size(sites))';
      yCoords(1:2:nSites) = vMotive.*vDist;
      yCoords(2:2:nSites) = vMotive.*vDist;

      % Output: probeMap
      probeMap = containers.Map('KeyType', 'int32', 'ValueType', 'any'); % a map from contact number to its x,y coordinates
      for i = 1:nSites
        site = find(sites == i);
        probeMap(site) = [xCoords(i) yCoords(i)]; %#ok<FNDSB>
      end

      % Output: conf
      conf.probe = self.productId;
      conf.chanMap = sites;
      conf.chanMap0ind = sites-1;
      conf.connected = connectedSites;
      conf.shankInd = ones(size(sites));
      conf.xcoords = xCoords';
      conf.ycoords = yCoords';

      % Output: params
      params.hDim = hDim;
      params.basicMotive = basicMotive;
      params.hStart = hStart;
    end

    function [chanMap, probe] = get_ks_map(self)
      % [chanMap, probe] = get_ks_map()
      %
      % Returns a channel map compatible with Kilosort3.
      %
      % Args:
      %   None
      %
      % Returns:
      %   chanMap (struct): a shape-(1, 1) Matlab structure containing the
      %     Kilosort probe channel map:
      %     chanMap (double): a shape-(1, J) array with the channel map
      %       organisation (1-indexed).
      %     chanMap0ind (double): a shape-(1, J) array with the channel map
      %       organisation (0-indexed).
      %     connected (double): a shape-(1, J) array of ones and zeros for
      %       connected and unconnected channels.
      %     kcoords (double): a shape-(1, J) array of shank indices
      %       corresponding to individual channels (1-indexed).
      %     xcoords (double): a shape-(1, J) array of probe x (horizontal)
      %       coordinates corresponding to individual channels (um).
      %     ycoords (double): a shape-(1, J) array of probe y (vertical)
      %       coordinates corresponding to individual channels (um).
      %   probe (char): a shape-(1, M) string with the name of the probe.

      [~, ~, chanMap] = self.get_native_map;
      chanMap.kcoords = chanMap.shankInd;
      probe = chanMap.probe;
      chanMap = rmfield(chanMap, {'probe','shankInd'});
    end

    function chanCoords = get_ce_map(self)
      % [chanCoords, probe] = get_ce_map()
      %
      % Returns a channel map compatible with Cell Explorer.
      %
      % Args:
      %   None
      %
      % Returns:
      %   chanCoords (struct): a shape-(1, 1) Matlab structure containing
      %     the CellExplorer probe channel map:
      %   productId (char): a shape-(1, L)) string with product name
      %     identifying the probe and its unique configuration.
      %   layout (char): a shape-(1, M) string describing probe layout in a
      %     single word.
      %   nChannels (numeric): a shape-(1, 1) number of probe
      %     recording channels.
      %   nShanks (numeric): a shape-(1, 1) number of probe shanks.
      %   shankSpacing (numeric): a shape-(1, 1) scalar denoting the
      %     distance between shanks (µm).
      %   shankFullLength (numeric): a shape-(1, 1) scalar denoting the
      %     length of shanks measured from the tip to the base of the probe
      %     (larger than shankLength; µm).
      %   shankRecLength (numeric): a shape-(1, 1) scalar denoting the
      %     length of shanks typically measured from the lowermost to the
      %     uppermost channel (the largest dimension; µm).
      %   shankWidth (numeric): a shape-(1, 2) array containing the shank
      %     width at the recording site closest to the tip of the probe
      %     (1st element) and at the site closest to the base of the probe
      %     (2nd element) (middle dimension, µm).
      %   shankThickness (numeric): a shape-(1, 1) scalar denoting
      %     shank thickness (the smallest dimension, µm).
      %   siteArea (numeric): a shape-(1, 1) scalar with area (size)
      %     of electrode sites (µm^2).
      %   horizontalSpacing (numeric): a shape-(1, 1) scalar representing
      %     the horizontal spacing between recording sites or pitches (µm).
      %   verticalSpacing (numeric): a shape-(1, 1) scalar representing
      %     the vertical spacing between recording sites or pitches (µm).
      %   uniformLayout (logical): a shape-(1,1) logical indicating whether
      %     the probe layout is uniform, meaning whether the same recording
      %     site layout is used for all shanks.
      %   customDesign (logical): a shape-(1,1) logical indicating whether
      %     the probe is customly designed.
      %   source (char): a shape-(1, N) string describing the coordinate
      %     reference point (origin). A common value would be
      %     'bottomLeftCh'. However, for Neuropixels probes it is the
      %     bottom left corner of the checkerboard layout assuming the
      %     bottom left recording site to be centred at (11,20) x-y
      %     coordinate so that all sites are packaged within the 3840-by-70
      %     µm board. This gives 4 site locations on the x-axis: 11, 27,
      %     43, and 59 µm.

      [~, ~, conf] = self.get_native_map;
      chanCoords.productId = self.productId;
      chanCoords.layout = self.layout;
      chanCoords.nChannels = self.nChannels;
      chanCoords.nShanks = self.nShanks;
      chanCoords.shankSpacing = self.shankSpacing;
      chanCoords.shankFullLength = self.shankFullLength;
      chanCoords.shankRecLength = self.shankRecLength;
      chanCoords.shankWidth = self.shankWidth;
      chanCoords.shankThickness = self.shankThickness;
      chanCoords.siteArea = self.siteArea;
      chanCoords.horizontalSpacing = self.horizontalSpacing;
      chanCoords.verticalSpacing = self.verticalSpacing;
      chanCoords.uniformLayout = self.uniformLayout;
      chanCoords.customDesign = self.customDesign;
      chanCoords.source = self.source;
      chanCoords.x = conf.xcoords;
      chanCoords.y = conf.ycoords;
      chanCoords.shankID = conf.shankInd;
    end

    function chanMapName = save_native_map(self, savepath)
      % chanMapName = save_native_map(savepath)
      % 
      % Saves the native probe channel map.
      %
      % Args:
      %   savepath (char): a shape-(1, M) string with the full saving path
      %     for the native probe channel map. If left empty, it will
      %     default to the current working directory. For the description
      %     of the native probe channel map see the docstring of
      %     get_native_map function.
      %
      % Returns:
      %   chanMapName (char): a shape-(1, N) string with the full path name
      %     of the newly saved native probe channel map.

      arguments
        self
        savepath (1,:) char = pwd
      end

      if isempty(savepath)
        savepath = pwd;
      end

      [~, ~, conf] = self.get_native_map;
      probe = self.productId;
      chanMap = conf.chanMap;
      chanMap0ind = conf.chanMap0ind;
      connected = conf.connected;
      shankInd = conf.shankInd;
      xcoords = conf.xcoords;
      ycoords = conf.ycoords;

      chanMapName = fullfile(savepath,[conf.probe '_nativeChanMap.mat']);
      save(chanMapName, 'probe','chanMap','chanMap0ind','connected','xcoords','ycoords','shankInd', '-v7.3');
    end

    function chanMapName = save_ks_map(self, savepath)
      % chanMapName = save_ks_map(savepath)
      % 
      % Saves the Kilosort3-compatible probe channel map.
      %
      % Args:
      %   savepath (char): a shape-(1, M) string with the full saving path
      %     for the Kilosort3-compatible probe channel map. If left empty,
      %     it will default to the current working directory. For the
      %     description of the Kilosort3-compatible probe channel map see
      %     the docstring of get_ks_map function.
      %
      % Returns:
      %   chanMapName (char): a shape-(1, N) string with the full path name
      %     of the newly saved Kilosort3-compatible probe channel map.

      arguments
        self
        savepath (1,:) char = pwd
      end

      if isempty(savepath)
        savepath = pwd;
      end

      [chanMap, probe] = self.get_ks_map;
      chanMap0ind = chanMap.chanMap0ind;
      connected = chanMap.connected;
      kcoords = chanMap.kcoords;
      xcoords = chanMap.xcoords;
      ycoords = chanMap.ycoords;
      chanMap = chanMap.chanMap;

      chanMapName = fullfile(savepath,[probe '_chanMap.mat']);
      save(chanMapName, 'chanMap','chanMap0ind','connected','xcoords','ycoords','kcoords', '-v7.3');
    end

    function chanMapName = save_ce_map(self, savepath)
      % chanMapName = save_ce_map(savepath)
      % 
      % Saves the CellExplorer-compatible probe channel map.
      %
      % Args:
      %   savepath (char): a shape-(1, M) string with the full saving path
      %     for the CellExplorer-compatible probe channel map. If left empty,
      %     it will default to the current working directory. For the
      %     description of the CellExplorer-compatible probe channel map
      %     see the docstring of get_ce_map function.
      %
      % Returns:
      %   chanMapName (char): a shape-(1, N) string with the full path name
      %     of the newly saved CellExplorer-compatible probe channel map.

      arguments
        self
        savepath (1,:) char = pwd
      end

      if isempty(savepath)
        savepath = pwd;
      end

      chanCoords = self.get_ce_map;
      chanMapName = fullfile(savepath,[chanCoords.productId '_chanCoords.channelinfo.mat']);
      save(chanMapName, 'chanCoords', '-v7.3');
    end
  end
end