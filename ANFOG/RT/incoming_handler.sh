#!/bin/bash
source `dirname $0`/../common.sh

# extract png file type
# $1 - file name
get_file_type() {
    local file=`basename $1`; shift
    echo $file | sed -e 's#\(.*\)_\([[:digit:]]\{8\}T[[:digit:]]\{6\}-[[:digit:]]\{8\}T[[:digit:]]\{6\}\)\.png$#\1#'
}

# handle an anfog_dm zip bundle
# $1 - zip file bundle
handle_zip_file() {
    log_info "Handling ANFOG RT zip file '$file'"
    local tmp_dir=`mktemp -d`
    chmod a+rx $tmp_dir
    local tmp_zip_manifest=`mktemp`

    unzip_file $file $tmp_dir $tmp_zip_manifest
    if [ $? -ne 0 ]; then
        rmdir $tmp_dir
        file_error "Error unzipping"
    fi
    local nb_nc_file
    nb_nc_file=`grep "\.nc$" $tmp_zip_manifest | wc -l`
    if [ $nb_nc_file -gt 1 ]; then
        file_error "More than one file in zip bundle"
    fi

    local nc_file
    nc_file=`grep "\.nc$" $tmp_zip_manifest | head -1`
    if [ $? -ne 0 ]; then
        rm -f $tmp_zip_manifest; rm -rf --preserve-root $tmp_dir
        file_error "Cannot find NetCDF file in zip bundle"
    fi

    if ! regex_filter $nc_file $ANFOG_RT_REGEX; then
        rm -f $tmp_zip_manifest; rm -rf --preserve-root $tmp_dir
        file_error "Did not pass regex filter"
    fi

    local tmp_nc_file=`make_writable_copy $tmp_dir/$nc_file`

    check_netcdf  $tmp_nc_file || file_error_and_report_to_uploader $BACKUP_RECIPIENT "Not a valid NetCDF file"
#    netcdf_checker -t=cf   $file || file_error_and_report_to_uploader $BACKUP_RECIPIENT "File is not CF compliant"
#    netcdf_checker -t=imos:1.3 $file || file_error_and_report_to_uploader $BACKUP_RECIPIENT "File is not IMOS compliant"

    local platform=`get_platform $tmp_nc_file`
    local mission_id=`get_mission_id $tmp_nc_file`

    if [ x"$mission_id" = x ] || [ x"$platform" = x ]; then
        rm -f $tmp_nc_file $tmp_zip_manifest; rm -rf --preserve-root $tmp_dir
        file_error "Cannot extract platform or mission_id"
    fi

    local path=$ANFOG_RT_BASE/$platform/$mission_id

    if directory_has_netcdf_files $path; then
            delete_previous_versions $path/`basename $nc_file`
    else
        mission_new $platform $mission_id
    fi

    s3_put $tmp_nc_file $path/`basename $nc_file` && rm -f $nc_file

    local extracted_file
    for extracted_file in `cat $tmp_zip_manifest`; do
        log_info "Extracted file '$extracted_file'"
        if has_extension $extracted_file "nc"; then
            log_info "Netcdf file already processed" && continue
        else
            delete_previous_versions $path/$extracted_file
            s3_put_no_index $tmp_dir/$extracted_file $path/$extracted_file
        fi
    done

    # dangerous, but necessary, since there might be a hierarchy in the zip file provided
    rm -f $file $tmp_zip_manifest; rm -rf --preserve-root $tmp_dir
}

# handle an anfog_dm zip bundle. the file will be in the form of
# MISSIONID_mission.txt (like Yamba20150601_mission.txt) and will contain the
# text 'completed'
# $1 - txt mission file
handle_txt_file() {
    local file=$1; shift
    local mission_id=`basename $file | cut -d'_' -f1`

    [ "`head -1 $file`" != "completed" ] && \
        file_error "Unexpected content in mission completion txt file"

    local platform=`get_platform_from_mission_id $mission_id`
    [ x"$platform" = x ] && \
        file_error "Cannot find platform for mission id '$mission_id'"

    mission_completed $platform $mission_id
    rm -f $file
}

# main
# $1 - file to handle
# pipeline handling either:
# - single text file sent at the end of a deployment, OR
# - zip containing data
#   1 - previous netCDF file have to be deleted.
#   2 - pngs are either updated or to be deleted (not platform dependent)
#   3 - status (current, completed, delayed mode) has to be updated :
#       as new mission starts, status sets to "current" by default
#       status switched to "completed" upon reception of a status text file
#       realtime mission data and folder to be moved to archive (or deleted?)
#       until reception of DM status uptated by the anfog_dm pipeline
main() {
    local file=$1; shift

    # when mission complete single text file uploaded, otherwise zip
    if has_extension $file "zip"; then
        handle_zip_file $file
    elif has_extension $file "txt"; then
        handle_txt_file $file
    else
        file_error "Unknown file extension"
    fi
}

main "$@"
