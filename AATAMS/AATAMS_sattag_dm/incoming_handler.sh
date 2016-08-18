#!/bin/bash

AATAMS_SATTAG_DM_WIP_DIR=$WIP_DIR/$JOB_NAME
ZIPPED_DIR=$AATAMS_SATTAG_DM_WIP_DIR/zipped
UNZIPPED_DIR=$AATAMS_SATTAG_DM_WIP_DIR/unzipped
REQUIRED_TABLES="haulout_orig cruise ctd diag summary"
AATAMS_SATTAG_DM_ERROR_DIR=$ERROR_DIR/$JOB_NAME
AATAMS_SATTAG_DM_INCOMING_DIR=$INCOMING_DIR/AATAMS/AATAMS_SATTAG_DM
# prefix to attach to harvested files, this will be prepended to the file name
# in the `url` table of indexed_file. in short, files will be indexed as:
# $AATAMS_SATTAG_DM_BASE/some_file.mdb
AATAMS_SATTAG_DM_BASE=IMOS/AATAMS/AATAMS_SATTAG_DM

# copy a file to archive directory
# $1 - file to copy
copy_to_archive() {
    local file=$1; shift
    # overwrite file, in case it already exists
    rm -f $ARCHIVE_DIR/$AATAMS_SATTAG_DM_BASE/`basename $file`

    local tmp_dir=`mktemp -d`
    cp $file $tmp_dir
    move_to_archive $tmp_dir/`basename $file` $AATAMS_SATTAG_DM_BASE

    rmdir $tmp_dir
}

# handle bulk deletion of files, unindex them
# $1 - manifest of deleted files (new line separated)
handle_deletions() {
    local tmp_files_deleted=$1; shift

    local deleted_mdb_files=`mktemp`

    # guess mdb files that were deleted by zip file name
    local zip_file
    for zip_file in `cat $tmp_files_deleted`; do
        # assume fileXXX.zip holds just fileXXX.mdb
        # replace .zip -> .mdb
        local deleted_mdb_file=`echo $zip_file | sed -e 's/\.zip$/.mdb/'`

        log_info "Assuming '$deleted_mdb_file' was deleted, because '$zip_file' was deleted"

        if [ -f $deleted_mdb_file ]; then
            log_info "Removing deleted mdb file '$UNZIPPED_DIR/$deleted_mdb_file'"
            rm -f $UNZIPPED_DIR/$deleted_mdb_file
        else
            log_info "Deleted mdb file '$UNZIPPED_DIR/$deleted_mdb_file' not found on disk"
        fi

        echo $deleted_mdb_file >> $deleted_mdb_files
    done

    # unindex multiple files that were deleted
    if ! unindex_files_bulk $UNZIPPED_DIR $AATAMS_SATTAG_DM_BASE $deleted_mdb_files; then
        rm -f $deleted_mdb_files
        file_error "Failed unindexing files, aborting operation..."
    fi
}

# handle bulk addition of files, index them
# $1 - manifest of added files (new line separated)
handle_additions() {
    local tmp_files_added=$1; shift

    local new_mdb_files=`mktemp`

    local -i retval=0

    local zip_file
    local extracted_files_tmp=`mktemp`
    for zip_file in `cat $tmp_files_added`; do
        unzip_file $zip_file $UNZIPPED_DIR $extracted_files_tmp
        let retval=$retval+$? # accumulate result

        cat $extracted_files_tmp >> $new_mdb_files
    done
    rm -f $extracted_files_tmp

    # verify file validity (make sure they contain all tables)
    local valid_new_mdb_files=`mktemp`
    local mdb_file
    for mdb_file in `cat $new_mdb_files`; do
        if ! mdb_has_tables $UNZIPPED_DIR/$mdb_file $REQUIRED_TABLES; then
            log_error "File '$mdb_file' is missing tables"

            mkdir -p $AATAMS_SATTAG_DM_ERROR_DIR
            cp $UNZIPPED_DIR/$mdb_file $AATAMS_SATTAG_DM_ERROR_DIR/
        else
            log_info "File '$mdb_file' has all tables ('$REQUIRED_TABLES')"
            echo $mdb_file >> $valid_new_mdb_files
        fi
    done
    rm -f $new_mdb_files

    if [ `cat $valid_new_mdb_files | wc -l` -eq 0 ]; then
        file_error "No valid files to index"
    fi

    # finally, harvest the files!
    if ! index_files_bulk $UNZIPPED_DIR $AATAMS_SATTAG_DM_BASE $valid_new_mdb_files; then
        rm -f $valid_new_mdb_files
        local process_tree=`pstree -aspG $$`
        file_error "Failed indexing files, aborting operation. Process tree follows '$process_tree'"
    fi

    for zip_file in `cat $tmp_files_added`; do
        copy_to_archive $zip_file
    done
}

