#!/bin/bash

declare -r BACKUP_RECIPIENT=benedicte.pasquer@utas.edu.au

# check that the file belongs to SOOP_TMV subfacility
# $1 - file name
is_soop_tmv_file() {
    local file=`basename $1`; shift
    echo $file | egrep -q '^IMOS_SOOP-TMV_'
}

# main
# $1 - file to handle
main() {
    local nc_file=$1; shift
    local checks='cf imos'
    log_info "Handling SOOP TMV file '$nc_file'"

    is_soop_tmv_file $nc_file || file_error "Not a SOOP TMV file"

    local tmp_nc_file=`make_writable_copy $nc_file`

    $DATA_SERVICES_DIR/SOOP/SOOP_TMV/soop_tmv_netcdf_compliance.sh $tmp_nc_file

    tmp_nc_file=`trigger_checkers_and_add_signature $tmp_nc_file $BACKUP_RECIPIENT $checks` || return 1

    local path
    path=`$DATA_SERVICES_DIR/SOOP/SOOP_TMV/destPath.py $nc_file` || \
        file_error "Cannot generate path for NetCDF file"

    log_info "path '$path'"
    s3_put $tmp_nc_file IMOS/$path/`basename $nc_file` && rm -f $nc_file
}

main "$@"
