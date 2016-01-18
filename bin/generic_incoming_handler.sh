#!/bin/bash

DEFAULT_BACKUP_RECIPIENT=sys.admin@emii.org.au

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
set_enrivonment() {
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
  -f, --fs                   Push to filesystem. S3 Pushing is opportunistic."
    exit 3
}

# main
# $1 - file to handle
main() {
    local tmp_getops
    tmp_getops=`getopt -o hr:e:c:E:b:f --long help,regex:,exec:,checks:,env:,email:,fs -- "$@"`
    [ $? != 0 ] && usage

    eval set -- "$tmp_getops"
    local regex path_evaluation_executable checks backup_recipient
    local -i push_to_fs=0

    # parse the options
    while true ; do
        case "$1" in
            -h|--help) usage;;
            -r|--regex) regex="$2"; shift 2;;
            -e|--exec) path_evaluation_executable="$2"; shift 2;;
            -c|--checks) checks="$2"; shift 2;;
            -E|--env) set_enrivonment "$2"; shift 2;;
            -b|--email) backup_recipient="$2"; shift 2;;
            -f|--fs) push_to_fs=1; shift 1;;
            --) shift; break;;
            *) usage;;
        esac
    done

    local file=$1; shift

    [ x"$path_evaluation_executable" = x ] && usage
    [ x"$backup_recipient" = x ] && backup_recipient=$DEFAULT_BACKUP_RECIPIENT

    if [ x"$regex" != x ]; then
        regex_filter "$regex" $file || file_error "Did not pass regex filter '$regex'"
    fi

    local tmp_file
    tmp_file=`trigger_checkers_and_add_signature $file $backup_recipient $checks` || return 1

    local path_hierarchy
    path_hierarchy=`$DATA_SERVICES_DIR/$path_evaluation_executable $file`
    if [ $? -ne 0 ] || [ x"$path_hierarchy" = x ]; then
        rm -f $tmp_file
        file_error "Could not evaluate path for '$file' using '$path_evaluation_executable'"
    fi

    if [ $push_to_fs == 0 ]; then
        s3_put $tmp_file IMOS/$path_hierarchy && rm -f $file
    elif [ $push_to_fs == 1 ]; then
        s3_put_no_index_keep_file $tmp_file IMOS/$path_hierarchy
        move_to_production_force $tmp_file $OPENDAP_DIR/1 IMOS/opendap/$path_hierarchy && \
            rm -f $file
    fi
}

main "$@"
