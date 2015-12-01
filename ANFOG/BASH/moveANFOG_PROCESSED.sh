#!/bin/bash

RSYNC_SOURCE_PATH=$INCOMING_DIR/ANFOG/processed
RSYNC_SOURCE_IMAGES_PATH=$INCOMING_DIR/ANFOG/jpeg
RSYNC_SOURCE_RAW_PATH=$INCOMING_DIR/ANFOG/raw
RSYNC_DEST_PUBLIC_PATH=$PUBLIC_DIR/ANFOG
RSYNC_DEST_ARCHIVE_PATH=$ARCHIVE_DIR/IMOS/ANFOG
RSYNC_DEST_PATH=$OPENDAP_IMOS_DIR/ANFOG

# rsync between staging and opendap : move data to opendap
rsync -vr -O --remove-source-files --include '+ */' --include '*FV01*.nc' --exclude '- *' ${RSYNC_SOURCE_PATH}/seaglider/ ${RSYNC_DEST_PATH}/seaglider/
rsync -vr -O --remove-source-files --include '+ */' --include '*FV01*.nc' --exclude '- *' ${RSYNC_SOURCE_PATH}/slocum_glider/ ${RSYNC_DEST_PATH}/slocum_glider/

# rsync between staging and public : move images and kml to public
rsync -r -O --remove-source-files ${RSYNC_SOURCE_IMAGES_PATH}/seaglider/ ${RSYNC_DEST_PUBLIC_PATH}/seaglider/
rsync -r -O --remove-source-files ${RSYNC_SOURCE_IMAGES_PATH}/slocum_glider/ ${RSYNC_DEST_PUBLIC_PATH}/slocum_glider/

# rsync between staging and archive : move raw to archive
rsync -r -O --remove-source-files ${RSYNC_SOURCE_RAW_PATH}/seaglider/ ${RSYNC_DEST_ARCHIVE_PATH}/seaglider/
rsync -r -O --remove-source-files ${RSYNC_SOURCE_RAW_PATH}/slocum_glider/ ${RSYNC_DEST_ARCHIVE_PATH}/slocum_glider/
