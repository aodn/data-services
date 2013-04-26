#!/bin/bash
# rsync ACORN radial FV01 data from STAGING to OPENDAP

# No need to delete empty files/directories, done by FV00 process before
#/usr/bin/find /mnt/imos-t4/IMOS/staging/ACORN/radial/ -type f -empty -delete
#/usr/bin/find /mnt/imos-t4/IMOS/staging/ACORN/radial/ -type d -empty -delete

# we need to prevent from copying growing files
# (files still being uploaded and not finished at the time we launch rsync)
# so we look for files last accessed for greater than 1min ago
/usr/bin/find /mnt/imos-t4/IMOS/staging/ACORN/radial/ -type f -amin +1 -name "*FV01_radial.nc" -printf %P\\0 | rsync -a --remove-source-files --files-from=- --from0 /mnt/imos-t4/IMOS/staging/ACORN/radial/ /mnt/imos-t3/IMOS/opendap/ACORN/radial_quality_controlled/
