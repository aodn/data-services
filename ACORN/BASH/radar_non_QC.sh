#!/bin/bash

# test the number of input arguments
if [ $# -ne 6 ]
then
	echo "Usage: $0 \"{'WERA_SITE_CODE', ...}\" \"'yyymmddTHH3000'\" \"'yyymmddTHH3000'\" \"{'CODAR_SITE_CODE', ...}\" \"'yyymmddTHH0000'\" \"'yyymmddTHH0000'\""
	exit
fi

date
tic=$(date +%s.%N)
printf "\n"

# Need to set the environment variables relevant for ACORN
source /home/ggalibert/DEFAULT_PATH.env
source /home/ggalibert/STORAGE.env
source /home/ggalibert/ACORN.env

# Run Matlab script to produce FV00 hourly averaged gridded files
matlab -nodisplay -r "cd([getenv('DATA_SERVICES_DIR') '/ACORN']); addpath(fullfile('.', 'Util')); acorn_summary('WERA', false, $1, $2, $3); acorn_summary('CODAR', false, $4, $5, $6); exit"

printf "\n"
date
toc=$(date +%s.%N)
printf "%6.1Fs\tFV00 radial files processed to hourly averaged gridded files\n"  $(echo "$toc - $tic"|bc )

tic=$(date +%s.%N)
printf "\n"

# Move produced files to OPENDAP
WERA_SOURCE=$DATA/ACORN/WERA/radial_nonQC/output/datafabric/gridded_1havg_currentmap_nonQC/
CODAR_SOURCE=$DATA/ACORN/CODAR/nonQC_gridded/output/datafabric/gridded_1havg_currentmap_nonQC/
TARGET=$OPENDAP/ACORN/gridded_1h-avg-current-map_non-QC/
find $WERA_SOURCE -type f -name "*FV00*.nc" -printf %P\\n | sort | rsync -va --remove-source-files --delete-before --files-from=- $WERA_SOURCE $TARGET
find $CODAR_SOURCE -type f -name "*FV00*.nc" -printf %P\\n | sort | rsync -va --remove-source-files --delete-before --files-from=- $CODAR_SOURCE $TARGET

printf "\n"
date
toc=$(date +%s.%N)
printf "%6.1Fs\tFV00 hourly averaged gridded files moved from WIP to OPENDAP\n"  $(echo "$toc - $tic"|bc )

#tic=$(date +%s.%N)
#printf "\n"

# Create Rottnest swim plots out of latest hourly gridded files
#GMT_OUTPUT=`$DATA_SERVICES_DIR/ACORN/GMT/rotswim-hourmap.sh`

#printf "\n"
#date
#toc=$(date +%s.%N)
#printf "%6.1Fs\t$GMT_OUTPUT\n"  $(echo "$toc - $tic"|bc )
