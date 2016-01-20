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

    local tmp_nc_file_with_sig
    tmp_nc_file_with_sig=`trigger_checkers_and_add_signature $tmp_nc_file $BACKUP_RECIPIENT $checks`
    if [ $? -ne 0 ]; then
        rm -f $tmp_nc_file $tmp_nc_file_with_sig
        return 1
    fi
    rm -f $tmp_nc_file
    tmp_nc_file=$tmp_nc_file_with_sig

    local path
    path=`$DATA_SERVICES_DIR/SOOP/SOOP_TMV/destPath.py $nc_file`
    if [ $? -ne 0 ]; then
        rm -f $tmp_nc_file
        file_error "Cannot generate path for NetCDF file"
    fi

    local tmp_plot_dir=`mktemp -d`
    $DATA_SERVICES_DIR/SOOP/SOOP_TMV/create_plot.py $tmp_nc_file $tmp_plot_dir
    if [ $? -ne 0 ]; then
        rm -f $tmp_nc_file; rmdir $tmp_plot_dir
        file_error "Failed creating figures"
    fi

    s3_put $tmp_nc_file_with_sig IMOS/$path/`basename $nc_file` && \
        rm -f $tmp_nc_file

    local plot_file
    for plot_file in $tmp_plot_dir/*; do
        s3_put_no_index $plot_file IMOS/$path/`basename $plot_file`
        if [ $? -ne 0 ]; then
            rm -f $tmp_plot_dir/*; rmdir $tmp_plot_dir
        fi
    done

    rmdir $tmp_plot_dir
    rm -f $nc_file
}

main "$@"
