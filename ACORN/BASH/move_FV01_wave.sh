#!/bin/bash
# rsync ACORN wavep FV01 data from STAGING to OPENDAP

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
stagingWaveDir=$STAGING/ACORN/wave/
stagingWaveFilesList=/tmp/move_FV01_wave.$$.list
find $stagingWaveDir -type f -amin +5 -name "*FV01_wavep.nc" -printf %P\\n | sort > $stagingWaveFilesList

# we check these NetCDF files are not corrupted (basic check with ncdump not throwing any error, this will also spot empty files)
stagingCorruptedWaveFilesList=/tmp/isCorruptedNC.$$.list
stagingSaneWaveFilesList=/tmp/move_FV01_wave.$$.checkedList
touch $stagingCorruptedWaveFilesList
cat $stagingWaveFilesList | xargs -I {} isCorruptedNC.sh $stagingWaveDir{} $stagingCorruptedWaveFilesList
grep -v -f $stagingCorruptedWaveFilesList $stagingWaveFilesList > $stagingSaneWaveFilesList
rm -f $stagingCorruptedWaveFilesList
rm -f $stagingWaveFilesList

# we can finally move the remaining files
# physics based wave parameters on sites
cat $stagingSaneWaveFilesList | grep -E "_CBG_|_SAG_|_ROT_|_COF_" | rsync -va --remove-source-files --delete-before --files-from=- $stagingWaveDir $OPENDAP/ACORN/gridded_1h-avg-wave-site-map_QC/
# empirical algorithms based wave parameters on stations
cat $stagingSaneWaveFilesList | grep -E "_TAN_|_LEI_|_CWI_|_CSP_|_GUI_|_FRE_|_RRK_|_NNB_" | rsync -va --remove-source-files --delete-before --files-from=- $stagingWaveDir $OPENDAP/ACORN/gridded_1h-avg-wave-station-map_QC/
rm -f $stagingSaneWaveFilesList

printf "\n"
date
toc=$(date +%s.%N)
printf "%6.1Fs\tFV01 wavep files moved from STAGING to OPENDAP\n"  $(echo "$toc - $tic"|bc )
