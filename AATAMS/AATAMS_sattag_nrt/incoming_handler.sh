#!/bin/bash
AATAMS_NRT_WIP=$WIP_DIR/AATAMS/AATAMS_sattag_nrt/NETCDF/AATAMS/AATAMS_sattag_nrt
AATAMS_NRT_BASE=IMOS/AATAMS/AATAMS_sattag_nrt

DEFAULT_BACKUP_RECIPIENT=laurent.besnard@utas.edu.au

netcdf_check_added_files() {
    local manifest_file=$1; shift
    local tmp_files_added=$1; shift
    local -i retval=0

    # run checker on files
    local file
    for file in `cat $tmp_files_added`; do
        if ! netcdf_checker -t=cf $file; then
            log_error "'$file' is not a valid NetCDF file"
            let retval=$retval+1
        fi
    done

    [ $retval -ne 0 ] && \
        file_error "Not all files passed NetCDF checking, aborting operation..."
}

# handle bulk addition of files (index + upload)
# $1 - manifest of added files (new line separated)
handle_additions() {
    local tmp_files_added=$1; shift
    local tmp_files_added_relative=`mktemp`

    sed -e "s#${AATAMS_NRT_WIP}/##" $tmp_files_added > $tmp_files_added_relative
    # index multiple files that were added
    index_files_bulk $AATAMS_NRT_WIP $AATAMS_NRT_BASE $tmp_files_added_relative || \
        file_error "Failed indexing files, aborting operation..."

    rm -f tmp_files_added_relative

    # upload files to s3
    local file
    for file in `cat $tmp_files_added`; do
        # keep files in wip dir
        log_info "$file"
        file_no_base=`echo $file | sed "s#${AATAMS_NRT_WIP}/##g"`
        s3_put_no_index $file $AATAMS_NRT_BASE/$file_no_base || \
            file_error "Failed uploading '$file', aborting operation..."
    done
}

# main
# $1 - file to handle
main() {
    local manifest_file=$1; shift
    local tmp_files_added=`mktemp`
    [[ `basename $manifest_file` == 'manifest' ]] || \
        file_error "Failed indexing manifest file, wrong name '$manifest_file' , aborting operation..."
    log_info "Handling rsync file '$manifest_file'"

    cat $manifest_file | grep -E "^/.*/IMOS_AATAMS-SATTAG_TSP_.*\.nc$" > $tmp_files_added
    local -i additions_count=`cat $tmp_files_added | wc -l`
    log_info "Handling '$additions_count' additions"

    [ $additions_count -gt 0 ] && netcdf_check_added_files $manifest_file $tmp_files_added
    [ $additions_count -gt 0 ] && handle_additions $tmp_files_added

    rm -f $tmp_files_added $manifest_file

    log_info "Successfully handled all aatams nrt files!"
}


main "$@"
