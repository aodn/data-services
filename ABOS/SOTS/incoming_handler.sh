#!/bin/bash

export PYTHONPATH="$DATA_SERVICES_DIR/lib/python"
export SCRIPTPATH="$DATA_SERVICES_DIR/ABOS/SOTS"

declare -r BACKUP_RECIPIENT=marty.hidas@utas.edu.au
declare -r BASE_HIERARCHY_PREFIX='IMOS/ABOS/SOTS'

# is_abos_sots_file
# check that the file belongs to ABOS-SOTS subfacility
# $1 - file name
is_abos_sots_file() {
    local file=`basename $1`; shift
    echo $file | egrep -q '^IMOS_ABOS-SOTS_.*_(Pulse|SAZ).*\.nc'
}

# main
# $1 - file to handle
main() {
    local file=$1; shift
    local tmp_file=`make_writable_copy $file`  # so we can edit the metadata

    local basename_file=`basename $file`

    is_abos_sots_file $file || file_error_and_report_to_uploader $BACKUP_RECIPIENT "Not an ABOS-SOTS file"
    check_netcdf      $file || file_error_and_report_to_uploader $BACKUP_RECIPIENT "Not a valid NetCDF file"
    check_netcdf_cf   $file || file_error_and_report_to_uploader $BACKUP_RECIPIENT "File is not CF compliant"
    check_netcdf_imos $file || file_error_and_report_to_uploader $BACKUP_RECIPIENT "File is not IMOS compliant"

    add_checker_signature $tmp_file cf imos

    local path_hierarchy
    path_hierarchy=`$SCRIPTPATH/destPath.py $file` || file_error "Could not determine destination path for file"
    [ x"$path_hierarchy" = x ] && file_error "Could not determine destination path for file"

    # add sub-facility directory
    path_hierarchy=$BASE_HIERARCHY_PREFIX/$path_hierarchy

    # archive previous version of file if found on opendap
    local prev_version_files
    prev_version_files=`$SCRIPTPATH/previousVersions.py $file $DATA_DIR/$path_hierarchy` || \
        file_error "Could not find previously published versions of file"

    for prev_file in $prev_version_files; do
        local basename_prev_file=`basename $prev_file`
        if [ $basename_prev_file != $basename_file ]; then
            s3_del $path_hierarchy/`basename $prev_file` || file_error "Could not delete previous files"
        else
            log_info "Not deleting '$basename_prev_file', same name as new file"
        fi
    done

    # publish the tmp_file which has the updated metadata
    s3_put $tmp_file $path_hierarchy/$basename_file && rm -f $file
}

main "$@"
