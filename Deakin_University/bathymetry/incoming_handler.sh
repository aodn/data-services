#!/bin/bash
DEFAULT_BACKUP_RECIPIENT=laurent.besnard@utas.edu.au
PATH_EVALUATION_EXECUTABLE='Deakin_University/bathymetry/dest_path.py'

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
    local regex=".*_Bathy_.*\.(nc|tif)$"

    regex_filter "$regex" $file || file_error "Did not pass regex filter '$regex'"

    local path_hierarchy
    path_hierarchy=`$DATA_SERVICES_DIR/$PATH_EVALUATION_EXECUTABLE $file`
    if [ $? -ne 0 ] || [ x"$path_hierarchy" = x ]; then
        file_error "Could not evaluate path for '$file' using '$PATH_EVALUATION_EXECUTABLE'"
    fi

    s3_put $file $path_hierarchy && rm -f $file
}


main "$@"
