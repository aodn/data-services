#!/bin/bash

# Avoid running this script if variables are undefined
set -u

ARGO_SRC_HOST=ftp.ifremer.fr
ARGO_SRC=/ifremer/argo/dac
ARGO_DEST=$OPENDAP_DIR/1/IMOS/opendap/Argo/dac
ARGO_LOG=$LOG_DIR/argo_lftp.log

lftp -e "mirror -e --parallel=10 --log=$ARGO_LOG $ARGO_SRC $ARGO_DEST ; quit" $ARGO_SRC_HOST
