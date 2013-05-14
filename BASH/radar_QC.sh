#!/bin/bash

# Need to set the environment variables relevant for ACORN
source /home/ggalibert/DEFAULT_PATH.env
source /home/ggalibert/STORAGE.env
source /home/ggalibert/ACORN.env

# Run Matlab script to produce FV01 hourly averaged gridded files
matlab -nodisplay -r "cd(getenv('ACORN_EXP')); addpath(fullfile('.', 'Util')); acorn_summary('WERA', true); exit"

# Move produced files to OPENDAP
rsync -vaR --remove-source-files $DATA/ACORN/WERA/radial_QC/output/datafabric/gridded_1havg_currentmap_QC/./ $OPENDAP/ACORN/gridded_1h-avg-current-map_QC/