SOOP Tropical Research Vessel
=============

This script downloads data from the AIMS web service for the SOOP TRV sub facility.

Two vessels are processed :
 * Cape Ferguson
 * RV Solander


## Installation

Open config.txt to change the paths of :
* data_wip_path     :location of the scripts output (log + data)
* data_opendap_path :location of the opendap folder where data is available to the public

For testing on local machine, please edit $DATA_SERVICE_REPO/env

## Usage
Type in your shell ```./SOOP_TRV.sh```


## System Requirements
Internet connection
Python:
      urllib2, urllib, xml.etree, tempfile, time, zipfile, logging, pickle, pathlib, os, shutil, netCDF4  

Operating System Support
The following operating systems are supported:
Ubuntu 9.10, MINT16


## Contact Support
for support contact:
Email: laurent.besnard@utas.edu.au
