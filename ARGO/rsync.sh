#!/bin/bash

# Avoid running this script if variables are undefined
set -u

ARGO_SRC_HOST=vdmzrs.ifremer.fr
ARGO_SRC=argo
ARGO_DEST=$OPENDAP_DIR/1/IMOS/opendap/Argo/dac
ARGO_LOG=$LOG_DIR/argo_rsync.log

rsync --times --delete -rzv $ARGO_SRC_HOST::$ARGO_SRC $ARGO_DEST &>> $LOG_DIR/argo_rsync.log
