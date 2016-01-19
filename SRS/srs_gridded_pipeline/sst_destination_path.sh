#!/bin/bash
# unit tests on shunit2_test_sst_destination_path.sh
# returns the relative imos hierarchy of an abom srs ghrsst file
# author: laurent.besnard@utas.edu.au

# return date product temporal_extent day_period   in this order, comma separated
# if the function 'fails', there s no output, which is not necessarely a problem as it
# points out that the filename is not a regular one
# $1 - netcdf filename
product_information() {
    local srs_file=$1; shift
    local product_info
    product_info=`echo $srs_file | sed 's/^\([0-9]\{14\}\)-ABOM-\(L3S\|L3C\|L3U\|L3P\)_.*_D-\(1d\|3d\|6d\|14d\|1m\)_\(day\|night\|dn\).*\.nc$/\1,\2,\3,\4/g' | \
        sed '/^\s*$/d'`
    [[ "$product_info" == "$srs_file" ]] || echo $product_info
}

# returns the data date in the format 'yyyy,mm,dd' from the netcdf filename
# $1 - netcdf filename
_get_date_netcdf() {
    local srs_file=$1; shift
    echo $srs_file | sed  's/^\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\).*\.nc$/\1,\2,\3/g'
}

# returns the year of the netcdf file date
# $1 - netcdf filename
get_year_netcdf() {
    local srs_file=$1; shift
    _get_date_netcdf $srs_file | cut -d',' -f1
}

# returns the month of the netcdf file date
# $1 - netcdf filename
get_month_netcdf() {
    local srs_file=$1; shift
    _get_date_netcdf $srs_file | cut -d',' -f2
}

# get he satellite number from the filename. only for avhrr sats
# $1 - netcdf filename
satellite_number_avhrr() {
    local srs_file=$1; shift
    echo $srs_file | grep -oE "*-AVHRR([0-9]{1,2})_" | sed 's/[^0-9]*//g'
}

# remove replace nc4 extension with nc
# $1 - netcdf filename
_check_and_replace_netcdf_extension() {
    local srs_file=$1; shift
    echo $srs_file | sed "s/\.nc4$/.nc/g"
}

# remove the file version. explanation:
# *v02.0-fv02.0.nc data until the end on 2013
# *v02.0-fv01.0.nc most recent data
# $1 - netcdf filename
_remove_netcdf_file_version() {
    local srs_file=$1; shift
    echo $srs_file | sed "s/\-v0.*\.nc$/.nc/g"
}

# remove the nc4 extension if exsist, and remove if exist the ugly file version from the file
# $1 - netcdf filename
clean_netcdf_filename() {
    local srs_file=$1; shift
    srs_file=`_check_and_replace_netcdf_extension $srs_file`
    _remove_netcdf_file_version $srs_file
}

# files must start with 14 digits, and finish with .nc$ , not nc4, no file version
# $1 - netcdf filename
srs_file_path() {
    local srs_file=$1; shift
    local srs_filename=`basename $srs_file`
    srs_filename=`clean_netcdf_filename $srs_filename`

    local year=`get_year_netcdf $srs_filename`
    local month=`get_month_netcdf $srs_filename`
    local product_information_output=`product_information $srs_filename`
    local product_name=`echo $product_information_output | cut -d',' -f2`
    local temporal_extent=`echo $product_information_output | cut -d',' -f3`
    local day_period=`echo $product_information_output | cut -d',' -f4`
    local day_period_short=`echo $day_period | sed 's/night/ngt/g'`
    local sst_prefix_path=sst/ghrsst
    local sat_number=`satellite_number_avhrr $srs_filename`

    local l3s_format
    local l3u_format
    local l3c_format

    l3s_format="ABOM-L3S_GHRSST-SST(skin|fnd)-AVHRR_D"
    # valid for all L3S except 1m which is foundation SST
    echo $srs_filename | grep -q -E "^[0-9]{14}-${l3s_format}-${temporal_extent}_${day_period}.nc$" && \
        echo ${sst_prefix_path}/${product_name}-${temporal_extent}/${day_period_short}/$year/$srs_filename && return
    # L3S southern product
    echo $srs_filename | grep -q -E "^[0-9]{14}-${l3s_format}-${temporal_extent}_${day_period}_Southern.nc$" && \
        echo ${sst_prefix_path}/${product_name}-${temporal_extent}S/${day_period_short}/$year/$srs_filename && return

    l3u_format="ABOM-L3U_GHRSST-SSTskin-AVHRR${sat_number}_D-(Des|Asc)_Southern" # L3U format
    echo $srs_filename | grep -q -E "^[0-9]{14}-${l3u_format}.nc$" && \
        echo ${sst_prefix_path}/L3U-S/n${sat_number}/$year/$srs_filename && return

    l3u_format="ABOM-L3U_GHRSST-SSTskin-AVHRR${sat_number}_D-(Des|Asc)" # L3U format
    echo $srs_filename | grep -q -E "^[0-9]{14}-${l3u_format}.nc$" && \
        echo ${sst_prefix_path}/L3U/n${sat_number}/$year/$srs_filename && return

    l3u_format="ABOM-L3U_GHRSST-SSTskin-MTSAT_1R-CRTM"
    echo $srs_filename | grep -q -E "^[0-9]{14}-${l3u_format}.nc$" && \
        echo ${sst_prefix_path}/L3U/mtsat1r/$year/$month/$srs_filename && return

    l3c_format="ABOM-L3C_GHRSST-SSTskin-AVHRR${sat_number}_D"
    echo $srs_filename | grep -q -E "^[0-9]{14}-${l3c_format}-${temporal_extent}_${day_period}.nc$" && \
        echo ${sst_prefix_path}/${product_name}-${temporal_extent}/${day_period_short}/n${sat_number}/${year}/$srs_filename && return
    # L3C southern product
    echo $srs_filename | grep -q -E "^[0-9]{14}-${l3c_format}-${temporal_extent}_${day_period}_Southern.nc$" && \
        echo ${sst_prefix_path}/${product_name}-${temporal_extent}S/${day_period_short}/n${sat_number}/${year}/$srs_filename && return

    file_error $srs_file "Error - no destination path was created"
}


# $1 - netcdf filename or filepath
main() {
    local file=$1; shift
    [ -z "$file" ] || srs_file_path $file
}

# don't run main if running shunit
if [[ `basename $0` =~ ^shunit2_.* ]]; then
    true
else
    main "$@"
fi
