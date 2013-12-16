#!/bin/bash
# rsync ACORN radial FV00 data from STAGING to OPENDAP

# Need to set the environment variables relevant for ACORN
source /home/ggalibert/DEFAULT_PATH.env
source /home/ggalibert/STORAGE.env
source /home/ggalibert/ACORN.env

# Need to delete empty files and directories older than 5min, not to move them
find $STAGING/ACORN/radial/ -type f -amin +5 -empty -delete
find $STAGING/ACORN/radial/ -type d -amin +5 -empty -delete

# we need to prevent from copying growing files
# (files still being uploaded and not finished at the time we launch rsync)
# so we look for files last accessed for greater than 5min ago
find $STAGING/ACORN/radial/ -type f -amin +5 -name "*FV00_radial.nc" -printf %P\\0 | rsync -a --remove-source-files --files-from=- --from0 $STAGING/ACORN/radial/ $OPENDAP/ACORN/radial/
