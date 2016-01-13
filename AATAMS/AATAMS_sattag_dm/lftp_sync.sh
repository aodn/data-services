#!/bin/bash

source $DATA_SERVICES_DIR/env

declare -r FTP_SOURCE=smuc.st-and.ac.uk
declare -r FTP_USER=IMOS
declare -r FTP_PASSWORD=Xav_Access
FTP_EXTRA_OPTS=""

# useful for testing, do not synchronize everything
#FTP_EXTRA_OPTS="--include-glob=ct8*.zip"

declare -r AATAMS_SATTAG_DM_WIP_DIR=$WIP_DIR/AATAMS_SATTAG_DM
declare -r ZIPPED_DIR=$AATAMS_SATTAG_DM_WIP_DIR/zipped

# sync files from remote AATAMS ftp server
# $1 - lftp log file
sync_files() {
    local lftp_log_file=$1; shift
    lftp -e "open -u $FTP_USER,$FTP_PASSWORD $FTP_SOURCE; lcd $ZIPPED_DIR; mirror -e --parallel=10 $FTP_EXTRA_OPTS --exclude-glob *_ODV.zip -vvv --log=$lftp_log_file; quit"
}

# main
main() {
    mkdir -p $ZIPPED_DIR
    local tmp_lftp_output_file=`mktemp`
    sync_files $tmp_lftp_output_file

    mv $tmp_lftp_output_file $INCOMING_DIR/AATAMS/AATAMS_SATTAG_DM/aatams_sattag_dm_lftp.`date +%Y%m%d-%H%M%S`.log
}

main "$@"
