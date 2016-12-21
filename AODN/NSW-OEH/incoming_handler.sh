#!/bin/bash

export PYTHONPATH="$DATA_SERVICES_DIR/lib/python"
export SCRIPTPATH="$DATA_SERVICES_DIR/AODN/NSW-OEH"

declare -r BACKUP_RECIPIENT=sebastien.mancini@utas.edu.au


# notify_uploader - send email report to uploader of $INCOMING_FILE and log where it was sent.
# if can't find uploader, send to $BACKUP_RECIPIENT instead
# $1 - file containing the message body
# $2 - message subject
notify_uploader() {
    local report=$1; shift
    local subject="$1"; shift

    local uploader_email
    uploader_email=`get_uploader_email $INCOMING_FILE` || uploader_email=$BACKUP_RECIPIENT

    cat $report | notify_by_email $uploader_email "$subject" && \
        log_info "Email report sent to '$uploader_email'"
}

# main - handle a zip file containing data and metadata for
# one survey from NSW-OEH
# $1 - zip file to handle
main() {
    local zipfile="$1"; shift
    local zipfile_basename=`basename $zipfile`

    # set up temp unzip directory and report file
    local unzip_dir=`mktemp -d --tmpdir ${JOB_NAME}_XXXXX`
    chmod 755 $unzip_dir  # make directory world readable
    local report=`get_log_file $LOG_DIR $INCOMING_FILE`
    trap "rm -rf --preserve-root $unzip_dir && rm -f $zipfile" EXIT

    # Check zip contents and unzip (report: list of extracted files, or errors)
    local dest_path
    log_info "Checking '$zipfile' and unzipping into '$unzip_dir'"
    dest_path=`$SCRIPTPATH/process_zip.py $zipfile $unzip_dir 2> $report`
    if [ $? -ne 0 ]; then
        notify_uploader $report "Failed to process '$zipfile_basename'"
        file_error "Zip file content failed checks"
    fi
    [ -n "$dest_path" ] || file_error "Could not determine destination path for file"

    # index and publish extracted files
    log_info "Publishing `cat $report | wc -l` extracted files..."

    index_files_bulk $unzip_dir $dest_path $report
    if [ $? -ne 0 ]; then
        # indexing failed... let uploader AND backup recipient know!
        notify_uploader $report "Contents of '$zipfile_basename' were extracted but publishing failed"
        cat $report | notify_by_email $BACKUP_RECIPIENT "$subject" &&
            log_info "Email report sent to '$BACKUP_RECIPIENT'"

        # unindex all files previously indexed to maintain db consistency with S3
        unindex_files_bulk $unzip_dir $dest_path $report
        file_error "Indexing failed"
    fi

    for file in `cat $report`; do
        s3_put_no_index "$unzip_dir/$file" "$dest_path/$file"
    done

    # email report to uploader (sort processed file names in $report)
    notify_uploader $report "Successfully processed '$zipfile_basename'"

    # remove any previous versions of the zip file from the error directory
    delete_files_in_error_dir $zipfile_basename
}


main "$@"
