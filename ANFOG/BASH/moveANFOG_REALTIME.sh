#!/bin/bash

RSYNC_SOURCE_PATH=/mnt/imos-t4/IMOS/staging/ANFOG/realtime
RSYNC_DEST_PUBLIC_PATH=/mnt/imos-t4/IMOS/public/ANFOG/Realtime
RSYNC_DEST_ARCHIVE_PATH=/mnt/imos-t4/IMOS/archive/ANFOG/realtime
RSYNC_DESTINATION_PATH=/mnt/opendap/1/IMOS/opendap/ANFOG/ANFOG/REALTIME

# rsync between staging and archive : move seaglider comm.log files
rsync -avr --remove-source-files --include '+ */' --include '*.log' --exclude '- *' ${RSYNC_SOURCE_PATH}/seaglider/ ${RSYNC_DEST_ARCHIVE_PATH}/seaglider/

# rsync between staging and public : move png's
rsync -avr  --remove-source-files --include '+ */' --include '*.png' --exclude '- *' ${RSYNC_SOURCE_PATH}/ ${RSYNC_DEST_PUBLIC_PATH}/

# rsync between staging and opendap : move data to opendap 
rsync -avr --min-size=1 --remove-source-files --include '+ */' --include '*.nc' --exclude '- *'  ${RSYNC_SOURCE_PATH}/ ${RSYNC_DESTINATION_PATH}/
