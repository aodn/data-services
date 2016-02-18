#!/bin/bash

declare -r BACKUP_RECIPIENT=benedicte.pasquer@utas.edu.au

# is_anfog_rt_file
# check that the file belongs to ANFOG facility
# $1 - file name
is_anfog_file() {
    local file=`basename $1`; shift
    echo $file | egrep -q '*ANFOG*_[[:digit:]]{8}T[[:digit:]]{6}Z*_timeseries_END-[[:digit:]]{8}T[[:digit:]]{6}Z.nc$'
}
# is_archive_file
# check if file is of the following type:
# FV00 (raw data and battery and pitch data(ANFOG_E*.nc), raw data zip
# $1 - file name
is_archive_file() {
    local file=`basename $1`; shift
        echo $file | egrep -q "_FV00_|.zip$"
}

# send notification of new mission to backup recipient
# update mission status listing (used in harvester)
# $1 - platform
# $2 - mission_id
notification_new_mission() {
    local platform=$1
    local mission_id=$2
#    notify_by_email $BACKUP_RECIPIENT "ANFOG_DM '$platform' mission '$mission_id' uploaded" || \
#      _file_error "Could not mail to '$BACKUP_RECIPIENT'"
}
# clean the REALTIME directory after =reception of a mission in Delayed mode
# $1 - platform
# $2 - mission_id
remove_from_rt_directory() {
    local platform=$1
    local mission_id=$2
    local path_to_rt=$DATA_DIR/ANFOG/REALTIME/$platform/$mission
    local files
    if [ -d "$path_to_rt" ]; then
        for files in 'find $path_to_rt/. -type f'; do
            if has_extension $files "nc"; then
                s3_del $path/$files
                if [ $? -ne 0 ]; then
                    file_error "Could not delete previous file '$basename_prev_file'"
                fi
            else
                s3_del_no_index $path/$files
                if [ $? -ne 0 ]; then
                    file_error "Could not delete previous file '$basename_prev_file'"
                fi
            fi
            local mission_listing="$DATA_SERVICES_DIR/ANFOG/ANFOG_RT/HarvestmissionList.csv"
            sed -i "s/$mission_id,$platform,FALSE,TRUE,FALSE/$mission_id,$platform,FALSE,TRUE,FALSE/g" $mission_listing
        done
        # Dan, what is the best way to remove a directory on s3?
#      rmdir $path_to_rt
    else
        log_info "No real-time data found for this mission"
    fi
}
# check if file belongs to the same mission as data file
# $1 file
# $2 mission id
is_mission_file() {
    local file=`basename $1`
    local mission_id=$2
    echo $file | egrep -q "$mission_id"
    log_info "done"
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

    if has_extension $file "nc"; then
        del_function='s3_del_no_index'
    else
        del_function='s3_del_no_index'
    fi

    if [ has_extension $file "nc" ] && [ ! is_archive_file $file ]; then
        local prev_version_files=`s3_ls $DATA_DIR/$path/${prev_versions_wildcard} | head -1`
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

    elif is_archive_file $file; then
        local file_type=`echo $file | cut -d'_' -f1`
        local prev_version_files=`ls -1 $archive_dir/$path/${file_type}*.* 2> /dev/null | xargs --no-run-if-empty -L1 basename | xargs`
        local basename_prev_file=`basename $prev_version_files`
        if [ $basename_prev_file != $basename_file ]; then
            log_info "Deleting '$basename_prev_file'"
        # ?DEL FUNCTION SPECIFIC TO ARCHIVE DIR????
            $del_function $archive_dir/$path//$basename_prev_file
            if [ $? -ne 0 ]; then
                file_error "Could not delete previous file '$basename_prev_file'"
            fi
         else
              log_info "Not deleting '$basename_prev_file', same name as new file"
         fi
        # here handling jpeg, pdf, kml
    elif [[ -e $path/$previous_file ]]; then
        $del_function $path/`basename $previous_file`
            if [ $? -ne 0 ]; then
                file_error "Could not delete previous file '$previous_file'"
            fi
    else
         file_error "Unknown file type"
    fi
}

# main
# $1 - file to handle
# pipeline handling either :
# processe zip file containing data file (.nc) , archive files( either .zip or .nc) , jpeg, pdfs and kml.
# script handles new and reprocessed files ( including archive file even if reprocessing is unlikely)

