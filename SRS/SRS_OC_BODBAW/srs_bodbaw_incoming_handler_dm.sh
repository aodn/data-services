#!/bin/bash
DEFAULT_BACKUP_RECIPIENT=laurent.besnard@utas.edu.au
PATH_EVALUATION_EXECUTABLE='SRS/SRS_OC_BODBAW/dest_path.py'

# returns non zero if file does not match regex filter
# $1 - regex to match with
# $2 - file to validate
regex_filter() {
    local regex="$1"; shift
    local file=`basename $1`; shift
    echo $file | grep -E $regex -q
}

# main
# $1 - file to handle
main() {
    local file=$1; shift
    local regex="^IMOS_SRS-OC-BODBAW_X_[[:digit:]]{8}T[[:digit:]]{6}Z_.*_END-[[:digit:]]{8}T[[:digit:]]{6}.*\\.(png|csv|nc)$"

    regex_filter "$regex" $file || file_error "Did not pass regex filter '$regex'"

    local path_hierarchy
    path_hierarchy=`$DATA_SERVICES_DIR/$PATH_EVALUATION_EXECUTABLE $file`
    if [ $? -ne 0 ] || [ x"$path_hierarchy" = x ]; then
        file_error "Could not evaluate path for '$file' using '$PATH_EVALUATION_EXECUTABLE'"
    fi

    local func
    if has_extension $file "nc"; then
        func=s3_put
    elif has_extension $file "csv" || has_extension $file "png"; then
        func=s3_put_no_index
    else
        file_error "Unknown file extension"
    fi

    $func $file IMOS/$path_hierarchy && rm -f $file
}

main "$@"
