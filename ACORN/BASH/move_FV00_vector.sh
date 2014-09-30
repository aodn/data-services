#!/bin/bash
# rsync ACORN vector FV00 data from STAGING to OPENDAP

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
find $STAGING/ACORN/acorn-migration-hierarchy/sea-state/ -type f -amin +5 -name "*FV00_sea-state.nc" -printf %P\\n | sort > /tmp/move_FV00_vector.$$.list

# we check these NetCDF files are not corrupted (basic check with ncdump not throwing any error, this will also spot empty files)
touch /tmp/isCorruptedNC.$$.list
cat /tmp/move_FV00_vector.$$.list | xargs -I {} isCorruptedNC.sh $STAGING/ACORN/acorn-migration-hierarchy/sea-state/{} /tmp/isCorruptedNC.$$.list
grep -v -f /tmp/isCorruptedNC.$$.list /tmp/move_FV00_vector.$$.list > /tmp/move_FV00_vector.$$.checkedList
rm -f /tmp/isCorruptedNC.$$.list
rm -f /tmp/move_FV00_vector.$$.list

# we can finally move the remaining files
cat /tmp/move_FV00_vector.$$.checkedList | rsync -va --remove-source-files --files-from=- $STAGING/ACORN/acorn-migration-hierarchy/sea-state/ $OPENDAP/ACORN/vector/
rm -f /tmp/move_FV00_vector.$$.checkedList

printf "\n"
date
toc=$(date +%s.%N)
printf "%6.1Fs\tFV00 vector files moved from STAGING to OPENDAP\n"  $(echo "$toc - $tic"|bc )
