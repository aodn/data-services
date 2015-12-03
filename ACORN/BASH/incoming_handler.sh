#!/bin/bash

ACORN_REGEX='^IMOS_ACORN_[[:alpha:]]{1,2}_[[:digit:]]{8}T[[:digit:]]{6}Z_[[:alpha:]]{3,4}_FV0[01]_(radial|sea-state|wavespec|windp|wavep|1-hour-avg)\.nc$'
CURRENT_GENERATOR=$DATA_SERVICES_DIR/ACORN/CurrentGenerator/CurrentGenerator.py
ACORN_HOURLY_AVG_DIR=$INCOMING_DIR/ACORN/hourly-avg

# validate regex, returns true (0) if passes, false (1) if not
# $1 - file
regex_filter() {
    local file=`basename $1`; shift
    echo $file | grep -E $ACORN_REGEX -q
}

# return true (0) if file needs indexing, false (1) otherwise
# $1 - file type
need_index() {
    local file_type=$1; shift
    if [ "$file_type" == "radial" ] || \
        [ "$file_type" == "radial_quality_controlled" ] || \
        [ "$file_type" == "gridded_1h-avg-current-map_non-QC" ] || \
        [ "$file_type" == "gridded_1h-avg-current-map_QC" ]; then
        return 0
    else
        return 1
    fi
}

# return acorn file type
# $1 - file
get_type() {
    local file=$1; shift
    if basename $file | grep -q "FV00_radial.nc$"; then
        echo "radial"
    elif basename $file | grep -q "FV00_sea-state.nc$"; then
        echo "vector"
    elif basename $file | grep -q "FV01_radial.nc$"; then
        echo "radial_quality_controlled"
    elif basename $file | grep -q "FV01_wavespec.nc$"; then
        echo "gridded_1h-avg-wave-spectra_QC"
    elif basename $file | grep -q "FV01_windp.nc$"; then
        echo "gridded_1h-avg-wind-map_QC"
    elif basename $file | grep -q "FV01_wavep.nc$"; then
        if basename $file | grep -qE "_CBG_|_SAG_|_ROT_|_COF_"; then
            echo "gridded_1h-avg-wave-site-map_QC"
        else
            echo "gridded_1h-avg-wave-station-map_QC"
        fi
    elif basename $file | grep -q "FV00_1-hour-avg.nc$"; then
        echo "gridded_1h-avg-current-map_non-QC"
    elif basename $file | grep -q "FV01_1-hour-avg.nc$"; then
        echo "gridded_1h-avg-current-map_QC"
    else
        return 1
    fi
}

# given a file, return its hierarchy
# $1 - file
# $2 - file type (radial/vector)
get_hierarchy() {
    local file=$1; shift
    local type=$1; shift

    local file_basename=`basename $file`

    local station_name=`echo $file_basename | cut -d_ -f5`

    local year=`echo $file_basename | cut -d_ -f4 | cut -c1-4`
    local month=`echo $file_basename | cut -d_ -f4 | cut -c5-6`
    local day=`echo $file_basename | cut -d_ -f4 | cut -c7-8`

    echo "IMOS/ACORN/$type/$station_name/$year/$month/$day/"`basename $file`
}

# abort operation if file is not newer than existing file
# $1 - file
# $2 - intended path hierarchy of file
compare_to_existing_file() {
    local file=$1; shift
    local path_hierarchy=$1; shift

    local tmp_existing=`mktemp -u`
    if s3_get $path_hierarchy $tmp_existing; then
        local existing_file_date_created=`nc_get_gatt_value $tmp_existing date_created`
        local new_file_date_created=`nc_get_gatt_value $file date_created`

        if ! timestamp_is_increasing $existing_file_date_created $new_file_date_created; then
            log_info "Existing file timestamp: '$existing_file_date_created'"
            log_info "New file timestamp: '$new_file_date_created'"
            rm -f $tmp_existing
            # TODO in future, just discard the file
            file_error "Incoming file is not newer than existing file"
        fi
    fi

    rm -f $tmp_existing
}

# main
# $1 - file to handle
main() {
    local file=$1; shift

    regex_filter $file || file_error "Did not pass ACORN regex filter"
    check_netcdf $file || file_error "Not a valid NetCDF file"

    local file_type=`get_type $file`
    [ x"$file_type" = x ] && echo "Unknown file type" 1>&2 && return 1

    local path_hierarchy
    path_hierarchy=`get_hierarchy $file $file_type`

    compare_to_existing_file $file $path_hierarchy

    # index radial and hourly average files
    if need_index $file_type; then
        s3_put $file $path_hierarchy
    else
        s3_put_no_index $file $path_hierarchy
    fi

    # trigger hourly average for radial/vector files
    if [ "$file_type" == "radial" ] || \
        [ "$file_type" == "radial_quality_controlled" ] || \
        [ "$file_type" == "vector" ]; then
        touch $ACORN_HOURLY_AVG_DIR/`basename $file`
    fi
}

# don't run main if running shunit
if [[ `basename $0` =~ ^shunit2_.* ]]; then
    true
else
    main "$@"
fi
