NRS_AIMS_Darwin_Yongala_data_rss_channels_process
=============

This script downloads data from the AIMS web service. The
data is NRT, and comes from two different stations : Darwin
and Yongala. The script can be run as many times as desired.


## Installation

Open config.txt to change the paths of :
* data_wip_path                    :location of the NRS scripts output (log + data)
* destination_production_data_path :location of the opendap folder where data is available to the public
* data_opendap_rsync_path          :location of the source data folder which will be rsynced to opendap
* logfile_name                     :name of the log file
* email1.log                       :email logfile user1
* email2.log                       :email logfile user2 (not required)

For testing on local machine, please edit $DATA_SERVICE_REPO/env

## Usage

Type in your shell ```./NRS.sh```


## System Requirements
Internet connection
Tested with MATLAB R2009a, R2012a

Operating System Support
The following operating systems are supported:
Ubuntu 9.10, MINT16


## Contact Support
for support contact:
Email: laurent.besnard@utas.edu.au
