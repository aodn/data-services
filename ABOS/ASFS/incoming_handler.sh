#!/bin/bash

export PYTHONPATH="$DATA_SERVICES_DIR/lib/python"
export SCRIPTPATH="$DATA_SERVICES_DIR/ABOS/ASFS"

UNZIP_DIR="$WIP_DIR/$JOB_NAME"

declare -r BACKUP_RECIPIENT=marty.hidas@utas.edu.au

declare -r DATACODE="[A-Z]+"
declare -r TIMESTAMP="[0-9]{8}T[0-9]{6}Z"
declare -r FV="FV0[012]"
declare -r REGEX="^IMOS_ABOS-ASFS_${DATACODE}_${TIMESTAMP}_SOFS_${FV}.*\.nc"

declare -r CHECKS="cf imos:1.4"


# returns non zero if file does not match regex filter
# $1 - regex to match with
# $2 - file to validate
regex_filter() {
    local regex="$1"; shift
    local file=`basename $1`; shift
    echo $file | grep -E "$regex" -q
}


# handle a netcdf file for the ABOS facility
# $1 - file to handle
main() {
    local file=$1; shift
    local basename_file=`basename $file`

    regex_filter $REGEX $file || \
        file_error_and_report_to_uploader $BACKUP_RECIPIENT "File '$basename_file' has incorrect name or was uploaded to the wrong directory"

    local tmp_file
    tmp_file=`trigger_checkers_and_add_signature $file $BACKUP_RECIPIENT $CHECKS` || return 1

    local dest_path
    dest_path=`$SCRIPTPATH/dest_path.py $file`
    if [ $? -ne 0 ] || [ -z "$dest_path" ]; then
        rm -f $tmp_file
        file_error_and_report_to_uploader $BACKUP_RECIPIENT "Could not determine destination path for '$basename_file'"
    fi

    # TODO: archiving of previous versions (rarely needed)

    s3_put $tmp_file $dest_path && \
        rm -f $file

    # let uploader know we've published the file
    local uploader_email
    local message="The file can be downloaded at https://s3-ap-southeast-2.amazonaws.com/imos-data/$dest_path"
    uploader_email=`get_uploader_email $INCOMING_FILE` || uploader_email=$BACKUP_RECIPIENT
    echo $message | notify_by_email $uploader_email "Successfully published '$basename_file'"
}


main "$@"
