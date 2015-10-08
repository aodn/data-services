#!/bin/bash

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

    echo "ACORN/$type/$station_name/$year/$month/$day/"`basename $file`
}

# main
# $1 - file to handle
main() {
    local file=$1; shift

    local file_type=`get_type $file`
    [ x"$file_type" = x ] && echo "Unknown file type" 1>&2 && return 1

    get_hierarchy $file $file_type
}

main "$@"
