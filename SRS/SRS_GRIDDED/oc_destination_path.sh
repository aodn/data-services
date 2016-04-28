#!/bin/bash
# unit tests on shunit2_test_oc_destination_path.sh
# returns the relative imos hierarchy of ocean colour netcdf file
# author: laurent.besnard@utas.edu.au

# remove replace nc4 extension with nc
# $1 - netcdf filename
_check_and_replace_netcdf_extension() {
    local srs_file=$1; shift
    echo $srs_file | sed "s/\.nc4$/.nc/g"
}

# remove the nc4 extension if exsist, and remove if exist the ugly file version from the file
# $1 - netcdf filename
clean_netcdf_filename() {
    local srs_file=$1; shift
    _check_and_replace_netcdf_extension $srs_file
}

# files must start with 14 digits, and finish with .nc$ , not nc4, no file version
# $1 - netcdf filename
srs_file_path() {
    local srs_file=$1; shift
    local srs_filename=`basename $srs_file`
    local product_name="chl_gsm|chl_oc3|dt|ipar|K_490|l2_flags|nanop_brewin2010at|nanop_brewin2012in|npp_vgpm_eppley_gsm|npp_vgpm_eppley_oc3|owtd|par|picop_brewin2010at|picop_brewin2012in|sst|sst_quality|tsm_clark16"
    local srs_aqua_path=SRS/OC/gridded/aqua
    local srs_contributed_path=SRS/OC/gridded/contributed

    srs_filename=`clean_netcdf_filename $srs_filename`
    # get folder structure for different aqua products
    if echo $srs_filename | grep -q -E "^A[0-9]{8}.aust.(${product_name}).nc$"; then
        local year=`echo  $srs_filename | awk '{print substr($0,2,4)}'`
        local month=`echo $srs_filename | awk '{print substr($0,6,2)}'`
        echo $srs_aqua_path/1d/${year}/${month}/$srs_filename && return

    elif echo $srs_filename | grep -q -E "^[0-9]{6}.(${product_name}).nc$"; then
        year=`echo $srs_filename | awk '{print substr($0,1,4)}'`
        echo $srs_aqua_path/1m/${year}/$srs_filename && return

    elif echo $srs_filename | grep -q -E "^[0-9]{4}.(${product_name})_mean.nc$"; then
        echo $srs_aqua_path/1y/$srs_filename && return

    elif echo $srs_filename | grep -q -E "^[0-9]{4}-[0-9]{4}.[0-9]{2}.(${product_name})_mean.nc$"; then
        echo $srs_aqua_path/1mNy/$srs_filename && return

    elif echo $srs_filename | grep -q -E "^[0-9]{4}-[0-9]{4}.[0-9]{2}.(${product_name})_mean.nc$"; then
        echo $srs_aqua_path/1mNy/$srs_filename && return

    elif echo $srs_filename | grep -q -E "^[0-9]{4}-[0-9]{4}.[0-9]{2}-[0-9]{2}.(${product_name})_mean_mean_mean.nc$"; then
        echo $srs_aqua_path/12mNy/$srs_filename && return

    elif echo $srs_filename | grep -q -E "^[0-9]{4}-[0-9]{4}x[0-9]{2}-[0-9]{2}.(${product_name})_mean_mean.nc$"; then
        echo $srs_aqua_path/12mNy/$srs_filename && return
    fi

    # contribute datasets
    if echo $srs_filename | grep -q -E "^A[0-9]{8}.L3m_DAY_CHL_chlor_a_4km.nc$"; then
        year=`echo $srs_filename | awk '{print substr($0,2,4)}'`
        echo $srs_contributed_path/nasa-global-oc/1d/aqua/${year}/$srs_filename && return

    elif echo $srs_filename | grep -q -E "^S[0-9]{8}.L3m_DAY_CHL_chlor_a_9km.nc$"; then
        year=`echo $srs_filename | awk '{print substr($0,2,4)}'`
        echo $srs_contributed_path/nasa-global-oc/1d/seawifs/${year}/$srs_filename && return

    elif echo $srs_filename | grep -q -E "^T[0-9]{8}.L3m_DAY_CHL_chlor_a_4km.nc$"; then
        year=`echo $srs_filename | awk '{print substr($0,2,4)}'`
        echo $srs_contributed_path/nasa-global-oc/1d/terra/${year}/$srs_filename && return

    elif echo $srs_filename | grep -q -E "^A[0-9]{14}.L3m_8D_SO_Chl_9km.Johnson_SO_Chl.nc$"; then
        echo $srs_contributed_path/SO-Johnson/chl/8d/aqua/$srs_filename && return

    elif echo $srs_filename | grep -q -E "^S[0-9]{14}.L3m_8D_SO_Chl_9km.Johnson_SO_Chl.nc$"; then
        echo $srs_contributed_path/SO-Johnson/chl/8d/seawifs/$srs_filename && return

    elif echo $srs_filename | grep -q -E "^A[0-9]{14}.L3m_MO_SO_Chl_9km.Johnson_SO_Chl.nc$"; then
        echo $srs_contributed_path/SO-Johnson/chl/1m/aqua/$srs_filename && return

    elif echo $srs_filename | grep -q -E "^S[0-9]{14}.L3m_MO_SO_Chl_9km.Johnson_SO_Chl.nc$"; then
        echo $srs_contributed_path/SO-Johnson/chl/1m/seawifs/$srs_filename && return
    fi
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
