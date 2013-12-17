#!/bin/bash
# rsync ACORN radial FV00 data from STAGING to OPENDAP

printf "\n"
date
tic=$(date +%s.%N)

# Need to set the environment variables relevant for ACORN
source /home/ggalibert/DEFAULT_PATH.env
source /home/ggalibert/STORAGE.env
source /home/ggalibert/ACORN.env

# Need to delete empty files older than 5min not to move them, and empty directories older than 31days
find $STAGING/ACORN/radial/ -type f -amin +5 -name "*FV00_radial.nc" -empty -delete -printf "Empty file %p deleted\n" | sort
find $STAGING/ACORN/radial/ -type d -atime +31 -empty -delete

# we need to prevent from copying growing files
# (files still being uploaded and not finished at the time we launch rsync)
# so we look for files last accessed for greater than 5min ago
find $STAGING/ACORN/radial/ -type f -amin +5 -name "*FV00_radial.nc" -printf %P\\n | sort | rsync -va --remove-source-files --files-from=- $STAGING/ACORN/radial/ $OPENDAP/ACORN/radial/

printf "\n"
date
toc=$(date +%s.%N)
printf "%6.1Fs\tFV00 radial files moved from STAGING to OPENDAP\n"  $(echo "$toc - $tic"|bc )
