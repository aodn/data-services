#!/bin/bash

DEFAULT_BACKUP_RECIPIENT=null

# returns non zero if file does not match regex filter
# $1 - regex to match with
# $2 - file to validate
regex_filter() {
    local regex="$1"; shift
    local file=`basename $1`; shift
    echo $file | grep -E $regex -q
}

# sets environment, literally runs 'export name="value"'
# $1 - environment variable pair (name=value)
set_environment() {
    local env_pair=$1; shift
    eval export $env_pair
}

# prints usage and exit
usage() {
    echo "Usage: $0 [OPTIONS]... FILE"
    echo "Performs generic checks against a file, then pushes it to production."
    echo "
Options:
  -r, --regex                Regular expresions to filter by.
  -e, --exec                 Execution for path evaluation.
  -c, --checks               NetCDF Checker checks to perform on file.
  -E, --env                  Environment variables to set (name=value).
  -b, --email                Backup email recipient.
  -d, --delete               delete files ."
    exit 3
}


# main
# $1 - file to handle
main() {
    local tmp_getops
    tmp_getops=`getopt -o hr:e:c:E:b:d: --long help,regex:,exec:,checks:,env:,email:,delete: -- "$@"`
    [ $? != 0 ] && usage

    eval set -- "$tmp_getops"
    local regex path_evaluation_executable checks backup_recipient s3_base_path_deletion_granted

    # parse the options
    while true ; do
        case "$1" in
            -h|--help) usage;;
            -r|--regex) regex="$2"; shift 2;;
            -e|--exec) path_evaluation_executable="$2"; shift 2;;
            -c|--checks) checks="$2"; shift 2;;
            -E|--env) set_environment "$2"; shift 2;;
            -b|--email) backup_recipient="$2"; shift 2;;
            -d|--delete) s3_base_path_deletion_granted="$2"; shift 2;;
            --) shift; break;;
            *) usage;;
        esac
    done

    local file=$1; shift

    # THIS IS A TEST CODE SCENARIO ONLY ! NOT TO BE MERGED
    # handle file deletion by uploader.
    # tried to use the unindex_files_bulk and _bulk_index_operation function but args don't make much sense to me
    if echo `basename $file` | grep -E -q '^files_to_delete.[[:digit:]]{8}T[[:digit:]]{6}Z$'; then
        local file_to_delete
        echo $file
        [ x"$s3_base_path_deletion_granted" = x ] && file_error "--delete option not provided"

        if [ `grep -E "^${s3_base_path_deletion_granted}" $file | wc -l` -eq `cat $file | wc -l` ]; then
            for file_to_delete in `cat $file`; do
                s3_del $file_to_delete
            done
        else
            file_error "Not all s3 objects start with \"${s3_base_path_deletion_granted}\". Deletion cancelled"
        fi
        rm -f $file
        exit 0
    fi
    ## END OF TEST CODE SCENARIO

    [ x"$path_evaluation_executable" = x ] && usage
    [ x"$backup_recipient" = x ] && backup_recipient=$DEFAULT_BACKUP_RECIPIENT

    if [ x"$regex" != x ]; then
        # extract the path where the file was uploaded (relative to 'incoming')
        incoming_dir=`dirname $INCOMING_FILE`
        incoming_dir=${incoming_dir#*incoming/}

        regex_filter "$regex" $file || file_error_and_report_to_uploader $backup_recipient \
            "$(basename $file) has incorrect name or was uploaded to the wrong place ($incoming_dir)"
    fi

    local tmp_file
    tmp_file=`trigger_checkers_and_add_signature $file $backup_recipient $checks` || return 1

    local path_hierarchy
    path_hierarchy=`$DATA_SERVICES_DIR/$path_evaluation_executable $file`
    if [ $? -ne 0 ] || [ x"$path_hierarchy" = x ]; then
        rm -f $tmp_file
        file_error "Could not evaluate path for '$file' using '$path_evaluation_executable'"
    fi

    s3_put $tmp_file IMOS/$path_hierarchy && \
        rm -f $file
}

main "$@"
