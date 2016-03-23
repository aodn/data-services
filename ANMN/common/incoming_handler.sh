#!/bin/bash

export PYTHONPATH="$DATA_SERVICES_DIR/lib/python"
export SCRIPTPATH="$DATA_SERVICES_DIR/ANMN/common"

declare -r BACKUP_RECIPIENT=marty.hidas@utas.edu.au
declare -r DATACODE="[A-Z]+"
declare -r TIMESTAMP="[0-9]{8}T[0-9]{6}Z"
declare -r FV="FV0[012]"
declare -r PRODUCT="[^_]+"

declare -r HANDLED_EXTENSIONS="nc|zip|cnv|pdf|png"

# returns non zero if file does not match regex filter
# $1 - regex to match with
# $2 - file to validate
regex_filter() {
    local regex="$1"; shift
    local file=`basename $1`; shift
    echo $file | grep -E "$regex" -q
}


# handle a netcdf file for the ANMN facility
# $1 - file to handle
handle_netcdf() {
    local file=$1; shift
    local basename_file=`basename $file`

    local regex="^IMOS_ANMN-${SUBFAC}_${DATACODE}_${TIMESTAMP}_${SITE}_${FV}(_${PRODUCT})?(_END-${TIMESTAMP})?(_C-${TIMESTAMP})?\.nc"
    regex_filter $regex $file || \
        file_error_and_report_to_uploader $BACKUP_RECIPIENT "$basename_file has incorrect name or was uploaded to the wrong place"

    local dest_path dest_dir
    dest_path=`$SCRIPTPATH/dest_path.py $file` || file_error "Could not determine destination path for file"
    [ x"$dest_path" = x ] && file_error "Could not determine destination path for file"
    dest_dir=`dirname $dest_path`

    # archive previous version of file if found on opendap
    local prev_version_files
    prev_version_files=`$SCRIPTPATH/previous_versions.py $file $DATA_DIR/$dest_dir` \
        || file_error "Could not find previously published versions of file"

    local prev_file
    for prev_file in $prev_version_files; do
        local basename_prev_file=`basename $prev_file`
        if [ $basename_prev_file != $basename_file ]; then
            s3_del $dest_dir/`basename $prev_file` || file_error "Could not delete previous files"
        else
            log_info "Not deleting '$basename_prev_file', same name as new file"
        fi
    done

    s3_put $file $dest_path
}


# handle a non-netcdf file for the ANMN facility
# $1 - file to handle
# $2 - regex to match against filename
handle_nonnetcdf() {
    local file=$1; shift
    local basename_file=`basename $file`
    local regex=$1; shift

    regex_filter $regex $file || \
        file_error_and_report_to_uploader $BACKUP_RECIPIENT "$basename_file has incorrect name or was uploaded to the wrong place"

    local dest_path
    dest_path=`$SCRIPTPATH/dest_path.py $file` || file_error "Could not determine destination path for file"
    [ x"$dest_path" = x ] && file_error "Could not determine destination path for file"

    s3_put_no_index $file $dest_path
}


# handle a zip file containing NetCDF files for the ANMN facility
# $1 - zip file to handle
handle_zip() {
    local zipfile=$1; shift

    local unzip_dir=`mktemp -d --tmpdir ${JOB_NAME}_XXXXX`
    chmod 755 $unzip_dir  # make directory world readable

    # unzip the file
    log_info "Unzipping '$zipfile' to $unzip_dir"
    local extracted_files=`mktemp --tmpdir=$unzip_dir`
    unzip_file $zipfile $unzip_dir $extracted_files || file_error "Failed to unzip"

    # abort operation if there are any files in archive that we don't
    # know how to handle (don't know how to handle them)
    grep -Eqv "\.(${HANDLED_EXTENSIONS})\$" $extracted_files && \
        file_error "Zip file contains unknown file types (only accept .${HANDLED_EXTENSIONS//|/, .})"

    # process extracted files
    local n_extracted=`cat $extracted_files | wc -l`
    log_info "Processing $n_extracted extracted files..."
    for file in `cat $extracted_files`; do
        handle_file $unzip_dir/$file
    done

    # clean up
    rm -f $zipfile $extracted_files
    rm -rf --preserve-root $unzip_dir
}

# call the appropriate handler depending on file extension
# $1 - file to handle
handle_file() {
    local file=$1; shift
    local basename_file=`basename $file`

    local date_or_timestamp="([0-9]{6}|$TIMESTAMP)"  # for non-netcdf files, allow just YYMMDD date
    local regex

    if has_extension $file "nc"; then
        handle_netcdf $file

    elif has_extension $file "zip"; then
        handle_zip $file

    elif has_extension $file "pdf"; then
        regex="^IMOS_ANMN-${SUBFAC}_${date_or_timestamp}_${SITE}_FV0[01]_LOGSHT"
        handle_nonnetcdf $file $regex

    elif has_extension $file "cnv"; then
        regex="^IMOS_ANMN-${SUBFAC}_${DATACODE}_${date_or_timestamp}_${SITE}_FV00_CTDPRO"
        handle_nonnetcdf $file $regex

    elif has_extension $file "png"; then
        regex="^IMOS_ANMN-${SUBFAC}_${SITE}_FV01.*_C-${TIMESTAMP}\.png"
        handle_nonnetcdf $file $regex

    else
        file_error_and_report_to_uploader $BACKUP_RECIPIENT "File type not accepted ($basename_file)"
    fi
}


# prints usage and exit
usage() {
    echo "Usage: $0 [OPTIONS]... FILE"
    echo "Performs generic checks against an ANMN file, then pushes it to production."
    echo "
Options:
  -s, --sub-facility         Sub-facility of accepted files (regular expresion).
  -t, --site                 Site_code of accepted files (regular expression).
  -c, --checks               Compliance checks to perform on file."
    exit 3
}

# main
# $1 - file to handle
# $@ - options
main() {
    local tmp_getops
    tmp_getops=`getopt -o hs:t:c: --long help,sub-facility:,site:,checks: -- "$@"`
    [ $? != 0 ] && usage

    eval set -- "$tmp_getops"
    local subfac="(NRS|NSW|SA|WA|QLD)"
    local site="[A-Za-z0-9-]+"
    local checks

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
    declare -rg SUBFAC="$subfac"
    declare -rg SITE="$site"

    handle_file $file
}

main "$@"
