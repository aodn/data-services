#!/bin/bash

RSYNC_SOURCE_PATH=$INCOMING_DIR/ANFOG/realtime
RSYNC_DEST_PUBLIC_PATH=$PUBLIC_DIR/ANFOG/Realtime
RSYNC_DEST_ARCHIVE_PATH=$ARCHIVE_DIR/IMOS/ANFOG/realtime
RSYNC_DESTINATION_PATH=$OPENDAP_IMOS_DIR/ANFOG/REALTIME

# rsync between staging and archive : move seaglider comm.log files
rsync -vr --remove-source-files --include '+ */' --include '*.log' --exclude '- *' ${RSYNC_SOURCE_PATH}/seaglider/ ${RSYNC_DEST_ARCHIVE_PATH}/seaglider/

# rsync between staging and public : move png's
rsync -vr --remove-source-files --include '+ */' --include '*.png' --exclude '- *' ${RSYNC_SOURCE_PATH}/ ${RSYNC_DEST_PUBLIC_PATH}/

#CALL SCRIPT TO PROCESS  SLOCUM DATA. THE RSYNC IS DONE IN THIS PROCESS
/usr/local/bin/matlab -nodisplay -r  "run /mnt/ebs/data-services/ANFOG/ANFOG_process_REALTIME_matlab/slocum_glider/slocum_realtime_main.m"

# SEAGLIDER : rsync between staging and opendap : move data to opendap 
rsync -vr --min-size=1 --remove-source-files --include '+ */' --include '*.nc' --exclude '- *'  ${RSYNC_SOURCE_PATH}/seaglider/ ${RSYNC_DESTINATION_PATH}/seaglider/
