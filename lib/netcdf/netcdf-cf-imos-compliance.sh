#!/bin/bash
# help update metadata/attributes in a NetCDF file so it complies with CF and IMOS conventions

imos_env_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/imos_env
source $imos_env_path
export $(cut -d= -f1 $imos_env_path)

# set lat lon geospatial min and max values according to LATITUDE and LONGITUDE values
# $1 - netcdf file
nc_set_geospatial_gatt() {
    local nc_file=$1; shift

    local geospatial_lon_max
    local geospatial_lon_min
    local geospatial_lat_min
    local geospatial_lat_max

    local valid_lat_max=90
    local valid_lat_min=-90
    local valid_lon_max=180
    local valid_lon_min=-180

    if ! nc_has_variable $nc_file LATITUDE; then
        return
    fi

    geospatial_lat_min=`nc_get_variable_min $nc_file LATITUDE`
    geospatial_lat_max=`nc_get_variable_max $nc_file LATITUDE`

    geospatial_lon_min=`nc_get_variable_min $nc_file LONGITUDE`
    geospatial_lon_max=`nc_get_variable_max $nc_file LONGITUDE`

    # overwrite global attribute. we need to check values as they can be wrong in nc files
    if [ $(echo $geospatial_lat_max'<'$valid_lat_max | bc -l) == 1 ]; then
        nc_set_att -a geospatial_lat_max,global,o,f,$geospatial_lat_max $nc_file
    fi

    if [ $(echo $geospatial_lat_min'>'$valid_lat_min | bc -l) == 1 ]; then
        nc_set_att -a geospatial_lat_min,global,o,f,$geospatial_lat_min $nc_file
    fi

    if [ $(echo $geospatial_lon_max'<'$valid_lon_max | bc -l) == 1 ]; then
        nc_set_att -a geospatial_lon_max,global,o,f,$geospatial_lon_max $nc_file
    fi

    if [ $(echo $geospatial_lon_min'>'$valid_lon_min | bc -l) == 1 ]; then
        nc_set_att -a geospatial_lon_min,global,o,f,$geospatial_lon_min $nc_file
    fi
}
export -f nc_set_geospatial_gatt


# modify the geospatial vertical extent global attribute by looking for the
# DEPTH value, and change the type to be numeric
# $1 - netcdf file
# $2 - depth var optional . default varname to check is DEPTH
nc_set_geospatial_vertical_gatt() {
    local nc_file=$1; shift
    local vertical_var=DEPTH
    if [ -n "$1" ]; then
        vertical_var=$1; shift
    fi

    # check variable DEPTH exists
    if ! nc_has_variable $nc_file $vertical_var; then
        return
    fi

    local geospatial_vertical_min
    local geospatial_vertical_max

    geospatial_vertical_min=`nc_get_variable_min $nc_file $vertical_var`
    geospatial_vertical_max=`nc_get_variable_max $nc_file $vertical_var`

    # overwrite global attributes
    nc_set_att -a geospatial_vertical_min,global,o,f,$geospatial_vertical_min $nc_file && \
        nc_set_att -a geospatial_vertical_max,global,o,f,$geospatial_vertical_max $nc_file

    local vertical_unit="$(nc_get_variable_att $nc_file $vertical_var units)"
    local vertical_positive="$(nc_get_variable_att $nc_file $vertical_var positive))"

    [ -n "$vertical_unit" ] && nc_set_att -a geospatial_vertical_units,global,o,c,"$vertical_unit" $nc_file
    [ -n "$vertical_positive" ] && nc_set_att -a geospatial_vertical_positive,global,o,c,"$vertical_positive" $nc_file
}
export -f nc_set_geospatial_vertical_gatt


# force the valid min max lat lon values
# modify type to be float
# $1 - netcdf file
nc_set_lat_lon_valid_min_max_att() {
    local nc_file=$1; shift

    local valid_lat_max=90
    local valid_lat_min=-90
    local valid_lon_max=180
    local valid_lon_min=-180

    if ! nc_has_variable $nc_file LATITUDE; then
        return
    fi

    local lat_var_type=`nc_get_variable_type $nc_file LATITUDE`
    local lon_var_type=`nc_get_variable_type $nc_file LONGITUDE`

    nc_set_att -a valid_max,LATITUDE,o,$lat_var_type,$valid_lat_max $nc_file
    nc_set_att -a valid_min,LATITUDE,o,$lat_var_type,$valid_lat_min $nc_file

    nc_set_att -a valid_max,LONGITUDE,o,$lon_var_type,$valid_lon_max $nc_file
    nc_set_att -a valid_min,LONGITUDE,o,$lon_var_type,$valid_lon_min $nc_file
}
export -f nc_set_lat_lon_valid_min_max_att


