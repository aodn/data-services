#!/bin/bash
# rsync ACORN windp FV01 data from STAGING to OPENDAP

printf "\n"
date
tic=$(date +%s.%N)

# Need to set the environment variables relevant for ACORN
source /home/ggalibert/DEFAULT_PATH.env
source /home/ggalibert/STORAGE.env
source /home/ggalibert/ACORN.env

# we need to prevent from copying growing files
# (files still being uploaded and not finished at the time we launch find)
# so we look for files last accessed for greater than 5min ago
stagingWindDir=$STAGING/ACORN/wind/
stagingWindFilesList=/tmp/move_FV01_wind.$$.list
find $stagingWindDir -type f -amin +5 -name "*FV01_windp.nc" -printf %P\\n | sort > $stagingWindFilesList

# we check these NetCDF files are not corrupted (basic check with ncdump not throwing any error, this will also spot empty files)
stagingCorruptedWindFilesList=/tmp/isCorruptedNC.$$.list
stagingSaneWindFilesList=/tmp/move_FV01_wind.$$.checkedList
touch $stagingCorruptedWindFilesList
cat $stagingWindFilesList | xargs -I {} isCorruptedNC.sh $stagingWindDir{} $stagingCorruptedWindFilesList
grep -v -f $stagingCorruptedWindFilesList $stagingWindFilesList > $stagingSaneWindFilesList
rm -f $stagingCorruptedWindFilesList
rm -f $stagingWindFilesList

# we can finally move the remaining files
cat $stagingSaneWindFilesList | rsync -va --remove-source-files --files-from=- $stagingWindDir $OPENDAP/ACORN/gridded_1h-avg-wind-map_QC/
rm -f $stagingSaneWindFilesList

printf "\n"
date
toc=$(date +%s.%N)
printf "%6.1Fs\tFV01 windp files moved from STAGING to OPENDAP\n"  $(echo "$toc - $tic"|bc )
