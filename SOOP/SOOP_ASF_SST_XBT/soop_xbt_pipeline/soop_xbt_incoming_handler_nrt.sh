#!/bin/bash
XBT_NRT_WIPDIR=$WIP_DIR/SOOP/SOOP_XBT_ASF_SST/data_sorted/XBT/sbddata
XBT_NRT_BASE=IMOS/SOOP/SOOP-XBT/REALTIME

DEFAULT_BACKUP_RECIPIENT=laurent.besnard@utas.edu.au

# handle bulk addition of files (index + upload)
# $1 - manifest of added files (new line separated)
handle_additions() {
    local tmp_files_added=$1; shift
    local tmp_files_added_relative=`mktemp`

    sed -e "s#${XBT_NRT_WIPDIR}/##" $tmp_files_added > $tmp_files_added_relative

    # index multiple files that were added
    index_files_bulk $XBT_NRT_WIPDIR $XBT_NRT_BASE $tmp_files_added_relative || \
        file_error "Failed indexing files, aborting operation..."

    # upload files to s3
    local file
    for file in `cat $tmp_files_added`; do
        # keep files in wip dir
        log_info "$file"
        file_no_base=`echo $file | sed "s#${XBT_NRT_WIPDIR}/##g"`
        s3_put_no_index $file $XBT_NRT_BASE/$file_no_base || \
            file_error "Failed uploading '$file', aborting operation..."
    done
}


# main
# $1 - file to handle
main() {
    local manifest_file=$1; shift
    local tmp_files_added=`mktemp`
    [[ `basename $manifest_file` == 'IMOS_SOOP-XBT_NRT_fileList.csv' ]] || \
        file_error "Failed indexing manifest file, wrong name '$manifest_file' , aborting operation..."
    log_info "Handling rsync file '$manifest_file'"

    cat $manifest_file | grep -E "^/.*/IMOS_SOOP-XBT_T_.*.csv$" > $tmp_files_added
    local -i additions_count=`cat $tmp_files_added | wc -l`
    log_info "Handling '$additions_count' additions"

    [ $additions_count -gt 0 ] && handle_additions $tmp_files_added

    rm -f $tmp_files_added $manifest_file

    log_info "Successfully handled all soop xbt nrt files!"
}

main "$@"
