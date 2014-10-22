#!/bin/bash
/usr/local/bin/matlab -nodisplay -r  "run /usr/local/bin/ANFOG/REALTIME/seaglider/seaglider_realtime_main_UNIX_v3.m"
/usr/local/bin/matlab -nodisplay -r  "run /usr/local/bin/ANFOG/REALTIME/slocum/slocum_realtime_main_UNIX_v3.m"

#get the SQL command
SEAGLIDERSQLUPD=/mnt/imos-t4/project_officers/wip/ANFOG/realtime/seaglider/output/processing
#find $SEAGLIDERSQLUPD -name '*SQL*' -type f  -exec /usr/local/bin/ANFOG/REALTIME/updatedb.sh {} \;
cp -r /mnt/imos-t4/project_officers/wip/ANFOG/realtime/seaglider/output/archive /usr/local/bin/ANFOG/REALTIME/seaglider/archive

SLOCUMSQLUPD=/mnt/imos-t4/project_officers/wip/ANFOG/realtime/slocum/output/processing
#find $SLOCUMSQLUPD -name '*SQL*' -type f  -exec /usr/local/bin/ANFOG/REALTIME/updatedb.sh {} \;
cp -r /mnt/imos-t4/project_officers/wip/ANFOG/realtime/slocum/output/archive /usr/local/bin/ANFOG/REALTIME/slocum/archive

       
