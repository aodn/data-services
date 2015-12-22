#!/bin/bash
# script to fix SOOP XBT files to make them pass the IMOS and CF checker (hopefully)
# used functions from data-services/lib/common/make_netcdf_pass_checker.sh

#####################################
# CF function to fix SOOP XBT files #
#####################################

# $1 netcdf file
fix_cf_conventions() {
    local nc_file=$1; shift

    nc_set_att -a cf_role,INSTANCE,o,c,'profile_id' $nc_file
    nc_set_att -a positive,DEPTH,o,c,'down' $nc_file
    _nc_fix_cf_add_att_coord_to_variables $nc_file
    nc_del_empty_att $nc_file
}

########################
# PRIVATE CF FUNCTIONS #
########################

# $1 netcdf file
_nc_fix_cf_add_att_coord_to_variables() {
    local nc_file=$1; shift
    local varlist='TEMP'

    local var
    for var in $varlist; do
        nc_set_att -a coordinates,$var,o,c,'TIME LATITUDE LONGITUDE DEPTH' $nc_file
    done
}

#######################################
# IMOS function to fix SOOP XBT files #
#######################################
fix_imos_conventions() {
    local nc_file=$1; shift

    nc_set_common_imos_gatt $nc_file
    nc_set_geospatial_gatt $nc_file
    nc_set_geospatial_vertical_gatt $nc_file
    nc_set_att -a geospatial_vertical_positive,global,o,c,'down' $nc_file

    if ! nc_has_gatt $nc_file abstract; then
        nc_set_att -a abstract,global,o,c,"SOOP XBT" $nc_file
    fi
}


main() {
    local nc_file=$1; shift
    local netcdf_output=$1; shift

    # modify a temporary copy of the original netcdf
    local tmp_modified_file=`mktemp`
    cp $nc_file $tmp_modified_file

    fix_cf_conventions $tmp_modified_file
    fix_imos_conventions $tmp_modified_file

    cp $tmp_modified_file $netcdf_output
    rm $tmp_modified_file
}

main "$@"
