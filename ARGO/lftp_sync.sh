#!/bin/bash

ARGO_SRC_HOST=ftp.ifremer.fr
ARGO_SRC=/ifremer/argo/dac
ARGO_DEST=/mnt/opendap/1/IMOS/opendap/Argo/dac
ARGO_LOG=/mnt/imos-t4/log/argo_lftp.log

lftp -e "mirror -e --parallel=10 --log=$ARGO_LOG $ARGO_SRC $ARGO_DEST ; quit" $ARGO_SRC_HOST
