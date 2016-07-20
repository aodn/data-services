#!/bin/bash

ARGO_WIP_DIR=$WIP_DIR/Argo/dac

ARGO_BASE=IMOS/Argo/dac

# run netcdf checking on given files in manifest
# $1 - manifest of all files (file uploaded to incoming directory)
# $2 - manifest of added files (new line separated)
netcdf_check_added_files() {
    local manifest_file=$1; shift
    local tmp_files_added=$1; shift
    local -i retval=0

    # run checker on files
    local file
    for file in `cat $tmp_files_added`; do
        file=$ARGO_WIP_DIR/$file
        if ! check_netcdf $file; then
            log_error "'$file' is not a valid NetCDF file"
            let retval=$retval+1
        fi
    done

    [ $retval -ne 0 ] && \
        file_error "Not all files passed NetCDF checking, aborting operation..."
}

# handle bulk deletion of files (unindex + delete)
# $1 - manifest of all files (file uploaded to incoming directory)
# $2 - manifest of deleted files (new line separated)
handle_deletions() {
    local manifest_file=$1; shift
    local tmp_files_deleted=$1; shift

    # unindex multiple files that were deleted
    unindex_files_bulk $ARGO_WIP_DIR $ARGO_BASE $tmp_files_deleted || \
        file_error "Failed unindexing files, aborting operation..."

    # delete files from s3
    local file
    for file in `cat $tmp_files_deleted`; do
        s3_del_no_index $ARGO_BASE/$file || \
            file_error "Failed deleting '$file', aborting operation..."
    done
}

# handle bulk addition of files (index + upload)
# $1 - manifest of all files (file uploaded to incoming directory)
# $2 - manifest of added files (new line separated)
handle_additions() {
    local manifest_file=$1; shift
    local tmp_files_added=$1; shift

    # index multiple files that were added
    index_files_bulk $ARGO_WIP_DIR $ARGO_BASE $tmp_files_added || \
        file_error "Failed indexing files, aborting operation..."

    # upload files to s3
    local file
    for file in `cat $tmp_files_added`; do
        # keep files in wip dir
        s3_put_no_index_keep_file $ARGO_WIP_DIR/$file $ARGO_BASE/$file || \
            file_error "Failed uploading '$file', aborting operation..."
    done
}


# lock processing of talend trigger to prevent simultanous talend runs
lock() {
    exec 200>$DATA_SERVICES_TMP_DIR/argo_pid.lock

    flock -n 200 \
        && return 0 \
        || return 1
}


# main
# $1 - file to handle
main() {
    local manifest_file=$1; shift

    log_info "Handling rsync file '$manifest_file'"

    local tmp_files_added=`mktemp`
    local tmp_files_deleted=`mktemp`

    # filter only on files with .nc extension. sometimes files on ifremer will
    # have awkward extensions, like file.nc.74 for instance

    get_rsync_deletions $manifest_file | grep "\.nc$" > $tmp_files_deleted
    local -i deletions_count=`cat $tmp_files_deleted | wc -l`

    get_rsync_additions $manifest_file | grep "\.nc$" > $tmp_files_added
    local -i additions_count=`cat $tmp_files_added | wc -l`

    log_info "Handling '$deletions_count' deletions"
    log_info "Handling '$additions_count' additions"

    lock || {
        log_info "Only one talend process can be run at once";
        exit 1
    }

    [ $additions_count -gt 0 ] && netcdf_check_added_files $manifest_file $tmp_files_added

    [ $deletions_count -gt 0 ] && handle_deletions $manifest_file $tmp_files_deleted

    [ $additions_count -gt 0 ] && handle_additions $manifest_file $tmp_files_added

    rm -f $tmp_files_added $tmp_files_deleted # TODO better cleanup

    log_info "Successfully handled all argo files!"

    # TODO archive log file?
    mkdir -p $WIP_DIR/Argo/rsync-logs/
    mv $manifest_file $WIP_DIR/Argo/rsync-logs/
}

main "$@"
