#!/bin/bash
# bash script to run data-product for WQM + CTD on most recent files.
# 
# The matlab script burstprodbatch.m reads in the time of last
# run and only processes files moved to OPeNDAP since then.
#
# burstprodbatch.m also runs setup_nctoolbox, and mylocalpath
# Creates products in wip/Products_Temp
#

# Need to set the relevant environment variables
source /home/ggalibert/DEFAULT_PATH.env
source /home/ggalibert/STORAGE.env

echo "Running MATLAB and burstprodbatch.m"

matlab -nodisplay -r "addpath(genpath(fullfile(getenv('DATA_SERVICES_DIR'), 'ANMN/burst_averaged_product'))); setup_nctoolbox; burstprodbatch; exit" 

echo "Moving products from wip directory to Staging"

rsync -arv --remove-source-files $DATA/ANMN/burst_avg_product/ $STAGING/ANMN
