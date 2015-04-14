#!/bin/bash

# Get latest SOFS files from BOM ftp site and sort them into the
# appropriate directories on opendap.

# PYTHONPATH points to ANMN code because we use a module in there
export PYTHONPATH="$DATA_SERVICES_DIR/ANMN"
UPDATE="$DATA_SERVICES_DIR/ABOS/sofsUpdate.py"

YEAR=`date +%Y`
RUNPATH="$WIP_DIR/ABOS/ASFS/SOFS"
TMPPATH="$RUNPATH/$YEAR"
OPENDAP="$OPENDAP_IMOS_DIR/ABOS/ASFS/SOFS"

FTPHOST="ftp.bom.gov.au"
FTPPATH="/register/bom404/outgoing/IMOS/MOORINGS/$YEAR"
FTPUSER="bom404,Vee8soxo"

mkdir -pv $RUNPATH && mkdir -pv $TMPPATH && mkdir -pv $OPENDAP

cd $RUNPATH && $UPDATE -s $FTPHOST -d $FTPPATH -u $FTPUSER  $TMPPATH  $OPENDAP 

# save logs & delete old ones
DATE=`date +%Y%m%d`
cat lftp.log  sofsUpdate.log  >sofsUpdate.$DATE.log
find $RUNPATH -maxdepth 1 -type f -name 'sofsUpdate.*.log' -mtime +30 -delete
