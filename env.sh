#!/bin/bash
# Local mock environment for ANMN NRS AIMS testing
# Run this before every session: source env.sh

export DATA_SERVICES_DIR="/home/khannak/projects/AODN/data_services/data-services"
export WIP_DIR="/tmp/anmn_test/wip"
export INCOMING_DIR="/tmp/anmn_test/incoming"
export ERROR_DIR="/tmp/anmn_test/error"
export PYTHONPATH="$DATA_SERVICES_DIR/lib/python"

mkdir -p "$WIP_DIR/ANMN/NRS_AIMS_Darwin_Yongala_data_rss_download_temporary/errors"
mkdir -p "$INCOMING_DIR/AODN/ANMN_NRS_DAR_YON"
mkdir -p "$ERROR_DIR/ANMN_NRS_DAR_YON"

echo "Environment loaded"
echo "  DATA_SERVICES_DIR -> $DATA_SERVICES_DIR"
echo "  WIP_DIR           -> $WIP_DIR"
echo "  INCOMING_DIR      -> $INCOMING_DIR"
echo "  PYTHONPATH        -> $PYTHONPATH"
