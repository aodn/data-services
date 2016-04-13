#!/bin/bash

declare -r BACKUP_RECIPIENT=benedicte.pasquer@utas.edu.au

# returns true (0) if file has a raw extension, which is one of:
# .ek5 .out .raw
# $1 - file
has_soop_ba_raw_extension() {
    local file=$1; shift
    has_extension $file "ek5" || \
        has_extension $file 'out' || \
        has_extension $file 'raw'
}

# is_soop_ba_file
# check that the file belongs to SOOP_BA subfacility
# $1 - file name
is_soop_ba_file() {
    local file=`basename $1`; shift
    echo $file | egrep -q '^IMOS_SOOP-BA_'
}

# returns 0 if directory has netcdf files, 1 otherwise
# $1 - path to directory
directory_has_netcdf_files() {
    local path=$1; shift
    s3_ls $path | grep -q "\.nc$"
}

# delete previous versions of a given file, returns 0 if anything was deleted,
# otherwise returns 1
# $1 - relative file path to delete previous versions of
delete_previous_versions() {
    local file=$1; shift
    local basename_file=`basename $file`

    local path=`dirname $file`
    local file_extension=`get_extension $file`

    local del_function='s3_del_no_index'
    local prev_versions_wildcard=".*\.${file_extension}$"

    if has_extension $file "nc"; then
        del_function='s3_del'
    elif has_extension $file "png"; then
        local file_basename=`basename $file`
        local channel=`echo $file_basename | cut -d '.' -f2`
        prev_versions_wildcard=".*\.${channel}\.${file_extension}$"
    fi

    local prev_version_files=`s3_ls $path | grep "$prev_versions_wildcard" 2> /dev/null | xargs --no-run-if-empty -L1 basename | xargs`

    local prev_file
    for prev_file in $prev_version_files; do
        local basename_prev_file=`basename $prev_file`
        if [ $basename_prev_file != $basename_file ]; then
            log_info "Deleting '$basename_prev_file'"
            $del_function $path/$basename_prev_file || \
                file_error "Could not delete previous file '$basename_prev_file'"
        else
            log_info "Not deleting '$basename_prev_file', same name as new file"
        fi
    done
}

# main
# $1 - file to handle
main() {
    local file=$1; shift
    log_info "Handling SOOP BA zip file '$file'"

    local tmp_dir=`mktemp -d`
    chmod a+rx $tmp_dir
    unzip -q -u -o $file -d $tmp_dir || file_error "Error unzipping"

    local nc_file
    nc_file=`find $tmp_dir -name "*.nc" | head -1` || file_error "Cannot find NetCDF file in zip bundle"

    local tmp_nc_file=`make_writable_copy $nc_file`
    if ! $DATA_SERVICES_DIR/SOOP/SOOP_BA/helper.py addReportingId $tmp_nc_file; then
        rm -f $tmp_nc_file
        file_error "Cannot add reporting_id"
    fi
    echo "" | notify_by_email $BACKUP_RECIPIENT "Processing new SOOP_BA file '$nc_file'"

    check_netcdf  $tmp_nc_file || file_error_and_report_to_uploader $BACKUP_RECIPIENT "Not a valid NetCDF file"
#    check_netcdf_cf   $file || file_error_and_report_to_uploader $BACKUP_RECIPIENT "File is not CF compliant"
#    check_netcdf_imos $file || file_error_and_report_to_uploader $BACKUP_RECIPIENT "File is not IMOS compliant"

    log_info "Processing '$tmp_nc_file'"
    local path
    path=`$DATA_SERVICES_DIR/SOOP/SOOP_BA/helper.py destPath $tmp_nc_file` || \
        file_error "Cannot generate path for NetCDF file"

    local -i is_update=0
    directory_has_netcdf_files IMOS/$path && is_update=1

    [ $is_update -eq 1 ] && delete_previous_versions IMOS/$path/`basename $nc_file`
    s3_put $tmp_nc_file IMOS/$path/`basename $nc_file` && rm -f $nc_file

    local extracted_file
    for extracted_file in `find $tmp_dir -type f`; do
        local basename_extracted_file=`basename $extracted_file`
        log_info "Extracted file '$basename_extracted_file'"

        if has_soop_ba_raw_extension $extracted_file; then
            log_info "Archiving '$extracted_file'"
            local path_to_raw=`echo $path | cut -d '/' -f1,2`
            local path_to_data=`echo $path | cut -d '/' -f3-`
            move_to_archive $extracted_file IMOS/$path_to_raw/raw/$path_to_data/$basename_extracted_file
        else
            [ $is_update -eq 1 ] && delete_previous_versions IMOS/$path/$basename_extracted_file
            s3_put_no_index $extracted_file IMOS/$path/$basename_extracted_file
        fi
    done

    # Dangerous, but necessary, since there might be a hierarchy in the zip file provided
    rm -f $file; rm -rf --preserve-root $tmp_dir
    echo "" | notify_by_email $BACKUP_RECIPIENT "Successfully published SOOP_BA voyage '$path' "
}

main "$@"
