#!/bin/bash
# rsync ACORN data from STAGING to OPENDAP
# vector FV00 (need to rename files with shorter time_stamps)
/usr/bin/find /mnt/imos-t4/IMOS/staging/ACORN/sea-state/ -type f | awk 'BEGIN {FS="_"} {if (length($4) == 14) print("mv "$0" "$1"_"$2"_"$3"_"substr($4,1,13)"00Z_"$5"_"$6"_"$7);}' | bash
/usr/bin/find /mnt/imos-t4/IMOS/staging/ACORN/sea-state/ -type d -empty -delete
/usr/bin/rsync -aR --remove-source-files --include '+ */' --include '*FV00*.nc'  --exclude '- *' /mnt/imos-t4/IMOS/staging/ACORN/sea-state/./ /mnt/imos-t3/IMOS/opendap/ACORN/vector/
