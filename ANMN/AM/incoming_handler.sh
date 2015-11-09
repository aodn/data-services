#!/bin/bash

export PYTHONPATH="$DATA_SERVICES_DIR/ANMN"
export SCRIPTPATH="$DATA_SERVICES_DIR/ANMN/AM"

declare -r BACKUP_RECIPIENT=marty.hidas@utas.edu.au
declare -r BASE_HIERARCHY_PREFIX='IMOS/ANMN/AM'

# handle a netcdf file for the facility
# $1 - file to handle
handle_netcdf() {
    local file=$1; shift
    local basename_file=`basename $file`

    local checks='cf imos'
    local tmp_file=`trigger_checkers_and_add_signature $file $BACKUP_RECIPIENT $checks`

    local path_hierarchy
    path_hierarchy=`$SCRIPTPATH/destPath.py $file` || file_error "Could not determine destination path for file"
    [ x"$path_hierarchy" = x ] && file_error "Could not determine destination path for file"

    local path_hierarchy=$BASE_HIERARCHY_PREFIX/$path_hierarchy

    # archive previous version of file if found on opendap
    local prev_version_files
    prev_version_files=`$SCRIPTPATH/previousVersions.py $file $DATA_DIR/$path_hierarchy` \
        || file_error "Could not find previously published versions of file"

    local prev_file
    for prev_file in $prev_version_files; do
        local basename_prev_file=`basename $prev_file`
        if [ $basename_prev_file != $basename_file ]; then
            s3_del $path_hierarchy/`basename $prev_file` || file_error "Could not delete previous files"
        else
            log_info "Not deleting '$basename_prev_file', same name as new file"
        fi
    done

    s3_put $tmp_file $path_hierarchy/$basename_file && \
        rm -f $file
}

# handle a netcdf file for the facility
# $1 - file to handle
handle_csv() {
    local file=$1; shift

    # generate NetCDF file using python script
    local wip_dir="$WIP_DIR/ANMN/AM"
    mkdir -p $wip_dir || file_error "Could not create wip directory '$wip_dir'"

    # copy the csv file to the wip dir with a unique name
    mkdir -p $wip_dir/tmp/
    cp -p $file $wip_dir/tmp/`basename $file`.`date +%Y%m%d-%H%M%S`

    local netcdf_file
    netcdf_file=`cd $wip_dir && $SCRIPTPATH/rtCO2.py $file` || file_error "Could not generate NetCDF file"

    if [ x"$netcdf_file" = x ]; then
        # no new NetCDF file created because csv file contains no new data since last run
        log_info "Nothing new to process"
        rm -f $file
    else
        local netcdf_file_full_path="$wip_dir/$netcdf_file"
        test -f $netcdf_file_full_path || file_error "Could not generate NetCDF file"

        handle_netcdf $netcdf_file_full_path && \
            rm -f $file
    fi
}

# main
# $1 - file to handle
main() {
    local file=$1; shift

    if has_extension $file "nc"; then
        handle_netcdf $file
    elif has_extension $file "csv"; then
        handle_csv $file
    else
        file_error "Not a NetCDF nor a csv file"
    fi
}

main "$@"
