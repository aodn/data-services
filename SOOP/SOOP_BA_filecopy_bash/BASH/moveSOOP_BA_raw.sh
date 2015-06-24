#!/bin/bash

RSYNC_SOURCE_RAW_PATH=/mnt/imos-t4/IMOS/staging/SOOP/BA/Raw_data
RSYNC_DEST_RAW_PATH=/mnt/imos-t4/IMOS/archive/SOOP/BA/raw

# rsync between staging and  archive: move raw data
rsync -vr --remove-source-files ${RSYNC_SOURCE_RAW_PATH}/ ${RSYNC_DEST_RAW_PATH}/

