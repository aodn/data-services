#!/bin/bash

RSYNC_SOURCE_PATH=/mnt/imos-t4/IMOS/staging/ANFOG/processed
RSYNC_SOURCE_IMAGES_PATH=/mnt/imos-t4/IMOS/staging/ANFOG/jpeg
RSYNC_SOURCE_RAW_PATH=/mnt/imos-t4/IMOS/staging/ANFOG/raw
RSYNC_DEST_PUBLIC_PATH=/mnt/imos-t4/IMOS/public/ANFOG
RSYNC_DEST_ARCHIVE_PATH=/mnt/imos-t4/IMOS/archive/ANFOG
RSYNC_DEST_PATH=/mnt/opendap/1/IMOS/opendap/ANFOG

# rsync between staging and opendap : move data to opendap
rsync -vr -O --remove-source-files --include '+ */' --include '*FV01*.nc' --exclude '- *' ${RSYNC_SOURCE_PATH}/seaglider/ ${RSYNC_DEST_PATH}/seaglider/
rsync -vr -O --remove-source-files --include '+ */' --include '*FV01*.nc' --exclude '- *' ${RSYNC_SOURCE_PATH}/slocum_glider/ ${RSYNC_DEST_PATH}/slocum_glider/

# rsync between staging and public : move images and kml to public
rsync -r -O --remove-source-files ${RSYNC_SOURCE_IMAGES_PATH}/seaglider/ ${RSYNC_DEST_PUBLIC_PATH}/seaglider/
rsync -r -O --remove-source-files ${RSYNC_SOURCE_IMAGES_PATH}/slocum_glider/ ${RSYNC_DEST_PUBLIC_PATH}/slocum_glider/

# rsync between staging and archive : move raw to archive
rsync -r -O --remove-source-files ${RSYNC_SOURCE_RAW_PATH}/seaglider/ ${RSYNC_DEST_ARCHIVE_PATH}/seaglider/
rsync -r -O --remove-source-files ${RSYNC_SOURCE_RAW_PATH}/slocum_glider/ ${RSYNC_DEST_ARCHIVE_PATH}/slocum_glider/
