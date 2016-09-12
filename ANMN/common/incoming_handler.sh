#!/bin/bash

export PYTHONPATH="$DATA_SERVICES_DIR/lib/python"
export SCRIPTPATH="$DATA_SERVICES_DIR/ANMN/common"

declare -r INCOMING_DIR=`dirname $INCOMING_FILE`

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


# create products based on this file, if any, and push them to incoming.
# fail with file_error if processing fails
# $1 - input file to process
# $2 - destination path of input file
create_products() {
    local file=$1; shift
    local dest_path=$1; shift
    local proc_dir=`mktemp -d --tmpdir ${JOB_NAME}_XXXXX`

    local burst_regex="(CTD|Biogeochem)_timeseries\/.*_FV01_.*(WQM|NXIC-CTD).*\.nc"
    local burst_process="$DATA_SERVICES_DIR/ANMN/burst_averaged_product/burst_average.py"
    local burst_product

    # process burst-averaged product?
    if [[ $dest_path =~ $burst_regex ]]; then
        burst_product=`$burst_process $file $proc_dir`

        if [[ $? != 0 || -z "$burst_product" ]] ; then
            # processing failed
            rm -rf --preserve-root $proc_dir
            file_error "Failed to process burst-averaged product from '$file'"
        else
            # move product to incoming dir
            echo "Created burst product '$(basename $burst_product)' from '$(basename $file)'. Moving product to '$INCOMING_DIR'"
            mv -nv $burst_product $INCOMING_DIR || \
                file_error "Could not move $burst_product to $INCOMING_DIR"
            rmdir $proc_dir
        fi
    fi

    return 0
}

# handle a netcdf file for the ANMN facility
# $1 - file to handle
handle_netcdf() {
    local file=$1; shift
    local basename_file=`basename $file`

    local regex="^IMOS_ANMN-${SUBFAC}_${DATACODE}_${TIMESTAMP}_${SITE}_${FV}(_${PRODUCT})?(_END-${TIMESTAMP})?(_C-${TIMESTAMP})?\.nc"
    regex_filter $regex $file || \
        file_error_and_report_to_uploader $BACKUP_RECIPIENT "$basename_file has incorrect name or was uploaded to the wrong place"

    local tmp_file
    tmp_file=`trigger_checkers_and_add_signature $file $BACKUP_RECIPIENT $CHECKS` || return 1

    local dest_path dest_dir
    dest_path=`$SCRIPTPATH/dest_path.py $file` || file_error "Could not determine destination path for file"
    [ x"$dest_path" = x ] && file_error "Could not determine destination path for file"
    dest_dir=`dirname $dest_path`

    # create products based on this file, if any, and push them to incoming
    # returns only if successful or no products to create
    create_products $tmp_file $dest_path

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

    s3_put $tmp_file $dest_path && \
        rm -f $file
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
    local file
    for file in `cat $extracted_files`; do
        handle_file $unzip_dir/$file || break
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

    # for non-netcdf files, allow 6 or 8-digit date or full timestamp
    local date_or_timestamp="([0-9]{6}|[0-9]{8}(T[0-9]{6}Z)?)"
    local regex

    if has_extension $file "nc"; then
        handle_netcdf $file || return 1

    elif has_extension $file "zip"; then
        handle_zip $file || return 1

    elif has_extension $file "pdf"; then
        regex="^IMOS_ANMN-${SUBFAC}_${date_or_timestamp}_${SITE}_FV0[01]_LOGSHT"
        handle_nonnetcdf $file $regex || return 1

    elif has_extension $file "cnv"; then
        regex="^IMOS_ANMN-${SUBFAC}_${DATACODE}_${date_or_timestamp}_${SITE}_FV00_CTDPRO"
        handle_nonnetcdf $file $regex || return 1

    elif has_extension $file "png"; then
        regex="^IMOS_ANMN-${SUBFAC}_${SITE}_FV01.*_C-${TIMESTAMP}\.png"
        handle_nonnetcdf $file $regex || return 1

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
    declare -rg SUBFAC="$subfac"
    declare -rg SITE="$site"
    declare -rg CHECKS="$checks"

    handle_file $file
}

main "$@"
