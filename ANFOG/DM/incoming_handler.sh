#!/bin/bash
source `dirname $0`/../common.sh

# check if file is of the following type:
# FV00 (raw data and battery and pitch data(ANFOG_E*.nc), raw data zip
# $1 - file name
needs_archive() {
    local file=`basename $1`; shift
    echo $file | egrep -q "^.*_FV00_.*\.nc$" ||
        echo $file | egrep -q "^.*_rawfiles.zip$"
}

# given platform and mission_id, find and delete associated realtime files
# $1 - platform
# $2 - mission_id
delete_rt_files() {
    local platform=$1; shift
    local mission_id=$1; shift
    local anfog_rt_path=$ANFOG_RT_BASE/$platform/$mission_id
    log_info "Clearing realtime files in '$anfog_rt_path'"

    local file
    for file in `s3_ls $anfog_rt_path`; do
        local del_function='s3_del_no_index'
        if has_extension $file "nc"; then
            del_function='s3_del'
        fi

        $del_function $anfog_rt_path/$file
    done
}

# returns path for netcdf file
# $1 - netcdf file
get_path_for_netcdf() {
    local file=$1; shift

    local platform=`get_platform $file`
    [ x"$platform" = x ] && log_error "Cannot extract platform" && return 1

    local mission_id=`get_mission_id $file`
    [ x"$mission_id" = x ] && log_error "Cannot extract mission_id" && return 1

    echo $ANFOG_DM_BASE/$platform/$mission_id
}

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

# handles a single netcdf file, return path in which file was stored
# $1 - netcdf file
handle_netcdf_file() {
    local file=$1; shift
    local checks='cf imos:1.4'

    log_info "Handling ANFOG DM netcdf file '$file'"

    if ! regex_filter $file $ANFOG_DM_REGEX; then
        file_error "Did not pass regex filter"
    fi

    local tmp_nc_file_with_sig
    tmp_nc_file_with_sig=`trigger_checkers_and_add_signature $file $BACKUP_RECIPIENT $checks`

    if [ $? -ne 0 ]; then
        file_error "Error in NetCDF checking"
        rm -f  $tmp_nc_file_with_sig
    fi

    local path
    path=`get_path_for_netcdf $tmp_nc_file_with_sig` || file_error "Cannot generate path for `basename $tmp_nc_file_with_sig`"

    local platform=`get_platform $file`
    [ x"$platform" = x ] && file_error "Cannot extract platform"

    local mission_id=`get_mission_id $file`
    [ x"$mission_id" = x ] && file_error "Cannot extract mission_id"

    s3_put $tmp_nc_file_with_sig $path/`basename $file` && rm -f $file

    delete_rt_files $platform $mission_id
    mission_delayed_mode $platform $mission_id
    echo $mission_id
}

# handle an anfog_dm zip bundle
# $1 - zip file bundle
handle_zip_file() {
    local file=$1; shift
    log_info "Handling ANFOG DM zip file '$file'"

    local tmp_dir=`mktemp -d`
    chmod a+rx $tmp_dir
    local tmp_zip_manifest=`mktemp`

    unzip_file $file $tmp_dir $tmp_zip_manifest
    if [ $? -ne 0 ]; then
        rm -rf --preserve-root $tmp_dir
        file_error "Error unzipping"
    fi

    local nc_file
    nc_file=`grep ".*_FV01_.*\.nc" $tmp_zip_manifest | head -1`
    if [ $? -ne 0 ]; then
        rm -rf --preserve-root $tmp_dir
        file_error "Cannot find NetCDF file in zip bundle"
    fi

    local path
    path=`get_path_for_netcdf $tmp_dir/$nc_file` || file_error "Cannot generate path for `basename $nc_file`"

    local mission_id
    mission_id=`handle_netcdf_file $tmp_dir/$nc_file` || file_error "Cannot process `basename $nc_file`. Aborting"

    local extracted_file
    for extracted_file in `cat $tmp_zip_manifest`; do
        log_info "Extracted file '$extracted_file'"
        if [ "$extracted_file" = "$nc_file" ]; then
            true # skip already processed netcdf file
        elif needs_archive $extracted_file; then
            move_to_archive $tmp_dir/$extracted_file $path
        else
            delete_previous_versions $path/`basename $extracted_file`
            s3_put_no_index $tmp_dir/$extracted_file $path/`basename $extracted_file`
        fi
    done
    echo $mission_id
    rm -f $tmp_zip_manifest; rm -rf --preserve-root $tmp_dir
}

# main
# $1 - file to handle
# pipeline handling either:
# processe zip file containing data file (.nc) , archive files( either .zip or .nc) , jpeg, pdfs and kml.
# script handles new and reprocessed files ( including archive file even if reprocessing is unlikely)
main() {
    local file=$1; shift
    local mission_id
    if has_extension $file "zip"; then
        notify_recipients $file "Handling ANFOG DM zip file `basename $file`"
        mission_id=`handle_zip_file $file`
    elif has_extension $file "nc"; then
        notify_recipients $file "Handling ANFOG DM netCDF file `basename $file`"
        mission_id=`handle_netcdf_file $file`
    else
        file_error_and_report_to_uploader "Unknown file extension"
    fi

    notify_recipients $file "Successfully published ANFOG Delayed Mode deployment '$mission_id'"
    rm -f $file
}

main "$@"
