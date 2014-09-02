#!/bin/bash
# rsync ACORN radial FV00 data from STAGING to OPENDAP

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
find $STAGING/ACORN/radial/ -type f -amin +5 -name "*FV00_radial.nc" -printf %P\\n | sort > /tmp/move_FV00_radial.$$.list

# we check these NetCDF files are not corrupted (basic check with ncdump not throwing any error, this will also spot empty files)
touch /tmp/isCorruptedNC.$$.list
cat /tmp/move_FV00_radial.$$.list | xargs -I {} isCorruptedNC.sh $STAGING/ACORN/radial/{} /tmp/isCorruptedNC.$$.list
grep -v -f /tmp/isCorruptedNC.$$.list /tmp/move_FV00_radial.$$.list > /tmp/move_FV00_radial.$$.checkedList
rm -f /tmp/isCorruptedNC.$$.list
rm -f /tmp/move_FV00_radial.$$.list

# we can finally move the remaining files
cat /tmp/move_FV00_radial.$$.checkedList | rsync -va --remove-source-files --files-from=- $STAGING/ACORN/radial/ $OPENDAP/ACORN/radial/
rm -f /tmp/move_FV00_radial.$$.checkedList

printf "\n"
date
toc=$(date +%s.%N)
printf "%6.1Fs\tFV00 radial files moved from STAGING to OPENDAP\n"  $(echo "$toc - $tic"|bc )

#printf "\n"
#date
#tic=$(date +%s.%N)

# Create Rottnest swim plots out of latest radial
#GMT_OUTPUT=`$ACORN_EXP/GMT/rotswim-10minmap.sh`

#printf "\n"
#date
#toc=$(date +%s.%N)
#printf "%6.1Fs\t$GMT_OUTPUT\n"  $(echo "$toc - $tic"|bc )
