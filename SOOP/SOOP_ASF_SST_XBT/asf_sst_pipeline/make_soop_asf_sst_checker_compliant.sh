#!/bin/bash
# script to fix SOOP files to make them pass the IMOS and CF checker (hopefully)
# used functions from data-services/lib/common/make_netcdf_pass_checker.sh

#########################################
# CF function to fix SOOP ASF SST files #
#########################################

# $1 netcdf file
nc_fix_soop_asf_sst_file_to_cf_convention() {
    local nc_file=$1; shift

    nc_fix_var_with_wrong_degrees_unit $nc_file
    nc_fix_var_with_wrong_microeinstein_unit $nc_file

    nc_set_att -a calendar,TIME,o,c,'gregorian' $nc_file
    _nc_fix_cf_add_att_coord_to_variables $nc_file
    _nc_fix_cf_remove_string1_dimension $nc_file
    _nc_fix_cf_gps_height_var $nc_file
    nc_set_att -a geospatial_vertical_min,global,o,f,0 $nc_file # for geospatial gatt to numeric and 0 since it's soop data
    nc_set_att -a geospatial_vertical_max,global,o,f,0 $nc_file
    nc_del_empty_att $nc_file
    _nc_fix_cf_fix_std_name_air_temp $nc_file
    nc_fix_time_coverage_gatt $nc_file
}

########################
# PRIVATE CF FUNCTIONS #
########################

# $1 netcdf file
_nc_fix_cf_fix_std_name_air_temp() {
    local nc_file=$1; shift
    local var
    local varlist="$(ncdump -h $nc_file | grep air_temparature | cut -d' ' -f1  | cut -d':' -f1 | sed -e 's/\t//g'  | sed -e '/^$/d' | tr '\n' ' ' )"
    for var in $varlist; do
        nc_set_att -a standard_name,$var,o,c,'air_temperature' $nc_file
    done
}

# $1 netcdf file
_nc_fix_cf_add_att_coord_to_variables() {
    local nc_file=$1; shift
    local var
    # add attribute coordinate to all variables except TIME LAT LON DEPTH *_FLAGS *_QUALITY_CONTROL
    local varlist="$(ncdump -h $nc_file | grep '(TIME)' | cut -d' ' -f2 | sed -e 's/(.*$//' | \
        sed -e 's/^TIME$//g' | sed -e 's/^LATITUDE$//g' | sed -e 's/^LONGITUDE$//g' | sed -e 's/^DEPTH$//g' | sed -e 's/^.*_FLAG$//g' | sed -e 's/^.*_quality_control$//g' | \
        sed -e 's/\t//g'  | sed -e '/^$/d' | tr '\n' ' ' )"
    for var in $varlist; do
        nc_set_att -a coordinates,$var,o,c,'TIME LATITUDE LONGITUDE' $nc_file
    done
}

# BOM files have QC variable dimensions set to (TIME, string1) with string1 as char(1)
# this makes the checker fails for 2 different reasons, we remove the string1 dimension
# $1 netcdf file
_nc_fix_cf_remove_string1_dimension() {
    local nc_file=$1; shift
    # Variable ***_quality_control has a non-space-time dimension after space-time-dimensions - Permute dimensions
    # only run if varlist not empty
    local varlist="$(ncdump -h $nc_file | grep "quality_control(TIME, string1)"  | cut -d' ' -f2 | sed -e 's/(.*$//' | sed -e 's/\t//g'  | sed -e '/^$/d' | tr '\n' ' ' )"
    if [[ ! -z $varlist ]]; then
        ## permute dimensions ( not done anymore)
        #local nc_file_temp=`mktemp`
        ## annoying warning message INFO nco_cpy_var_dfn_trv() is defining dimension TIME as fixed (non-record) in output file even though it is a record dimension in the input file.
        #ncpdq -O  -a string1,TIME $nc_file -o $nc_file_temp > `mktemp` 2>&1
        #mv $nc_file_temp $nc_file

        # remove string1 dimension since char is a single character and it is required that QC var has same dim has non QC
        ncwa -O -a string1 $nc_file $nc_file
        #ncpdq -O $nc_file $nc_file # repack
    fi
}

# adding information to GPS_HEIGHT variable
# $1 nc_file
_nc_fix_cf_gps_height_var() {
    local nc_file=$1; shift
    local var=GPS_HEIGHT

    if nc_has_variable $nc_file $var;then
        #nc_set_att -a axis,$var,o,c,Z $nc_file
        nc_set_att -a positive,$var,o,c,up $nc_file
        nc_set_att -a reference_datum,$var,o,c,"geographical coordinates, WGS84" $nc_file
        #nc_set_att -a standard_name,$var,o,c,height $nc_file
        comment="The GPS_HEIGHT variable reported by the SST recording equipment on the OOCL Panama is simply \
            a 1-minute average of the GPS receiver's antenna height in metres above MSL as reported in the NMEA \
            GPGGA sentence. No geoid correction is made even though this datum (WGS84 ellipsoid model) is provided \
            in another GPGGA variable reported by the GPS receiver on this vessel. \
            The GPS_HEIGHT variable is an experimental field in OOCL Panama, Wana Bhum and Xutra Bhum files.  It \
            was included as we had been asked to supply the nominal depth of the SST sensor and this seemed to be \
            a possible method of supplying the difference in depth of the SST sensor during a voyage referenced to \
            the change in height of the GPS.  The GPS_HEIGHT variable should not be used to obtain the absolute height \
            of the GPS as it is not referenced to a known datum as this requires quite complicated corrections."
        nc_set_att -a comment,$var,o,c,"$comment" $nc_file
        nc_set_att -a valid_min,$var,o,c,-200 $nc_file
        nc_set_att -a valid_max,$var,o,c,200 $nc_file
    fi
}

