#!/bin/bash
# rsync ACORN wavespec FV01 data from STAGING to OPENDAP

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
stagingWaveSpecDir=$STAGING/ACORN/spectra/
stagingWaveSpecFilesList=/tmp/move_FV01_spectra.$$.list
find $stagingWaveSpecDir -type f -amin +5 -name "*FV01_wavespec.nc" -printf %P\\n | sort > $stagingWaveSpecFilesList

# we check these NetCDF files are not corrupted (basic check with ncdump not throwing any error, this will also spot empty files)
#stagingCorruptedWaveSpecFilesList=/tmp/isCorruptedNC.$$.list
#stagingSaneWaveSpecFilesList=/tmp/move_FV01_spectra.$$.checkedList
#touch $stagingCorruptedWaveSpecFilesList
#cat $stagingWaveSpecFilesList | xargs -I {} isCorruptedNC.sh $stagingWaveSpecDir{} $stagingCorruptedWaveSpecFilesList
#grep -v -f $stagingCorruptedWaveSpecFilesList $stagingWaveSpecFilesList > $stagingSaneWaveSpecFilesList
#rm -f $stagingCorruptedWaveSpecFilesList
#rm -f $stagingWaveSpecFilesList

# we can finally move the remaining files
#cat $stagingSaneWaveSpecFilesList | rsync -va --remove-source-files --files-from=- $stagingWaveSpecDir $OPENDAP/ACORN/gridded_1h-avg-wave-spectra_QC/
cat $stagingWaveSpecFilesList | rsync -va --remove-source-files --delete-before --files-from=- $stagingWaveSpecDir $OPENDAP/ACORN/gridded_1h-avg-wave-spectra_QC/
#rm -f $stagingSaneWaveSpecFilesList
rm -f $stagingWaveSpecFilesList

printf "\n"
date
toc=$(date +%s.%N)
printf "%6.1Fs\tFV01 wavespec files moved from STAGING to OPENDAP\n"  $(echo "$toc - $tic"|bc )
