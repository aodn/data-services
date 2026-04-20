#!/bin/bash

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

pyenv activate anmn-env

export DATA_SERVICES_DIR="/home/khannak/projects/AODN/data_services/data-services"
export PYTHONPATH="$DATA_SERVICES_DIR/lib/python"

export WIP_DIR="$DATA_SERVICES_DIR/ANMN/tmp/wip"
export INCOMING_DIR="$DATA_SERVICES_DIR/ANMN/tmp/incoming"
export ERROR_DIR="$DATA_SERVICES_DIR/ANMN/tmp/error"

mkdir -p "$WIP_DIR/ANMN/NRS_AIMS_Darwin_Yongala_data_rss_download_temporary/errors"
mkdir -p "$INCOMING_DIR/AODN/ANMN_NRS_DAR_YON"
mkdir -p "$ERROR_DIR/ANMN_NRS_DAR_YON"

echo
echo "Environment ready"
echo "Python      : $(python --version)"
echo "PYTHONPATH  : $PYTHONPATH"
echo "WIP_DIR     : $WIP_DIR"
echo "INCOMING_DIR: $INCOMING_DIR"
echo
echo "Now run:"
echo "  cd $DATA_SERVICES_DIR/ANMN/NRS_AIMS/REALTIME"
echo "  python anmn_nrs_aims_test.py --testing"
