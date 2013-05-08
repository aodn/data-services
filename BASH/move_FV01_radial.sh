#!/bin/bash
# rsync ACORN radial FV01 data from STAGING to OPENDAP

# Need to set the environment variables relevant for ACORN
source /home/ggalibert/DEFAULT_PATH.env
source /home/ggalibert/STORAGE.env
source /home/ggalibert/ACORN.env

# No need to delete empty files/directories, done by FV00 process before
#find $STAGING/ACORN/radial/ -type f -empty -delete
#find $STAGING/ACORN/radial/ -type d -empty -delete

# we need to prevent from copying growing files
# (files still being uploaded and not finished at the time we launch rsync)
# so we look for files last accessed for greater than 1min ago
find $STAGING/ACORN/radial/ -type f -amin +1 -name "*FV01_radial.nc" -printf %P\\0 | rsync -a --remove-source-files --files-from=- --from0 $STAGING/ACORN/radial/ $OPENDAP/ACORN/radial_quality_controlled/
