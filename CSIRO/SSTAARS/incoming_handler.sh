#!/bin/bash
PATH_EVALUATION_EXECUTABLE='CSIRO/SSTAARS/dest_path.py'

# returns non zero if file does not match regex filter
# $1 - regex to match with
# $2 - file to validate
regex_filter() {
    local regex="$1"; shift
    local file=`basename $1`; shift
    echo $file | grep -E $regex -q
}

# return true (0) if file needs indexing, false (1) otherwise
# $1 - file to handle
need_index() {
    local file=$1; shift
    local regex_need_index="^SSTAARS_daily_fit_[[:digit:]]{3}\\.nc$"

    if [ regex_filter "$regex_need_index" $file ]; then
        return 0 
    else
        return 1
    fi
}

# main
# $1 - file to handle
main() {
    local file=$1; shift
    local regex="^SSTAARS(|_daily_fit(|_[[:digit:]]{3}))\\.nc$"

    regex_filter "$regex" $file || file_error "Did not pass regex filter '$regex'"

    local path_hierarchy
    path_hierarchy=`$DATA_SERVICES_DIR/$PATH_EVALUATION_EXECUTABLE $file`
    if [ $? -ne 0 ] || [ x"$path_hierarchy" = x ]; then
        file_error "Could not evaluate path for '$file' using '$PATH_EVALUATION_EXECUTABLE'"
    fi

    # index daily files
    if need_index $file; then
        s3_put $file $path_hierarchy
    else
        s3_put_no_index $file $path_hierarchy
    fi

    rm -f $file
}


main "$@"
