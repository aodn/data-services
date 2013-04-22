#!/bin/bash
# rsync ACORN data from STAGING to OPENDAP
# radial FV00 (need to delete empty files and directories not to move them)
/usr/bin/find /mnt/imos-t4/IMOS/staging/ACORN/radial/ -type f -empty -delete
/usr/bin/find /mnt/imos-t4/IMOS/staging/ACORN/radial/ -type d -empty -delete
/usr/bin/rsync -aR --remove-source-files --include '+ */' --include '*FV00*.nc'  --exclude '- *' /mnt/imos-t4/IMOS/staging/ACORN/radial/./ /mnt/imos-t3/IMOS/opendap/ACORN/radial/
