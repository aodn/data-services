#!/bin/bash

declare -r BACKUP_RECIPIENT=benedicte.pasquer@utas.edu.au
declare -r ANFOG_RT_WIP_DIR=$WIP_DIR/ANFOG/RT; mkdir -p $ANFOG_RT_WIP_DIR
declare -r MISSION_LISTING="$ANFOG_RT_WIP_DIR/HarvestmissionList.csv"

declare -r ANFOG_BASE=IMOS/ANFOG
declare -r ANFOG_RT_BASE=$ANFOG_BASE/REALTIME
declare -r ANFOG_DM_BASE=$ANFOG_BASE

declare -r PLATFORM_CODES="SG:seaglider SL:slocum_glider"

declare -r ANFOG_RT_REGEX='^IMOS_ANFOG_'
declare -r ANFOG_DM_REGEX='IMOS_ANFOG.*_[[:digit:]]{8}T[[:digit:]]{6}Z_.*_timeseries_END-[[:digit:]]{8}T[[:digit:]]{6}Z.nc$'

# validate regex, returns true (0) if passes, false (1) if not
# $1 - file
# $2 - regex
regex_filter() {
    local file=`basename $1`; shift
    local regex="$1"; shift
    echo $file | grep -E "$regex" -q
}

# given a code, return platform name
# $1 - code
get_platform_from_code() {
    local code=$1; shift
    echo $PLATFORM_CODES | grep -o "\b$code:\w\+\b" | cut -d: -f2
}

# given an anfog netcdf file, returns platform
# $1 - netcdf file
get_platform() {
    local nc_file=$1; shift
    local code=`echo $nc_file | cut -d_ -f5 | cut -c1-2`
    get_platform_from_code $code
}

# given an anfog netcdf file, returns mission id, by looking at its title, for
# example:
# 'Slocum G2 glider data from the mission Yamba20150601' -> 'Yamba20150601'
# 'Slocum glider data from Yamba20151110' -> 'Yamba20151110'
# $1 - netcdf file
get_mission_id() {
    local nc_file=$1; shift
    # grep last word
    nc_get_gatt_value $nc_file title | grep -o "[^ ]\+$"
}

# new anfog mission
# $1 - platform
# $2 - mission_id
mission_new() {
    local platform=$1; shift
    local mission_id=$1; shift
    set_mission_status $platform $mission_id in_progress
}

# mission completed (not running any more)
# $1 - platform
# $2 - mission_id
mission_completed() {
    local platform=$1; shift
    local mission_id=$1; shift
    set_mission_status $platform $mission_id completed
}

# mission finalized (received delayed mode files)
# $1 - platform
# $2 - mission_id
mission_delayed_mode() {
    local platform=$1; shift
    local mission_id=$1; shift
    set_mission_status $platform $mission_id delayed_mode
}

# mission status can be one of 'in_progress', 'completed' or 'delayed_mode'
# set mission status with given status string
# $1 - platform
# $2 - mission_id
# $3 - mission status (string like 'TRUE,FALSE,TRUE')
set_mission_status() {
    local platform=$1; shift
    local mission_id=$1; shift
    local mission_status=$1; shift

    echo "" | notify_by_email $BACKUP_RECIPIENT "$mission_status ANFOG '$platform/$mission_id'"
    log_info "'$platform/$mission_id' new status '$mission_status'"

    touch $MISSION_LISTING
    sed -i -e "/^$mission_id,$platform,.*/d" $MISSION_LISTING
    echo "$mission_id,$platform,$mission_status" >> $MISSION_LISTING
}

# use mission listing to extract platform for given mission id
# $1 - mission id
get_platform_from_mission_id() {
    local mission_id=$1; shift
    grep "^$mission_id," $MISSION_LISTING | cut -d, -f2 | head -1
}

# returns 0 if directory has netcdf files, 1 otherwise
# $1 - path to directory
directory_has_netcdf_files() {
    local path=$1; shift
    s3_ls $path | grep -q "\.nc$"
}

# delete previous versions of a given file
# $1 - relative file path to delete previous versions of a given file
delete_previous_versions() {
    local file=$1; shift
    local basename_file=`basename $file`

    local path=`dirname $file`
    local file_extension=`get_extension $file`

    local del_function='s3_del_no_index'
    local prev_versions_wildcard=".*\.${file_extension}"

    if has_extension $file "nc"; then
        del_function='s3_del'
    elif has_extension $file "png"; then
        local file_type=`get_file_type $basename_file`
        prev_versions_wildcard="${file_type}_[[:digit:]]\{8\}T[[:digit:]]\{6\}-[[:digit:]]\{8\}T[[:digit:]]\{6\}\.${file_extension}"
    elif has_extension $file "jpg" || has_extension $file "pdf" || has_extension $file "kml"; then
        return
    else
        log_info "Cannot delete previous files for file '$basename_file'"
        return
    fi

    local prev_version_files=`s3_ls $path | grep "$prev_versions_wildcard" 2> /dev/null | xargs --no-run-if-empty -L1 basename | xargs`

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