main() {
    local file=$1; shift

    log_info "Handling ANFOG DM file '$file'"

    local tmp_dir=`mktemp -d`
    chmod a+rx $tmp_dir
    unzip -q -u -o $file -d $tmp_dir
    if [ $? -ne 0 ]; then
        rmdir $tmp_dir
        file_error "Error unzipping"
    fi
    # find FV01 (processed) netcdf file
    local nc_file
    nc_file=`find $tmp_dir -name "*FV01*.nc" | head -1`
    if [ $? -ne 0 ]; then
        rmdir $tmp_dir
        file_error "Cannot find NetCDF file in zip bundle"
    fi
    local tmp_nc_file=`make_writable_copy $nc_file`

    # correct netcdf for CF and IMOS compliance requirements
#    $DATA_SERVICES_DIR/SOOP/SOOP_TMV/soop_tmv_netcdf_compliance.sh $tmp_nc_file

#    local checks='cf imos'
#    local tmp_nc_file_with_sig
#    tmp_nc_file_with_sig=`trigger_checkers_and_add_signature $tmp_nc_file $BACKUP_RECIPIENT $checks`

#    if [ $? -ne 0 ]; then
#        rm -f $tmp_nc_file $tmp_nc_file_with_sig
#        return 1
#    fi
#    rm -f $tmp_nc_file
#    tmp_nc_file=$tmp_nc_file_with_sig

    # generate path
    local path
    path=`$DATA_SERVICES_DIR/ANFOG/ANFOG_DM/dest_path.py dest_path $tmp_nc_file`
    if [ $? -ne 0 ]; then
        rm -f $tmp_nc_file
        file_error "Cannot generate path for NetCDF file"
    fi

    # check for previous versions
    local -i is_update=0

    directory_has_netcdf_files $DATA_DIR/IMOS/$path && is_update=1

    log_info " path: '$path'"
    if  [ $is_update -eq 0 ]; then
        # new mission, move file to target dir
        local platform=`echo $path | cut -d '/' -f2`
        local mission_id=`echo $path | cut -d '/' -f3`
        notification_new_mission $platform $mission_id
        remove_from_rt_directory $platform $mission_id
    else
        delete_previous_versions $tmp_nc_file
    fi
    #s3_put $tmp_nc_file IMOS/$path/`basename $nc_file` && rm -f $nc_file
    s3_put_no_index $tmp_nc_file IMOS/$path/`basename $nc_file` && rm -f $nc_file

    log_info " mv netcdf"
    local extracted_file
    for extracted_file in `find $tmp_dir -type f`; do
        basename_extracted_file=`basename $extracted_file`
        log_info " Extracted '$basename_extracted_file'"
        if [ $is_update -eq 0 ]; then
            # new mission, move file to target dir
            if is_archive_file $basename_extracted_file; then
                 log_info "1"
                # CONFIRM LOCATION OF ANFOG ARCHIVE WITH DAN
                move_to_archive $extracted_file IMOS/$path_to_archive/raw/$path/$basename_extracted_file
            else
                log_info "2"
                # check that bundle contain file from only one mission / inconsistent file name
                is_mission_file $basename_extracted_file $mission_id || \
                    file_error "File '$basename_extracted_file' doesn't belong to the mission '$mission_id'"
                s3_put_no_index $extracted_file IMOS/$path/$basename_extracted_file
            fi
        else
            if is_archive_file $basename_extracted_file; then
 #              notify_by_email $BACKUP_RECIPIENT " Updated archive file '$basename_extracted_file' for mission '$mission_id'"
                log_info "3"
                delete_previous_versions $basename_extracted_file
                move_to_archive $extracted_file IMOS/$path_to_archive/raw/$path/$basename_extracted_file

            else     # other files ie kml, pdf and jpeg
                log_info "4"
                is_mission_file $basename_extracted_file $mission_id || \
                    file_error "File '$basename_extracted_file' doesn't belong to the mission '$mission_id'"
                delete_previous_versions $basename_extracted_file
                s3_put_no_index $extracted_file IMOS/$path/$basename_extracted_file
            fi
        fi
    done

    # Dangerous, but necessary, since there might be a hierarchy in the zip file provided
        rm -f $file; rm -rf --preserve-root $tmp_dir
}

main "$@"
