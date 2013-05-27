#!/bin/bash

date
tic=$(date +%s.%N)
echo ' '

# Need to set the environment variables relevant for ACORN
source /home/ggalibert/DEFAULT_PATH.env
source /home/ggalibert/STORAGE.env
source /home/ggalibert/ACORN.env

# Run Matlab script to produce FV01 hourly averaged gridded files
matlab -nodisplay -r "cd(getenv('ACORN_EXP')); addpath(fullfile('.', 'Util')); acorn_summary('WERA', true); exit"

echo ' '
date
toc=$(date +%s.%N)
printf "%6.1Fs\tFV01 radial files processed to hourly averaged gridded files\n"  $(echo "$toc - $tic"|bc )

date
tic=$(date +%s.%N)
echo ' '

# Move produced files to OPENDAP
rsync -vaR --remove-source-files $DATA/ACORN/WERA/radial_QC/output/datafabric/gridded_1havg_currentmap_QC/./ $OPENDAP/ACORN/gridded_1h-avg-current-map_QC/

echo ' '
date
toc=$(date +%s.%N)
printf "%6.1Fs\tFV01 hourly averaged gridded files moved from WIP to OPENDAP\n"  $(echo "$toc - $tic"|bc )
