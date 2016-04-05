#!/bin/bash
# script to correct ANFOG_DM file for IMOS and CF compliance
# used functions from data-services/lib/common/make_netcdf_pass_checker.sh

ACKNOWLEDGEMENT="Any users of IMOS data are required to clearly acknowledge \
the source of the material derived from IMOS in the format: \"Data was sourced from the Integrated Marine Observing System (IMOS) \
- IMOS is a national collaborative research infrastructure, supported by the Australian Government."
DATA_CENTRE="eMarine Information Infrastructure (eMII)"
DISTRIBUTION_ST="Data may be re-used, provided that related metadata explaining the data has been reviewed by the user, and the data is \
appropriately acknowledged. Data, products and services from IMOS are provided \"as is\" without any warranty as to fitness for a particular \
purpose."
CONVENTIONS="IMOS standard set using the IODE flags"
PROJECT="Integrated Marine Observing System (IMOS)"
#####################################
# CF function to fix ANFOG DM files #
#####################################

# make changes to pass CF compliance checks
# $1 - netcdf file
fix_cf_conventions() {

    local nc_file=$1; shift
    nc_has_variable $nc_file "PROFILE" && nc_set_att -a _FillValue,PROFILE,o,l,999999 $nc_file
    nc_set_att -a axis,LONGITUDE,o,c,'X' $nc_file
    nc_has_variable $nc_file "PSAL" && nc_set_att -a units,PSAL,o,c,'1e-3' $nc_file
    nc_has_variable $nc_file "CDOM" && nc_set_att -a units,CDOM,o,c,'1e-9' $nc_file
    nc_has_variable $nc_file "PHASE" && nc_set_att -a units,PHASE,o,c,'1' $nc_file
    nc_has_variable $nc_file "PROFILE" && nc_set_att -a units,PROFILE,o,c,'1' $nc_file
    nc_has_variable $nc_file "NTRA" && nc_set_att -a standard_name,NTRA,o,c,'mole_concentration_of_nitrate_in_sea_water' $nc_file
    nc_has_variable $nc_file "NTRA_quality_control" && nc_set_att -a standard_name,NTRA_quality_control,o,c,'mole_concentration_of_nitrate_in_sea_water status_flag' $nc_file

    nc_fix_cf_add_att_coord_to_variables $nc_file
    nc_remove_att_from_qc_variables $nc_file
}

########################
# CF FUNCTIONS #
########################

# fix variable attribute coordinates
# $1 - netcdf file
nc_fix_cf_add_att_coord_to_variables() {
    local nc_file=$1; shift
    local varlist_3d="$(ncdump -h $nc_file | grep '(TIME)' | cut -d' ' -f2 | \
        sed -e 's/(.*$//' | sed -e 's/^TIME$//g' | sed -e 's/^LATITUDE$//g' | \
        sed -e 's/^LONGITUDE$//g' | sed -e 's/^DEPTH$//g' | sed -e 's/^.*_quality_control$//g' | \
        sed -e 's/^PROFILE$//g' | sed -e 's/^PHASE$//g' | sed -e 's/^[UV]CUR$//g' | \
        sed -e 's/^.*HEAD$//g' | sed -e 's/\t//g'  | sed -e '/^$/d' | tr '\n' ' ' )"

    local var
    for var in $varlist_3d; do
        nc_has_variable $nc_file $var && nc_set_att -a coordinates,$var,o,c,'TIME LATITUDE LONGITUDE DEPTH' $nc_file
    done

    local varlist_2d="[UV]CUR [UV]CUR_GPS VBSC PROFILE PHASE HEAD"

    for var in $varlist_2d; do
        nc_has_variable $nc_file $var && nc_set_att -a coordinates,$var,o,c,'TIME LATITUDE LONGITUDE' $nc_file
    done
}

# fix qc variables that have unknown standard name
# # $1 - netcdf file
nc_remove_att_from_qc_variables() {
    local nc_file=$1; shift
    local qc="quality_control"
    local varlist="IRRAD[[:digit:]]\{3\}_${qc} [UV]CUR_GPS_${qc} VBSC_${qc} PROFILE_${qc} PHASE_${qc} HEAD_${qc} CDOM_${qc}"

    local var
    for var in $varlist; do
        local vars=`nc_list_variables $nc_file | grep "$var"`
        for var in $vars; do
            nc_set_att -a standard_name,$var,d,, $nc_file
        done
    done
}

#######################################
# IMOS function to fix ANFOG DM files #
#######################################

