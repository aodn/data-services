#!/bin/bash

export PYTHONPATH="$DATA_SERVICES_DIR/lib/python"
export SCRIPTPATH="$DATA_SERVICES_DIR/ABOS/common"

UNZIP_DIR="$WIP_DIR/$JOB_NAME"

declare -r BACKUP_RECIPIENT=marty.hidas@utas.edu.au
declare -r DATACODE="[A-Z]+"
declare -r TIMESTAMP="[0-9]{8}(T[0-9]{6}Z)?"
declare -r FV="FV0[012]"
declare -r PRODUCT="[^_]+"
declare -r PART="PART[0-9]+"


# returns non zero if file does not match regex filter
# $1 - regex to match with
# $2 - file to validate
regex_filter() {
    local regex="$1"; shift
    local file=`basename $1`; shift
    echo $file | grep -E "$regex" -q
}


# trigger netcdf checker for file - SKIP CF check_reduced_horizontal_grid
# $1 - file
# $2 - backup email recipient (passing 'null' implies no email sending)
# "$@" - suites (checkers) to trigger
trigger_checkers() {
    local file=$1; shift
    local backup_recipient=$1; shift

    error_handler=file_error
    if [ "$backup_recipient" != "null" ]; then
        error_handler="file_error_and_report_to_uploader $backup_recipient"
    fi

    check_netcdf $file || \
        $error_handler "Not a NetCDF file"

    local check_suite
    local extra_opts
    for check_suite in "$@"; do
        if [ "$check_suite" == "cf" ]; then
            extra_opts='--skip-checks check_reduced_horizontal_grid'
            log_warn "Skipping CF check_reduced_horizontal_grid while checking $file"
        else
            extra_opts=''
        fi
        netcdf_checker $file --test=$check_suite $extra_opts || \
            $error_handler "NetCDF file does not comply with '${check_suite}' conventions"
    done
}
export -f trigger_checkers


# handle a netcdf file for the ABOS facility
# $1 - file to handle
handle_netcdf() {
    local file=$1; shift
    local basename_file=`basename $file`

    regex_filter $REGEX $file || \
        file_error_and_report_to_uploader $BACKUP_RECIPIENT "File '$basename_file' has incorrect name or was uploaded to the wrong directory"

    local tmp_file
    tmp_file=`trigger_checkers_and_add_signature $file $BACKUP_RECIPIENT $CHECKS` || return 1

    local dest_path
    dest_path=`$SCRIPTPATH/dest_path.py $file`
    if [ $? -ne 0 ] || [ -z "$dest_path" ]; then
        rm -f $tmp_file
        file_error "Could not determine destination path for file"
    fi

    # TODO: archiving of previous versions (rarely needed)

    s3_put $tmp_file $dest_path && \
        rm -f $file
}


# handle a zip file containing NetCDF files for the ABOS facility
# $1 - zip file to handle
handle_zip() {
    local zipfile=$1; shift

    # unzip the file
    log_info "Unzipping '$zipfile' to $UNZIP_DIR"
    mkdir -pv $UNZIP_DIR
    local extracted_files=`mktemp`
    unzip_file $zipfile $UNZIP_DIR $extracted_files || file_error "Failed to unzip"

    # abort operation if there are any non-NetCDF files in archive
    # (don't know how to handle them)
    grep -v '\.nc$' $extracted_files && file_error "Zip file contains non-NetCDF files"

    # process extracted files
    local n_extracted=`cat $extracted_files | wc -l`
    log_info "Processing $n_extracted extracted files..."
    for file in `cat $extracted_files`; do
        handle_netcdf $UNZIP_DIR/$file
    done
    rm -f $zipfile $extracted_files
}

# prints usage and exit
usage() {
    echo "Usage: $0 [OPTIONS]... FILE"
    echo "Performs generic checks against an ABOS file, then pushes it to production."
    echo "
Options:
  -s, --sub-facility         Sub-facility of accepted files (regular expresion).
  -t, --site                 Site_code of accepted files (regular expression).
  -c, --checks               Compliance checks to perform on file."
    exit 3
}

# main
# $1 - file to handle
main() {
    local tmp_getops
    tmp_getops=`getopt -o hs:t:c: --long help,sub-facility:,site:,checks: -- "$@"`
    [ $? != 0 ] && usage

    eval set -- "$tmp_getops"
    local subfac="(DA|SOTS)"
    local site="[A-Za-z0-9-]+"
    local checks=""

    # parse the options
    while true ; do
        case "$1" in
            -h|--help) usage;;
            -s|--sub-facility) subfac="$2"; shift 2;;
            -t|--site) site="$2"; shift 2;;
            -c|--checks) checks="$2"; shift 2;;
            --) shift; break;;
            *) usage;;
        esac
    done

    local file=$1; shift

    [ x"$subfac" = x ] && usage
    [ x"$site" = x ] && usage
    declare -rg REGEX="^IMOS_ABOS-${subfac}_${DATACODE}_${TIMESTAMP}_${site}_${FV}(_${PRODUCT})?(_END-${TIMESTAMP})?(_C-${TIMESTAMP})?(_${PART})?\.nc"

    declare -rg CHECKS="$checks"

    if has_extension $file "nc"; then
        handle_netcdf $file
    elif has_extension $file "zip"; then
        handle_zip $file
    else
        file_error "Not a NetCDF file or a zip file"
    fi
}

main "$@"
