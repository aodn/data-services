#!/bin/bash

# returns non zero if file does not match regex filter
# $1 - file to validate
regex_filter() {
    local file=`basename $1`; shift
    # regex to validate ACORN file basename
    echo $file | grep -q '^IMOS_ACORN_[[:alpha:]]\{1,2\}_[[:digit:]]\{8\}T[[:digit:]]\{6\}Z_[[:alpha:]]\{3,4\}_FV0[01]_\(radial\|sea-state\).nc$'
}

# return acorn file type
# $1 - file
get_type() {
    local file=$1; shift
    if basename $file | grep -q "FV00_radial.nc"; then
        echo "radial"
    elif basename $file | grep -q "FV00_sea-state.nc"; then
        echo "vector"
    elif basename $file | grep -q "FV01_radial.nc"; then
        echo "radial_quality_controlled"
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

    echo "$type/$station_name/$year/$month/$day"
}

# main
# $1 - file to handle
main() {
    local file=$1; shift

    check_netcdf          $file       || file_error $file "Not a valid NetCDF file"
    # TODO netcdf checking not quite implemented yet for ACORN
    #check_netcdf_cf       $file       || file_error $file "NetCDF file is not CF compliant"
    #check_netcdf_imos     $file       || file_error $file "NetCDF file is not IMOS compliant"
    #check_netcdf_facility $file acorn || file_error $file "NetCDF file is not ACORN compliant"

    regex_filter $file || file_error $file "Did not pass regex filter"

    local file_type=`get_type $file`
    [ x"$file_type" = x ] && file_error $file "Unknown file type"

    local hierarchy_path=`get_hierarchy $file $file_type`
    [ x"$hierarchy_path" = x ] && file_error $file "Could not generate hierarchy"

    move_to_production_force $file $OPENDAP_DIR/1 IMOS/opendap/ACORN/$hierarchy_path/`basename $file`
}

main "$@"