# handle a single zip file, copy to wip dir and generate a manifest
# $1 - zip file
handle_zip_file() {
    local zip_file=$1; shift
    local manifest_file=`mktemp`
    local zip_file_in_wip_dir="$ZIPPED_DIR/"`basename $zip_file`
    log_info "Handling single zip file '$zip_file_in_wip_dir'"

    mv $zip_file $zip_file_in_wip_dir || \
        file_error "Cannot move '$zip_file' -> '$zip_file_in_wip_dir'"

    # push manifest back to incoming directory (mock as lftp manifest)
    echo "get -O `dirname $zip_file_in_wip_dir` ftp://manual@`hostname --long`/`basename $zip_file_in_wip_dir`" > $manifest_file
    mv $manifest_file $AATAMS_SATTAG_DM_INCOMING_DIR/aatams_sattag_dm_manual.`date +%Y%m%d-%H%M%S`.log
}

# handle a single mdb file, simply zip it and push back to same directory
# $1 - mdb file
handle_mdb_file() {
    local mdb_file=$1; shift
    # simply push the zip file into the same directory
    local zip_file=`echo $AATAMS_SATTAG_DM_INCOMING_DIR/\`basename $mdb_file\` | sed -e 's/\.mdb$/.zip/'`
    log_info "Handling single mdb file '"`basename $mdb_file`"', pushing back as '"`basename $zip_file`"'"
    (cd `dirname $mdb_file` && zip $zip_file `basename $mdb_file`)

    rm -f $mdb_file
}

# handle a lftp manifest file (bulk operation)
# $1 - manifest file
handle_manifest_file() {
    local manifest_file=$1; shift

    log_info "Handling lftp file '$manifest_file'"

    local tmp_files_added=`mktemp`
    local tmp_files_deleted=`mktemp`

    get_lftp_deletions $manifest_file $UNZIPPED_DIR > $tmp_files_deleted
    local -i deletions_count=`cat $tmp_files_deleted | wc -l`

    get_lftp_additions $manifest_file $UNZIPPED_DIR > $tmp_files_added
    local -i additions_count=`cat $tmp_files_added | wc -l`

    log_info "Handling '$deletions_count' deletions"
    log_info "Handling '$additions_count' additions"

    mkdir -p $ZIPPED_DIR $UNZIPPED_DIR

    [ $deletions_count -gt 0 ] && handle_deletions $tmp_files_deleted

    [ $additions_count -gt 0 ] && handle_additions $tmp_files_added

    rm -f $tmp_files_added $tmp_files_deleted

    log_info "Successfully handled all AATAMS_SATTAG_DM files!"

    mkdir -p $AATAMS_SATTAG_DM_WIP_DIR/lftp-logs/
    mv $manifest_file $AATAMS_SATTAG_DM_WIP_DIR/lftp-logs/
}

# main
# $1 - file to handle, can be one of:
#       * lftp manifest (list of zip files)
#       * single zip file
main() {
    local file=$1; shift

    if has_extension $file "zip"; then
        handle_zip_file $file
    elif has_extension $file "mdb"; then
        handle_mdb_file $file
    else
        handle_manifest_file $file
    fi

    rm -f $file
}

main "$@"