###########################################
# IMOS function to fix SOOP ASF SST files #
###########################################
nc_fix_soop_asf_sst_file_to_imos_convention() {
    local nc_file=$1; shift

    nc_fix_bom_qc_convention_att $nc_file
    nc_set_common_imos_gatt $nc_file
    nc_set_geospatial_gatt $nc_file
    nc_set_lat_lon_valid_min_max_att $nc_file
    nc_set_time_valid_min_att $nc_file
    nc_set_geospatial_vertical_gatt $nc_file
    _nc_add_flag_var_att $nc_file
    _nc_add_var_fillvalues $nc_file
}

# add flag variable information
# $1 netcdf file
_nc_add_flag_var_att() {
    local nc_file=$1; shift
    local var
    local flag_values
    local flag_meanings
    local ancillary_var

    var=AIRT_FLAG
    flag_values="0,1"
    flag_meanings="unknown currently_available_the_only_sensor"
    ancillary_var=`echo $var | sed  's/_FLAG//g'`
    nc_has_variable $nc_file $var && nc_add_missing_qc_var_values_meaning $nc_file $var $flag_values "$flag_meanings"
    nc_has_variable $nc_file $ancillary_var &&  nc_set_att -a ancillary_variables,$ancillary_var,o,c,$var $nc_file

    var=ATMP_FLAG
    flag_values="0,1"
    flag_meanings="unknown currently_available_the_only_sensor"
    ancillary_var=`echo $var | sed  's/_FLAG//g'`
    nc_has_variable $nc_file $var && nc_add_missing_qc_var_values_meaning $nc_file $var $flag_values "$flag_meanings"
    nc_has_variable $nc_file $ancillary_var &&  nc_set_att -a ancillary_variables,$ancillary_var,o,c,$var $nc_file

    var=LW_FLAG
    flag_values="1,2,3"
    flag_meanings="starboard_sensor port_sensor average_of_both_sensors"
    ancillary_var=`echo $var | sed  's/_FLAG//g'`
    nc_has_variable $nc_file $var && nc_add_missing_qc_var_values_meaning $nc_file $var $flag_values "$flag_meanings"
    nc_has_variable $nc_file $ancillary_var &&  nc_set_att -a ancillary_variables,$ancillary_var,o,c,$var $nc_file

    var=RAIN_AMOUNT_FLAG
    flag_values="0,1"
    flag_meanings="unknown currently_available_the_only_sensor"
    ancillary_var=`echo $var | sed  's/_FLAG//g'`
    nc_has_variable $nc_file $var && nc_add_missing_qc_var_values_meaning $nc_file $var $flag_values "$flag_meanings"
    nc_has_variable $nc_file $ancillary_var &&  nc_set_att -a ancillary_variables,$ancillary_var,o,c,$var $nc_file

    var=RELH_FLAG
    flag_values="0,1"
    flag_meanings="unknown currently_available_the_only_sensor"
    ancillary_var=`echo $var | sed  's/_FLAG//g'`
    nc_has_variable $nc_file $var && nc_add_missing_qc_var_values_meaning $nc_file $var $flag_values "$flag_meanings"
    nc_has_variable $nc_file $ancillary_var &&  nc_set_att -a ancillary_variables,$ancillary_var,o,c,$var $nc_file

    var=SW_FLAG
    flag_values="1,2"
    flag_meanings="starboard_sensor port_sensor"
    ancillary_var=`echo $var | sed  's/_FLAG//g'`
    nc_has_variable $nc_file $var && nc_add_missing_qc_var_values_meaning $nc_file $var $flag_values "$flag_meanings"
    nc_has_variable $nc_file $ancillary_var &&  nc_set_att -a ancillary_variables,$ancillary_var,o,c,$var $nc_file

    var=TEMP_FLAG
    flag_values="0,1"
    flag_meanings="unknown currently_available_the_only_sensor"
    ancillary_var=`echo $var | sed  's/_FLAG//g'`
    nc_has_variable $nc_file $var && nc_add_missing_qc_var_values_meaning $nc_file $var $flag_values "$flag_meanings"
    nc_has_variable $nc_file $ancillary_var &&  nc_set_att -a ancillary_variables,$ancillary_var,o,c,$var $nc_file

    var=WIND_FLAG
    flag_values="0,1"
    flag_meanings="unknown mainmast_sensor"
    ancillary_var=WSPD
    nc_has_variable $nc_file $var && nc_add_missing_qc_var_values_meaning $nc_file $var $flag_values "$flag_meanings"
    nc_has_variable $nc_file $ancillary_var &&  nc_set_att -a ancillary_variables,$ancillary_var,o,c,$var $nc_file
}

# $1 netcdf file
_nc_add_var_fillvalues() {
    local nc_file=$1; shift
    local var
    local fillvalue="-9999"
    local VAR="AIRT ATMP_H LW_H RAIN_AMOUNT_H RELH_H SW_H TEMP_H WIND_H"
    for var in $VAR;do
        if nc_has_variable $nc_file $var; then
            nc_set_att -a _FillValue,$var,o,f,$fillvalue $nc_file
        fi
    done
}

main(){
    local nc_file=$1; shift
    local netcdf_output=$1; shift

    # we modify a temporary copy of the original netcdf
    local tmp_modified_file=`mktemp`
    cp $nc_file $tmp_modified_file

    nc_fix_soop_asf_sst_file_to_imos_convention $tmp_modified_file
    nc_fix_soop_asf_sst_file_to_cf_convention $tmp_modified_file

    cp $tmp_modified_file $netcdf_output
    rm $tmp_modified_file
    return 0
}

main "$@"
