#!/bin/bash

# Grab real-time CO2 data in csv format from staging, write them to
# netCDF and upload to opendap.


export PYTHONPATH="$DATA_SERVICES_DIR/ANMN"
UPDATE="$PYTHONPATH/NRSrealtime/rtCO2.py"

TMPPATH="$WIP_DIR/ANMN/AM"
INCOMING="$INCOMING_DIR/ANMN/AM"
OPENDAP="$OPENDAP_IMOS_DIR/ANMN/AM"


# Kangaroo Island
mkdir -pv $TMPPATH/NRSKAI
cd $TMPPATH/NRSKAI && $UPDATE $INCOMING/pco2_mooring_data_KANGAROO_4.csv -u $OPENDAP/NRSKAI/CO2/real-time


# Maria Island
mkdir -pv $TMPPATH/NRSMAI
cd $TMPPATH/NRSMAI && $UPDATE $INCOMING/pco2_mooring_data_MARIA_9.csv -u $OPENDAP/NRSMAI/CO2/real-time


# Yongala
mkdir -pv $TMPPATH/NRSYON
cd $TMPPATH/NRSYON && $UPDATE $INCOMING/pco2_mooring_data_YONGALA_3.csv -u $OPENDAP/NRSYON/CO2/real-time
