#!/bin/bash

alias error_dir="cd $ERROR_DIR"
alias incoming_dir="cd $INCOMING_DIR"

declare -x -r PROJECTOFFICER_USER=`stat --printf="%U" $DATA_SERVICES_DIR/env`
alias sudo_project_officer="sudo -u $PROJECTOFFICER_USER -s"
