#!/bin/bash
# rsync ACORN vector FV00 data from STAGING to OPENDAP

# Need to set the environment variables relevant for ACORN
source /home/ggalibert/DEFAULT_PATH.env
source /home/ggalibert/STORAGE.env
source /home/ggalibert/ACORN.env

# Need to rename files with shorter time_stamps
# not anymore : Arnstein should have fixed this problem.
#/usr/bin/find $STAGING/ACORN/sea-state/ -type f | awk 'BEGIN {FS="_"} {if (length($4) == 14) print("mv "$0" "$1"_"$2"_"$3"_"substr($4,1,13)"00Z_"$5"_"$6"_"$7);}' | bash

# Need to delete empty files and directories not to move them
find $STAGING/ACORN/sea-state/ -type f -empty -delete
find $STAGING/ACORN/sea-state/ -type d -empty -delete

# we need to prevent from copying growing files
# (files still being uploaded and not finished at the time we launch rsync)
# so we look for files last accessed for greater than 5min ago
find $STAGING/ACORN/sea-state/ -type f -amin +5 -name "*FV00_sea-state.nc" -printf %P\\0 | rsync -a --remove-source-files --files-from=- --from0 $STAGING/ACORN/sea-state/ $OPENDAP/ACORN/vector/
