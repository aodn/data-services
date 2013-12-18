#!/bin/bash
# rsync ACORN radial FV01 data from STAGING to OPENDAP

printf "\n"
date
tic=$(date +%s.%N)

# Need to set the environment variables relevant for ACORN
source /home/ggalibert/DEFAULT_PATH.env
source /home/ggalibert/STORAGE.env
source /home/ggalibert/ACORN.env

# We can delete empty directories older than 31days
find $STAGING/ACORN/ -type d -atime +31 -empty -delete

# we need to prevent from copying growing files
# (files still being uploaded and not finished at the time we launch find)
# so we look for files last accessed for greater than 5min ago
find $STAGING/ACORN/radial/ -type f -amin +5 -name "*FV01_radial.nc" -printf %P\\n | sort > $ACORN_EXP/BASH/move_FV01_radial.$$.list

# we check these NetCDF files are not corrupted (basic check with ncdump not throwing any error, this will also spot empty files)
cat $ACORN_EXP/BASH/move_FV01_radial.$$.list | xargs -I {} isCorruptedNC.sh $STAGING/ACORN/radial/{} $ACORN_EXP/BASH/isCorruptedNC.$$.list
grep -v -f $ACORN_EXP/BASH/isCorruptedNC.$$.list $ACORN_EXP/BASH/move_FV01_radial.$$.list > $ACORN_EXP/BASH/move_FV01_radial.$$.checkedList
rm -f $ACORN_EXP/BASH/isCorruptedNC.$$.list
rm -f $ACORN_EXP/BASH/move_FV01_radial.$$.list

# we can finally move the remaining files
cat $ACORN_EXP/BASH/move_FV01_radial.$$.checkedList | rsync -va --remove-source-files --files-from=- $STAGING/ACORN/radial/ $OPENDAP/ACORN/radial_quality_controlled/
rm -f $ACORN_EXP/BASH/move_FV01_radial.$$.checkedList

printf "\n"
date
toc=$(date +%s.%N)
printf "%6.1Fs\tFV01 radial files moved from STAGING to OPENDAP\n"  $(echo "$toc - $tic"|bc )
