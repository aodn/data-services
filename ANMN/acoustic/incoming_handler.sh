#!/bin/bash

export PYTHONPATH="$DATA_SERVICES_DIR/lib/python"
export SCRIPTPATH="$DATA_SERVICES_DIR/ANMN/acoustic"

declare -r BACKUP_RECIPIENT=marty.hidas@utas.edu.au

# returns non zero if file does not match regex filter
# $1 - regex to match with
# $2 - file to validate
regex_filter() {
    local regex="$1"; shift
    local file=`basename $1`; shift
    echo $file | grep -E "$regex" -q
}


# handle a csv file containing metadata for ANMN Passive Acoustics deployments
# $1 - file to handle
handle_csv() {
    local file=$1; shift
    local basename_file=`basename $file`

    regex_filter "^IMOS.*\.csv$" $file || \
        file_error_and_report_to_uploader $BACKUP_RECIPIENT "$basename_file has incorrect name or was uploaded to the wrong place"

    # TODO Basic sanity checks

    # TODO Dump a backup of the acoustic_deployments table?

    # Rename csv to update.yyyymmdd-hhmmss.csv
    local timestamp=`date +%Y%m%d-%H%M%S`
    local dest_path="IMOS/ANMN/Acoustic/metadata/update.${timestamp}.csv"

    # Index & push to S3
    s3_put $file $dest_path
}


# main
# $1 - file to handle
main() {
    local file=$1; shift
    local basename_file=`basename $file`

    if has_extension $file "csv"; then
        handle_csv $file
    else
        file_error_and_report_to_uploader $BACKUP_RECIPIENT "Not a csv file ($basename_file)"
    fi
}

main "$@"
