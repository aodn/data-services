#!/bin/bash
# rsync ACORN radial FV01 data from STAGING to OPENDAP

date
tic=$(date +%s.%N)
echo ' '

# Need to set the environment variables relevant for ACORN
source /home/ggalibert/DEFAULT_PATH.env
source /home/ggalibert/STORAGE.env
source /home/ggalibert/ACORN.env

# Need to delete empty files older than 5min not to move them
# No need to delete empty directories, done by move_FV00_radial.sh already
find $STAGING/ACORN/radial/ -type f -amin +5 -name "*FV01_radial.nc" -empty -delete -printf "Empty file %p deleted\n" | sort

# we need to prevent from copying growing files
# (files still being uploaded and not finished at the time we launch rsync)
# so we look for files last accessed for greater than 5min ago
find $STAGING/ACORN/radial/ -type f -amin +5 -name "*FV01_radial.nc" -printf %P\\n | sort | rsync -va --remove-source-files --files-from=- $STAGING/ACORN/radial/ $OPENDAP/ACORN/radial_quality_controlled/

echo ' '
date
toc=$(date +%s.%N)
printf "%6.1Fs\tFV01 radial files moved from STAGING to OPENDAP\n"  $(echo "$toc - $tic"|bc )
