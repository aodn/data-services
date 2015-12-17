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
    chmod a+rx $tmp_dir
    unzip -q -u -o $file -d $tmp_dir || file_error "Error unzipping"

    local nc_file
    nc_file=`find $tmp_dir/. -name "*.nc" | head -1` || file_error "Cannot find NetCDF file in zip bundle"

    check_netcdf      $nc_file || file_error_and_report_to_uploader $BACKUP_RECIPIENT "Not a valid NetCDF file"
#    check_netcdf_cf   $file || file_error_and_report_to_uploader $BACKUP_RECIPIENT "File is not CF compliant"
#    check_netcdf_imos $file || file_error_and_report_to_uploader $BACKUP_RECIPIENT "File is not IMOS compliant"

    log_info "Processing '$nc_file'"
    local path
    path=`$SCRIPTPATH/destPath.py $nc_file` || file_error "Cannot generate path for NetCDF file"

    # this file will need indexing, so use s3_put
    s3_put $nc_file IMOS/SOOP/$path/`basename $nc_file`

    local extracted_file
    for extracted_file in `find $tmp_dir -type f`; do
        local file_basename=`basename $extracted_file`
        s3_put_no_index $extracted_file IMOS/SOOP/$path/$file_basename
    done

    rm -f $file # remove zip file
    #Dangerous, but necessary, since there might be a hierarchy in the zip file provided
    rm -rf --preserve-root $tmp_dir
}

main "$@"
