#!/bin/bash

RSYNC_SOURCE_PATH=$INCOMING_DIR/ANFOG/realtime
RSYNC_DEST_PUBLIC_PATH=$PUBLIC_DIR/ANFOG/Realtime
RSYNC_DEST_ARCHIVE_PATH=$ARCHIVE_DIR/ANFOG/realtime
RSYNC_DESTINATION_PATH=$OPENDAP_DIR/1/IMOS/opendap/ANFOG/REALTIME

# rsync between staging and archive : move seaglider comm.log files
rsync -vr --remove-source-files --include '+ */' --include '*.log' --exclude '- *' ${RSYNC_SOURCE_PATH}/seaglider/ ${RSYNC_DEST_ARCHIVE_PATH}/seaglider/

# rsync between staging and public : move png's
rsync -vr --remove-source-files --include '+ */' --include '*.png' --exclude '- *' ${RSYNC_SOURCE_PATH}/ ${RSYNC_DEST_PUBLIC_PATH}/

# rsync between staging and opendap : move data to opendap 
rsync -vr --min-size=1 --remove-source-files --include '+ */' --include '*.nc' --exclude '- *'  ${RSYNC_SOURCE_PATH}/ ${RSYNC_DESTINATION_PATH}/
