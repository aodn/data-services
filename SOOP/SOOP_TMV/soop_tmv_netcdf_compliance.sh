#!/bin/bash
# script to fix SOOP XBT files to make them pass the IMOS and CF checker (hopefully)
# used functions from data-services/lib/common/make_netcdf_pass_checker.sh

ACKNOWLEDGEMENT="Any users of IMOS data are required to clearly acknowledge \
the source of the material derived from IMOS in the format: \"Data was sourced from the Integrated Marine Observing System (IMOS) \
- IMOS is a national collaborative research infrastructure, supported by the Australian Government. \
This data was collected by the Environmental Protection Authority (EPA) of Victoria. Assistance with logistical and technical \
support for this project has been provided by the Spirit of Tasmania 1 vessel operator, TT lines \". "
#####################################
# CF function to fix SOOP TMV files #
#####################################

# make changes to pass CF compliance checks
# $1 - netcdf file
fix_cf_conventions() {
    local nc_file=$1; shift
    nc_set_att -a featureType,global,d,,  $nc_file
    nc_set_att -a featuretype,global,o,c,'trajectory' $nc_file
    nc_set_att -a units,PSAL,o,c,'1e-3' $nc_file
    nc_set_att -a units,TURB,o,c,'1' $nc_file
    nc_fix_cf_add_att_coord_to_variables $nc_file
}

########################
# CF FUNCTIONS #
########################

# fix variable attribute coordinates
# $1 - netcdf file
nc_fix_cf_add_att_coord_to_variables() {
    local nc_file=$1; shift
    local varlist="$(ncdump -h $nc_file | grep '(TIME)' | cut -d' ' -f2 | sed -e 's/(.*$//' | \
        sed -e 's/^TIME$//g' | sed -e 's/^LATITUDE$//g' | sed -e 's/^LONGITUDE$//g' | sed -e 's/^.*_quality_control$//g' | \
        sed -e 's/\t//g'  | sed -e '/^$/d' | tr '\n' ' ' )"

    local var
    for var in $varlist; do
        nc_set_att -a coordinates,$var,o,c,'TIME LATITUDE LONGITUDE' $nc_file
    done
}

#######################################
# IMOS function to fix SOOP TMV files #
#######################################
# make changes to pass IMOS compliance checks
# $1 - netcdf file
fix_imos_conventions() {
    local nc_file=$1; shift
    # original files contains date in Matlab format. Now, changed to be processing date
    local timestamp=`date -u "+%Y-%m-%dT%H:%M:%SZ"`
    nc_set_att -a date_created,global,o,c,"${timestamp}" $nc_file
    nc_set_att -a acknowledgement,global,o,c,"${ACKNOWLEDGEMENT}" $nc_file
}

main() {
    local nc_file=$1; shift

    local tmp_modified_file=`mktemp`
    cp $nc_file $tmp_modified_file

    fix_cf_conventions $tmp_modified_file || file_error "Could not fix CF"
    fix_imos_conventions $tmp_modified_file || file_error "Could not fix IMOS"

    cp $tmp_modified_file $nc_file
    rm $tmp_modified_file
}

main "$@"
