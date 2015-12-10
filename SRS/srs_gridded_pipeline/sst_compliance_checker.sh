#!/bin/bash
# script to fix SRS GHRSST SST files to make them pass the CF checker

####################################
# cf function to fix srs sst files #
####################################

# fix netcdf file to pass cf convention
# $1 netcdf file
_nc_fix_srs_sst_file_to_cf_convention() {
    local nc_file=$1; shift

    nc_set_att -a calendar,time,o,c,'gregorian' $nc_file # missing attribute
    nc_set_att -a Conventions,global,o,c,'CF-1.6' $nc_file # v1.7 in file not yet released

    # remove the next 2 attributes
    nc_set_att -a add_offset,quality_level,d,b,0 $nc_file
    nc_set_att -a scale_factor,quality_level,d,b,1 $nc_file

    # l2p_flags variable
    ncap2 -O -s 'l2p_flags=int(l2p_flags)' $nc_file $nc_file # only char, int8, int32. int16 is not accepted (see https://github.com/aodn/compliance-checker/blob/master/compliance_checker/cf/cf.py#L811)
    local flag_meanings="microwave land ice lake river reserved aerosol analysis lowwind highwind edge terminator reflector swath delta_dn"
    nc_set_att -a flag_meanings,l2p_flags,o,c,"$flag_meanings" $nc_file # comma separated is not correct
    local flag_masks="1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384"
    nc_set_att -a flag_masks,l2p_flags,o,i,"$flag_masks" $nc_file
    nc_set_att -a valid_max,l2p_flags,o,i,32767 $nc_file
    nc_set_att -a valid_min,l2p_flags,o,i,0 $nc_file
}

# copy of function for Edward's testing only. Have to remove on prod
# "$@" - parameters for ncatted
nc_set_att() {
    ncatted "$@"
}


# fix netcdf file
# $1 - input file
# $2 - output file
main() {
    local nc_file=$1; shift
    local netcdf_output=$1; shift

    # we modify a temporary copy of the original netcdf
    local tmp_modified_file=`mktemp`
    cp $nc_file $tmp_modified_file

    _nc_fix_srs_sst_file_to_cf_convention $tmp_modified_file

    cp $tmp_modified_file $netcdf_output
    rm $tmp_modified_file
    return 0
}

main "$@"
