#!/bin/bash

source $DATA_SERVICES_DIR/env

declare -r FTP_SOURCE=$IMOS_PO_CREDS_BOM_FTP_ADDRESS
declare -r FTP_USER=$IMOS_PO_CREDS_BOM_FTP_USERNAME
declare -r FTP_PASSWORD=$IMOS_PO_CREDS_BOM_FTP_PASSWORD
FTP_EXTRA_OPTS=""

declare -r ABOS_SOFS_WIP_DIR=$WIP_DIR/ABOS/ASFS/SOFS
declare -r ABOS_SOFS_WIP_DIR_FTP=$ABOS_SOFS_WIP_DIR/ftp
declare -r ABOS_SOFS_WIP_DIR_LOG=$ABOS_SOFS_WIP_DIR/lftp-logs

# sync files from remote BoM ftp server
# $1 - lftp log file
sync_files() {
    local lftp_log_file=$1; shift
    lftp -e "open -u $FTP_USER,$FTP_PASSWORD $FTP_SOURCE; mirror -e --parallel=10 $FTP_EXTRA_OPTS -vvv --log=$lftp_log_file $FTP_DIR $ABOS_SOFS_WIP_DIR_FTP/; quit"
}

# copy files to incoming dir with the correct permissions
# $1 - subdirectory to copy to, relative to $INCOMING_DIR
# "$@" - file(s) to copy
copy_to_incoming() {
    local incoming_dir="$INCOMING_DIR/$1" ; shift

    for file; do
        local file_basename=$(basename $file)
        local tmp_file=$(mktemp -t "${file_basename}.XXXXXX")
        install -g projectofficer -m 0664 $file $tmp_file && \
            mv $tmp_file $incoming_dir/$file_basename
    done
}

# main - update SOFS files from BoM ftp site for given year
# $1 - year (current year if not given)
main() {
    local year=$1; shift
    [ -z "$year" ] && year=`date +%Y`
    declare -rg FTP_DIR="/register/bom404/outgoing/IMOS/MOORINGS/$year"

    mkdir -p $ABOS_SOFS_WIP_DIR_FTP
    local tmp_lftp_output_file=`mktemp`
    sync_files $tmp_lftp_output_file || return 1

    local tmp_files_added=`mktemp`
    get_lftp_additions $tmp_lftp_output_file $ABOS_SOFS_WIP_DIR_FTP > $tmp_files_added

    for nc_file in `cat $tmp_files_added`; do
        if has_extension $nc_file "nc"; then
            copy_to_incoming ABOS/ASFS "$ABOS_SOFS_WIP_DIR_FTP/$nc_file"
        fi
    done
    rm -f $tmp_files_added

    mkdir -p $ABOS_SOFS_WIP_DIR_LOG/
    mv $tmp_lftp_output_file $ABOS_SOFS_WIP_DIR_LOG/abos_sofs_lftp.`date +%Y%m%d-%H%M%S`.log
}

main "$@"
