#!/bin/bash
DEFAULT_BACKUP_RECIPIENT=laurent.besnard@utas.edu.au
PATH_EVALUATION_EXECUTABLE='SRS/SRS_OC_BODBAW/dest_path.py'
PATH_XLS_CONVERSION_EXECUTABLE='SRS/SRS_OC_BODBAW/srs_oc_bodbaw_netcdf_creation.py'

# returns non zero if file does not match regex filter
# $1 - regex to match with
# $2 - file to validate
regex_filter() {
    local regex="$1"; shift
    local file=`basename $1`; shift
    echo $file | grep -E $regex -q
}

# $1 - excel file to convert and push back to incoming dir
process_excel() {
    local file="$1"
    local output_dir
    log_info "Converting `basename $file` into PNG/CSV/NC"
    output_dir=`$DATA_SERVICES_DIR/$PATH_XLS_CONVERSION_EXECUTABLE -i "$file"`
    # handle failure of python script
    if [ $? -ne 0 ]; then
        file_error "Could not convert XLS file" "$file"
    fi

    # copy generated files to incoming
    for f in `find $output_dir -type f`; do
        mv "$f" $INCOMING_DIR/SRS/OC/BODBAW
    done
    rmdir $output_dir

    # move xls to archive dir. File will be sync to TPAC automatically
    local archive_dir_bodbaw=$ARCHIVE_DIR/IMOS/SRS/BODBAW
    [ ! -d "$archive_dir_bodbaw" ] && mkdir -p "$archive_dir_bodbaw"
    mv "$file" "$archive_dir_bodbaw"
    rmdir `dirname "$file"`

    exit 0
}


# main
# $1 - file to handle
main() {
    local file="$1"; shift

    if has_extension $file "xls"; then
        regex_filter ".*(pigment|absorption|TSS|ac9|hs6).*\\.xls" $file && process_excel $file
    else
        local regex="^IMOS_SRS-OC-BODBAW_X_[[:digit:]]{8}T[[:digit:]]{6}Z_.*_END-[[:digit:]]{8}T[[:digit:]]{6}.*\\.(png|csv|nc)$"
        regex_filter "$regex" $file || file_error "Did not pass regex filter '$regex'"

        local path_hierarchy
        path_hierarchy=`$DATA_SERVICES_DIR/$PATH_EVALUATION_EXECUTABLE $file`
        if [ $? -ne 0 ] || [ x"$path_hierarchy" = x ]; then
            file_error "Could not evaluate path for '$file' using '$PATH_EVALUATION_EXECUTABLE'"
        fi

        local func
        if has_extension $file "nc"; then
            local checks='cf'
            tmp_file_with_sig=`trigger_checkers_and_add_signature $file $DEFAULT_BACKUP_RECIPIENT $checks`
            s3_put $tmp_file_with_sig IMOS/$path_hierarchy && rm -f $file $tmp_file_with_sig
        elif has_extension $file "csv" || has_extension $file "png"; then
            s3_put_no_index $file IMOS/$path_hierarchy && rm -f $file
        else
            file_error "Unknown file extension"
        fi
    fi
}

main "$@"