# force the valid min value of time to 0
# $1 - netcdf file
nc_set_time_valid_min_att() {
    local nc_file=$1; shift
    local var_type=`nc_get_variable_type $nc_file TIME`
    nc_set_att -a valid_min,TIME,o,$var_type,0 $nc_file
}
export -f nc_set_time_valid_min_att


# modify common imos global attributes
# $1 - netcdf file
nc_set_common_imos_gatt() {
    local nc_file=$1; shift
    nc_set_att -a Conventions,global,o,c,"$CONVENTIONS" $nc_file # this test is crap, should be free to have any version
    nc_set_att -a data_centre,global,o,c,"$DATA_CENTRE" $nc_file
    nc_set_att -a data_centre_email,global,o,c,"$DATA_CENTRE_EMAIL" $nc_file
    nc_set_att -a project,global,o,c,"$PROJECT" $nc_file # this test is crap, should be free to have any version
    nc_set_att -a acknowledgement,global,o,c,"$ACKNOWLEDGEMENT" $nc_file
    nc_set_att -a distribution_statement,global,o,c,"$DISTRIBUTION_STATEMENT" $nc_file
}
export -f nc_set_common_imos_gatt

# fix time coverage start and end gatt by looking into TIME variable
# $1 nc_file
nc_fix_time_coverage_gatt() {
    local nc_file=$1; shift
    local time_min=`nc_get_time_min $nc_file`
    local time_max=`nc_get_time_max $nc_file`

    nc_set_att -a time_coverage_start,global,o,c,"$time_min" $nc_file
    nc_set_att -a time_coverage_end,global,o,c,"$time_max" $nc_file
}
export -f nc_fix_time_coverage_gatt

# modify BOM qc convention attribut
# $1 - netcdf file
nc_fix_bom_qc_convention_att() {
    local nc_file=$1; shift
    local var
    local varlist
    local quality_control_conventions='BOM (SST and Air-Sea flux) quality control procedure'

    # qc value for BOM
    varlist="$(ncdump -h $nc_file | grep "quality_control_set = 3" | \
      cut -d':' -f1 | sed -e 's/(.*$//' | sed -e 's/\t//g'  | sed -e '/^$/d' | tr '\n' ' ')"
    for var in $varlist; do
         nc_set_att -a quality_control_conventions,$var,o,c,"$quality_control_conventions" $nc_file
    done
}
export -f nc_fix_bom_qc_convention_att

# modify file
# $1 - netcdf file
nc_fix_var_with_wrong_degrees_unit() {
    local nc_file=$1; shift
    local var
    local valist

    # get list of var containing 'degrees (clockwise from true north)' and change the attribute
    varlist="$(ncdump -h $nc_file | grep 'degrees (clockwise from true north)' | cut -d':' -f1 | sed -e 's/\t//g'  | sed -e '/^$/d' | tr '\n' ' ' )"
    for var in $varlist; do
        nc_set_att -a units,$var,o,c,'degree' $nc_file
        nc_set_att -a comment,$var,o,c,'(clockwise from true north)' $nc_file
    done
    unset var
    unset varlist

    # get list of var containing 'degrees (clockwise towards true north)' and change the attribute
    varlist="$(ncdump -h $nc_file | grep 'degrees (clockwise towards true north)' | cut -d':' -f1 | sed -e 's/\t//g'  | sed -e '/^$/d' | tr '\n' ' ' )"
    for var in $varlist; do
        nc_set_att -a units,$var,o,c,'degree' $nc_file
        nc_set_att -a comment,$var,o,c,'(clockwise towards true north)' $nc_file
    done
}
export -f nc_fix_var_with_wrong_degrees_unit

# add correct unit to microeinstein variables
# $1 - netcdf file
nc_fix_var_with_wrong_microeinstein_unit() {
    local nc_file=$1; shift
    local var
    # get list of var containing "microeinstein meter-2" and change the attribute
    local units_old
    local units_new

    units_old="microeinstein meter-2"
    units_new="W m-2"

    varlist="$(ncdump -h $nc_file | grep "$units_old" | cut -d':' -f1 | sed -e 's/\t//g'  | sed -e '/^$/d' | tr '\n' ' ' )"
    for var in $varlist; do
        nc_set_att -a units,$var,o,c,"$units_new" $nc_file
    done
}
export -f nc_fix_var_with_wrong_microeinstein_unit

# add missing flag_values and flag_meanings to ncfile
# $1 - netcdf file
# $2 -  variable name
# $3 - flag values, comma separated string of bytes
# $4 - flag meanings, space separated string
nc_add_missing_qc_var_values_meaning() {
    local nc_file=$1; shift
    local var=$1; shift
    local flag_values=$1; shift
    local flag_meanings="$1"; shift

    if nc_has_variable $nc_file; then
        nc_set_att -a flag_meanings,$var,o,c,"$flag_meanings" $nc_file
        nc_set_att -a flag_values,$var,o,b,"$flag_values" $nc_file
    fi
}
export -f nc_add_missing_qc_var_values_meaning
