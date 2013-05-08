#!/bin/bash
# rsync ACORN radial FV00 data from STAGING to OPENDAP

# Need to delete empty files and directories not to move them
find $STAGING/ACORN/radial/ -type f -empty -delete
find $STAGING/ACORN/radial/ -type d -empty -delete

# we need to prevent from copying growing files
# (files still being uploaded and not finished at the time we launch rsync)
# so we look for files last accessed for greater than 1min ago
find $STAGING/ACORN/radial/ -type f -amin +1 -name "*FV00_radial.nc" -printf %P\\0 | rsync -a --remove-source-files --files-from=- --from0 $STAGING/ACORN/radial/ $OPENDAP/ACORN/radial/
