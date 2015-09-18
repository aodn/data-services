#!/bin/bash

export PYTHONPATH="$DATA_SERVICES_DIR/SOOP"
export SCRIPTPATH="$DATA_SERVICES_DIR/SOOP/SOOP_CO2"

declare -r BACKUP_RECIPIENT=benedicte.pasquer@utas.edu.au

# is_soop_co2_file
# check that the file belongs to SOOP_CO2 subfacility
# $1 - file name
is_soop_co2_file() {
    local file=`basename $1`; shift
    echo $file | egrep -q '^IMOS_SOOP-CO2_'
}

# main
# $1 - file to handle
main() {
    local file=$1; shift
    log_info "Handling SOOP CO2 zip file '$file'"

    local tmp_dir=`mktemp -d`
    unzip -q -u -o $file -d $tmp_dir || file_error "Error unzipping"

    local nc_file
    nc_file=`ls -1 $tmp_dir/*.nc | head -1` || file_error "Cannot find NetCDF file in zip bundle"

    check_netcdf      $nc_file || file_error_and_report_to_uploader $file $BACKUP_RECIPIENT "Not a valid NetCDF file"
#    check_netcdf_cf   $file || file_error_and_report_to_uploader $file $BACKUP_RECIPIENT "File is not CF compliant"
#    check_netcdf_imos $file || file_error_and_report_to_uploader $file $BACKUP_RECIPIENT "File is not IMOS compliant"

    log_info "Processing '$nc_file'"
    local path
    path=`$SCRIPTPATH/destPath.py $nc_file` || file_error "Cannot generate path for NetCDF file"

    local extracted_file
    for extracted_file in $tmp_dir/*; do
        local file_basename=`basename $extracted_file`
        move_to_production $extracted_file $OPENDAP_DIR/1 IMOS/$path/$file_basename
        move_to_producion_s3 $extracted_file IMOS/$path/$file_basename
    done

    rm -f $file # remove zip file
    rmdir $tmp_dir
}

main "$@"
