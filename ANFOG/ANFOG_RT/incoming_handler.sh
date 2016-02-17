#!/bin/bash

declare -r BACKUP_RECIPIENT=benedicte.pasquer@utas.edu.au

# is_anfog_rt_file
# check that the file belongs to ANFOG facility
# $1 - file name
is_anfog_file() {
    local file=`basename $1`; shift
    echo $file | egrep -q '^IMOS_ANFOG_'
}
# send notification of new mission to backup recipient
# update mission status listing (used in harvester)
# $1 - platform
# $2 - mission_id
notification_new_mission() {
    local platform=$1
    local mission_id=$2
    notify_by_email $BACKUP_RECIPIENT "New ANFOG_RT '$platform' mission '$mission_id'"
    log_info "New '$platform' mission mission '$mission_id'"
    local mission_listing="$DATA_SERVICES_DIR/ANFOG/ANFOG_RT/HarvestmissionList.csv"
    echo "$mission_id,$platform,TRUE,FALSE,FALSE">>$mission_listing
}
# get_file_type
# extract png file type
# $1 - file name
get_file_type() {
    local file=`basename $1`; shift
    echo $file | sed -e 's#\(.*\)_\([[:digit:]]\{8\}T[[:digit:]]\{6\}-[[:digit:]]\{8\}T[[:digit:]]\{6\}\)\.png$#\1 \2#' | cut -d' ' -f1
}
# get_file_timestamp
# extract png timestamp
# $1 - file name
get_file_timestamp() {
    local file=`basename $1`; shift
    local timestamp=`echo $file | sed -e 's#\(.*\)_\([[:digit:]]\{8\}T[[:digit:]]\{6\}-[[:digit:]]\{8\}T[[:digit:]]\{6\}\)\.png$#\1 \2#' | cut -d' ' -f2`

}

# returns 0 if is text file sent when mission completed
# $1 - file name
is_completed_mission_file() {
    local file=`basename $1`; shift
#    is_mission_txt_file=`echo $file | egrep -q '_mission.txt$'`
#    has_message=`grep -q "completed" $file`
    echo $file | egrep -q '_mission.txt$' || \
        file_error "Not valid status file '$file'"
    grep -q "completed" $file || \
        file_error "Status message incorrect"
}

# returns 0 if directory has netcdf files, 1 otherwise
# $1 - path to directory
directory_has_netcdf_files() {
    local path=$1; shift
    ls -1 $path/ 2> /dev/null | grep -q "\.nc$"
}


# delete previous versions of a given file, returns 0 if anything was deleted,
# otherwise returns 1
# $1 - relative file path to delete previous versions of a given file


delete_previous_versions() {
    local file=$1; shift
    local basename_file=`basename $file`

    local path=`dirname $file`
    local file_extension=`get_extension $file`

    local del_function='s3_del_no_index'
    local prev_versions_wildcard="*.${file_extension}"

    if has_extension $file "nc"; then
        del_function='s3_del_no_index'
    else
        del_function='s3_del_no_index'
    fi

    if has_extension $file "nc"; then
        local prev_version_files=`ls -1 $DATA_DIR/$path/${prev_versions_wildcard} 2> /dev/null | xargs --no-run-if-empty -L1 basename | xargs`
        local basename_prev_file=`basename $prev_version_files`
        if [ $basename_prev_file != $basename_file ]; then
            log_info "Deleting '$basename_prev_file'"
            $del_function $path/$basename_prev_file
            if [ $? -ne 0 ]; then
                file_error "Could not delete previous file '$basename_prev_file'"
            fi
         else
              log_info "Not deleting '$basename_prev_file', same name as new file"
        fi

    elif has_extension $file "png"; then

        # here handling dive plots only, summary plot are dealt with in the main program
        local file_type=`get_file_type $basename_file`
        local file_timestamp="[*_2*T*.png]"
        #`get_file_timestamp $basename_file`

        local previous_file=`s3_ls $path | grep $file_type_2*T*-2*T*.png`
        local prev_png_file=`grep "_2*T*-2*T*.png" $previous_file`
        # local previous_file=`ls -1 $DATA_DIR/$path | grep '$file_type_$file_timestamp.png' `
        log_info " XXX previous file : '$previous_file' , prev png '$prev_png_file'"
        if [[ -e $path/$previous_file ]]; then
            $del_function $path/$previous_file
            if [ $? -ne 0 ]; then
                file_error "Could not delete previous file '$previous_file'"
            fi
        else
            log_info "No previous file"
        fi
    elif  has_extension $file "txt"; then
        # handling of unit_track text file
        log_info "Not deleting '$basename_file', same name as new file"
    else
         file_error "Unknown file type"
    fi
}

