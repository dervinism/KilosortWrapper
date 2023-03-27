# KilosortWrapper
Allows you to load Kilosort from a .xml and a .dat file compatible with Neurosuite. 

## Installation
Download and add the KilosortWrapper directory to your Matlab path. Also add subdirectories ```chanMaps``` and ```ConfigurationFiles``` to your Matlab path.

## Settings
Most settings are defined in the KilosortConfiguration.m file. Some general settings are defined in the KilosortWrapper file, including: 
* ```basepath```: Raw data folder
* ```basename```: Basename of the raw data folder (e.g., ```continuous``` in OpenEphys)
* ```GPU_id``` 
* ```procPath```: Path to the intermediate processing folder (expected to be located on SSD)
* ```createSubdirectory```: Allows you to save the output files from Kilosort to a sub directory (labeled by data and time)
* ```performAutoCluster```: Allows you to perform autoclustering of the Kilosort autput (currently put on hold)
* ```config```: You can supply a config version input to use another config file (configuration files should be stored in the ConfigurationFiles folder)
* ```acqBoard```: Differentiate between acquisition boards (currently supports only OpenEphys)
* ```probe```: Differentiate between Neuropixels and other probes
 
## Features
Skip channels: To skip dead channels, synchronize the anatomical groups and the spike groups in Neuroscope and remove the dead channels in the spike groups. The synchronization is necessary for maintaining the correct waveform layout in Phy.

Define probe layouts: The wrapper now supports probes with staggered, poly3 and poly5 probe layouts. Open your xml file and define your probe layout in the Notes field (General information). Kilosort assumes a staggered probe layout without any input.

CreateSubdirectory: Allows you to save the output files from Kilosort to a sub directory (labeled by data and time).

## Outputs
The Kilosort wrapper allows you to save the output in Neurosuite and Phy compatible files. 

### Phy

### Neurosuite (Kilosort2Neurosuite)
Creates all classical files used in the Neurosuite format. For this the dat file is filtered, waveforms are extracted and global PCA features are calculated. 

## Please use below DOI for citing the KiloSortWrapper
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.3604165.svg)](https://doi.org/10.5281/zenodo.3604165)

### Cite as
Peter C. Petersen, Brendon Watson, & Adrien Peyrache. (2020, January 10). petersenpeter/KilosortWrapper: KiloSortWrapper (Version 1.0). Zenodo. http://doi.org/10.5281/zenodo.3604165