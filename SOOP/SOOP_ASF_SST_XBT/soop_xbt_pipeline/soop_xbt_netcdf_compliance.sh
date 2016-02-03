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
    _nc_del_fillvalue_depth_dimension $nc_file
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

_nc_del_fillvalue_depth_dimension() {
    local nc_file=$1; shift
    local script_dir=`dirname "$0"`

    # fix depth dimension
    if [ -f $script_dir/return_soop_xbt_good_depth_dimension.py ]; then
      local depth_dimension=`$script_dir/return_soop_xbt_good_depth_dimension.py $nc_file`
      local cdl_tempfile=`mktemp`

      ncdump $nc_file > $cdl_tempfile
      # modify the line 3 of the CDL file. ALL XBT file should be written the same way. We still check we change the right dimension
      sed -n '3p' $cdl_tempfile | grep -q DEPTH && sed -i "3s/.*/        DEPTH = $depth_dimension ;/" $cdl_tempfile && ncgen  -k4 -o $nc_file $cdl_tempfile
      rm $cdl_tempfile
    fi
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