# main
# $1 - file to handle
# pipeline handling either :
# - single text file sent at the end of a deployment, OR
# - zip containing data
# 1- seaglider and slocunm_glider netCDF file are treated differently:
#    previous slocum_glider netCDF file have to be deleted. All seaglider file have to be kept
# 2- pngs are either updated or to be deleted ( not platform dependent)
# 3- status (current, completed, delayed mode) has to be updated :
#    as new mission starts, status sets to "current" by default
#    status switched to "completed" upon reception of a status text file
#    realtime mission data and folder to be moved to archive (or deleted?) until reception of DM
#    delayed_mode status uptated by the anfog_dm pipeline

main() {
    local file=$1; shift

    # when mission complete single text file uploaded, otherwise zip
    local -i istext=0
    has_extension $file "txt"  && $istext=1
    if [ $istext -eq 1 ] ; then
        local -i completed=0
        is_completed_mission_file $file && completed=1
        mission_id=`echo basename $file | cut -d'_' -f1`
        echo "$mission_id,$platform,FALSE,TRUE,FALSE">>$mission_listing
        log_info "Mission '$mission_id' completed"
    else
        log_info "Handling ANFOG RT zip file '$file'"
        local tmp_dir=`mktemp -d`
        chmod a+rx $tmp_dir
        unzip -q -u -o $file -d $tmp_dir
        if [ $? -ne 0 ]; then
            rmdir $tmp_dir
            file_error "Error unzipping"
        fi
        local nc_file
        nc_file=`find $tmp_dir -name "*.nc" | head -1`
        if [ $? -ne 0 ]; then
            rmdir $tmp_dir
            file_error "Cannot find NetCDF file in zip bundle"
        fi
        local tmp_nc_file=`make_writable_copy $nc_file`
        # check for zero size file
        if [[ ! -s $tmp_nc_file ]]; then
            rm -f $tmp_nc_file
            file_error "Error : File is empty"
        fi
        check_netcdf  $tmp_nc_file || file_error_and_report_to_uploader $BACKUP_RECIPIENT "Not a valid NetCDF file"
#        check_netcdf_cf   $file || file_error_and_report_to_uploader $BACKUP_RECIPIENT "File is not CF compliant"
#        check_netcdf_imos $file || file_error_and_report_to_uploader $BACKUP_RECIPIENT "File is not IMOS compliant"

        log_info "Processing '$tmp_nc_file'"
        local path
        path=`$DATA_SERVICES_DIR/ANFOG/ANFOG_RT/dest_path.py dest_path $tmp_nc_file`
        if [ $? -ne 0 ]; then
            rm -f $tmp_nc_file
            file_error "Cannot generate path for NetCDF file"
        fi

        # when processing slocum_glider data, previous  netcdf files have to be deleted
        # whereas all seaglider nc files have to be kept.
        local platform=`echo $path | cut -d'/' -f3`
        local mission_id=`echo $path | cut -d '/' -f4`
        local -i is_update=0
        directory_has_netcdf_files $DATA_DIR/IMOS/$path && is_update=1

        [ $is_update -eq 0 ] && notification_new_mission $platform $mission_id

        if [ $platform == "slocum_glider" ] && [ $is_update -eq 1 ]; then
            delete_previous_versions IMOS/$path/`basename $nc_file`
        fi

        s3_put_no_index $tmp_nc_file IMOS/$path/`basename $nc_file` && rm -f $nc_file

        # all pngs have to be deleted/replaced irrespective of the platform
        local extracted_file
        for extracted_file in `find $tmp_dir -type f`; do
            local basename_extracted_file=`basename $extracted_file`
            log_info "Extracted file '$basename_extracted_file'"
            if [ $is_update -eq 0 ]; then
            # new mission, move file to target dir
                s3_put_no_index $extracted_file IMOS/$path/$basename_extracted_file
            else
                if [[ -e $DATA_DIR/IMOS/$path/$basename_extracted_file ]]; then
                    log_info "Not deleting '$basename_extracted_file' same as new file"
                    s3_put_no_index $extracted_file IMOS/$path/$basename_extracted_file
                else
                    delete_previous_versions IMOS/$path/$basename_extracted_file
                    s3_put_no_index $extracted_file IMOS/$path/$basename_extracted_file
                fi
            fi
        done

    # Dangerous, but necessary, since there might be a hierarchy in the zip file provided
        rm -f $file; rm -rf --preserve-root $tmp_dir
    fi
}

main "$@"
