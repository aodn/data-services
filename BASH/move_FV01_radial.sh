#!/bin/bash

# No need to delete empty files/directories, done by FV00 process before
#/usr/bin/find /mnt/imos-t4/IMOS/staging/ACORN/radial/ -type f -empty -delete
#/usr/bin/find /mnt/imos-t4/IMOS/staging/ACORN/radial/ -type d -empty -delete

# rsync ACORN radial FV01 data from STAGING to OPENDAP
/usr/bin/rsync -aR --remove-source-files --include '+ */' --include '*FV01*.nc'  --exclude '- *' /mnt/imos-t4/IMOS/staging/ACORN/radial/./ /mnt/imos-t3/IMOS/opendap/ACORN/radial_quality_controlled/
