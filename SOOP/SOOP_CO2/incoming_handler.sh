#!/bin/bash

export PYTHONPATH="$DATA_SERVICES_DIR/SOOP"
export SCRIPTPATH="$DATA_SERVICES_DIR/SOOP/SOOP_CO2"

declare -r BACKUP_RECIPIENT=benedicte.pasquer@utas.edu.au

# is_imos_soop_co2_file
# check that the file from IMOS SOOP_CO2
# $1 - file name
is_imos_soop_co2_file() {
    local file=`basename $1`; shift
    echo $file | egrep -q '^IMOS_SOOP-CO2_'
}

# is_future_reef_map_file
# check that the file belongs toFuture Reef MAP project
# $1 - file name
is_future_reef_map_file() {
    local file=`basename $1`; shift
    echo $file | egrep -q '^FutureReefMap_'
}

# notify_recipients
# notify uploader and backup recipient about status of uploaded file
# $1 - file name
# $2 - message
notify_recipients() {
    local file=$1; shift
    local message="$1"; shift
    local recipient=`get_uploader_email $file`

    if [ -n "$recipient" ]; then
        echo "" | notify_by_email $recipient "$message"
    fi
    echo "" | notify_by_email $BACKUP_RECIPIENT "$message"
}

# handles a single netcdf file, return path in which file is stored
# $1 - netcdf file
handle_netcdf_file() {
    local file=$1; shift

    log_info "Handling SOOP CO2 file '$file'"

    echo "" | notify_by_email $BACKUP_RECIPIENT "Processing new underway CO2 file "`basename $file`

    local tmp_file_with_sig
    local checks

    if is_imos_soop_co2_file $file; then
        checks='cf imos:1.4'
    elif is_future_reef_map_file $file; then
        checks='cf'
    else
        file_error_and_report_to_uploader $BACKUP_RECIPIENT "Not an underway CO2 file "`basename $file`
    fi

    tmp_file_with_sig=`trigger_checkers_and_add_signature $file $BACKUP_RECIPIENT $checks`
    if [ $? -ne 0 ]; then
            file_error "Error in NetCDF checking"
            rm -f  $tmp_nc_file_with_sig
    fi

    local path
    path=`$SCRIPTPATH/dest_path.py $tmp_file_with_sig`

    if [ -n "$path" ]; then
        s3_put $tmp_file_with_sig $path/`basename $file`
        echo $path
        notify_recipients $file "Successfully published SOOP_CO2 voyage '$path'"
    else
        file_error_and_report_to_uploader $BACKUP_RECIPIENT "Cannot generate path for "`basename $file`
    fi
    rm -f $file
}

# handle a soop_co2 zip bundle
# $1 - zip file bundle
handle_zip_file() {
    local file=$1; shift
    log_info "Handling SOOP CO2 zip file '$file'"

    echo "" | notify_by_email $BACKUP_RECIPIENT "Processing new underway CO2 zip file '$file'"

    local tmp_dir=`mktemp -d`
    chmod a+rx $tmp_dir
    local tmp_zip_manifest=`mktemp`

    unzip_file $file $tmp_dir $tmp_zip_manifest
    if [ $? -ne 0 ]; then
        rm -f $tmp_zip_manifest
        rm -rf --preserve-root $tmp_dir
        file_error_and_report_to_uploader  $BACKUP_RECIPIENT "Error unzipping file "`basename $file`
    fi

    local nc_file
    nc_file=`grep ".*\.nc" $tmp_zip_manifest | head -1`
    if [ $? -ne 0 ]; then
        rm -f $tmp_zip_manifest
        rm -rf --preserve-root $tmp_dir
        file_error_and_report_to_uploader $BACKUP_RECIPIENT "Cannot find NetCDF file in zip bundle "`basename $file`
    fi

    log_info "Processing '$nc_file'"

    local path_to_storage=`handle_netcdf_file $tmp_dir/$nc_file`

    if [ -n "$path_to_storage" ];then
        local extracted_file
        for extracted_file in `find $tmp_dir -type f`; do
            local file_basename=`basename $extracted_file`
            s3_put_no_index $extracted_file $path_to_storage/$file_basename
        done
    else
        file_error "Cannot generate path for `basename $nc_file`"
    fi
    rm -f $file # remove zip file
    #Dangerous, but necessary, since there might be a hierarchy in the zip file provided
    rm -rf --preserve-root $tmp_dir
}

# main
# $1 - file to handle
# pipeline handling either:
# processe zip file containing data file (.nc) , txt, doc or xml files
# script handles new and reprocessed files
main() {
    local file=$1; shift

    if has_extension $file "zip"; then
        handle_zip_file $file
    elif has_extension $file "nc"; then
        handle_netcdf_file $file
    else
        file_error_and_report_to_uploader $BACKUP_RECIPIENT "Unknown file extension "`basename $file`
    fi
}

main "$@"
