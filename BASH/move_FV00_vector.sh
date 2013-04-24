#!/bin/bash

# Need to rename files with shorter time_stamps
#/usr/bin/find /mnt/imos-t4/IMOS/staging/ACORN/sea-state/ -type f | awk 'BEGIN {FS="_"} {if (length($4) == 14) print("mv "$0" "$1"_"$2"_"$3"_"substr($4,1,13)"00Z_"$5"_"$6"_"$7);}' | bash

# Need to delete empty files and directories not to move them
/usr/bin/find /mnt/imos-t4/IMOS/staging/ACORN/sea-state/ -type f -empty -delete
/usr/bin/find /mnt/imos-t4/IMOS/staging/ACORN/sea-state/ -type d -empty -delete

# rsync ACORN vector FV00 data from STAGING to OPENDAP
/usr/bin/rsync -aR --remove-source-files --include '+ */' --include '*FV00*.nc'  --exclude '- *' /mnt/imos-t4/IMOS/staging/ACORN/sea-state/./ /mnt/imos-t3/IMOS/opendap/ACORN/vector/
