#!/bin/bash

# Update real-time netCDF files and plots for Maria and North
# Stradbroke Island NRS from .csv files on CMAR ftp site.


export MPLCONFIGDIR=/tmp
export PYTHONPATH="$DATA_SERVICES_DIR/ANMN"
UPDATE="$PYTHONPATH/NRSrealtime/rtUpdate.py"


# Process Maria Island

TMP_MAI="$WIP_DIR/ANMN/NRS/REAL_TIME/NRSMAI"
OPENDAP_MAI=$OPENDAP_IMOS_DIR/ANMN/NRS/REAL_TIME/NRSMAI
PUBLIC_MAI=$PUBLIC_IMOS_DIR/ANMN/NRS/NRSMAI/realtime

# mkdir -pv $TMP_MAI
# cd $TMP_MAI && $UPDATE NRSMAI MariaIsland_3 -d $OPENDAP_MAI -p $PUBLIC_MAI


# Process North Stradbroke Island

TMP_NSI="$WIP_DIR/ANMN/NRS/REAL_TIME/NRSNSI"
OPENDAP_NSI=$OPENDAP_IMOS_DIR/ANMN/NRS/REAL_TIME/NRSNSI
PUBLIC_NSI=$PUBLIC_IMOS_DIR/ANMN/NRS/NRSNSI/realtime

mkdir -pv $TMP_NSI
cd $TMP_NSI && $UPDATE NRSNSI NorthStradbroke1 -n 20 60 -d $OPENDAP_NSI -p $PUBLIC_NSI