# make changes to pass IMOS compliance checks
# $1 - netcdf file
fix_imos_conventions() {
    local nc_file=$1; shift

    # global attributes
    nc_set_att -a data_centre,global,o,c,"${DATA_CENTRE}" $nc_file
    nc_set_att -a acknowledgement,global,o,c,"${ACKNOWLEDGEMENT}" $nc_file
    nc_set_att -a distribution_statement,global,o,c,"${DISTRIBUTION_ST}" $nc_file
    nc_set_att -a geospatial_lat_units,global,o,c,"degrees_north" $nc_file
    nc_set_att -a geospatial_lon_units,global,o,c,"degrees_east" $nc_file
    nc_set_att -a geospatial_vertical_units,global,o,c,"meter" $nc_file
    nc_set_att -a naming_authority,global,o,c,"IMOS" $nc_file
    nc_set_att -a project,global,o,c,"${PROJECT}" $nc_file

    # variables
    nc_set_att -a units,TIME,o,c,"days since 1950-01-01 00:00:00 UTC" $nc_file
    nc_has_variable $nc_file "PHASE" && nc_set_att -a ancillary_variables,PHASE,o,c,"PHASE_quality_control PROFILE" $nc_file
    nc_has_variable $nc_file "PROFILE" && nc_set_att -a ancillary_variables,PROFILE,o,c,"PROFILE_quality_control PHASE" $nc_file
    nc_has_variable $nc_file "UCUR_GPS" && nc_set_att -a ancillary_variables,UCUR_GPS,o,c,"UCUR_GPS_quality_control" $nc_file

    fix_imos_qc_convention $nc_file
    fix_var_long_name $nc_file
    fix_depth_min_max $nc_file
    fix_lon_lat_min_max $nc_file
    fix_time_min_max $nc_file
}

# fix file for IMOS conventions
# $1 - netcdf file
fix_imos_qc_convention() {
    local nc_file=$1; shift
    local var=".*_quality_control$"
    nc_set_att -a quality_control_conventions,$var,o,c,"${CONVENTIONS}" $nc_file
}

# fix variable long names
# $1 - netcdf file
fix_var_long_name() {
    local nc_file=$1; shift
    local varlist="SENSOR[[:digit:]] DEPLOYMENT PLATFORM"

    local var
    for var in $varlist; do
        local vars=`nc_list_variables $nc_file | grep "$var"`
        for var in $vars; do
            nc_set_att -a long_name,$var,o,c,"${var,,} informations" $nc_file
        done
    done
}

# fix min/max on depth variable
# $1 - netcdf file
fix_depth_min_max() {
    local nc_file=$1; shift
    local tmp_file=`mktemp`

    local depth_min=`ncap2 -O -C -v -s "val=DEPTH.min();print(val)" ${nc_file} $tmp_file | cut -f 3- -d ' ' ;`
    local depth_max=`ncap2 -O -C -v -s "val=DEPTH.max();print(val)" ${nc_file} $tmp_file | cut -f 3- -d ' ' ;`
    rm -f $tmp_file

    nc_set_att -a geospatial_vertical_max,global,o,f,${depth_max} $nc_file
    nc_set_att -a geospatial_vertical_min,global,o,f,${depth_min} $nc_file
}


# fix gatt geospatial latitude and longitude min/max
# $1 - netcdf file
fix_lon_lat_min_max() {
    local nc_file=$1; shift
    local tmp_file=`mktemp`

    local lat_min=`ncap2 -O -C -v -s "val=LATITUDE.min();print(val)" ${nc_file} $tmp_file | cut -f 3- -d ' ' ;`
    local lat_max=`ncap2 -O -C -v -s "val=LATITUDE.max();print(val)" ${nc_file} $tmp_file | cut -f 3- -d ' ' ;`
    local lon_min=`ncap2 -O -C -v -s "val=LONGITUDE.min();print(val)" ${nc_file} $tmp_file | cut -f 3- -d ' ' ;`
    local lon_max=`ncap2 -O -C -v -s "val=LONGITUDE.max();print(val)" ${nc_file} $tmp_file | cut -f 3- -d ' ' ;`
    rm -f $tmp_file

    nc_set_att -a geospatial_lat_max,global,o,f,${lat_max} $nc_file
    nc_set_att -a geospatial_lat_min,global,o,f,${lat_min} $nc_file
    nc_set_att -a geospatial_lon_max,global,o,f,${lon_max} $nc_file
    nc_set_att -a geospatial_lon_min,global,o,f,${lon_min} $nc_file
}

# fix gatt geospatial time_coverage_start/end
# $1 - netcdf file
fix_time_min_max(){
    local nc_file=$1; shift
    local time_min=`nc_get_time_min $nc_file`
    local time_max=`nc_get_time_max $nc_file`

    nc_set_att -a time_coverage_start,global,o,c,${time_min} $nc_file
    nc_set_att -a time_coverage_end,global,o,c,${time_max} $nc_file
}

main() {
    local nc_file=$1; shift

    local tmp_modified_file=`mktemp`
    cp $nc_file $tmp_modified_file

    if ! fix_cf_conventions $tmp_modified_file; then
        echo "Cannot fix CF conventions"
        rm -f $tmp_modified_file
        return 1
    fi

    if ! fix_imos_conventions $tmp_modified_file; then
        echo "Cannot fix IMOS conventions"
        rm -f $tmp_modified_file
        return 1
    fi

    mv -- $tmp_modified_file $nc_file
}

main "$@"
