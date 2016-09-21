#!/bin/bash

export PYTHONPATH="$DATA_SERVICES_DIR/SOOP"
export SCRIPTPATH="$DATA_SERVICES_DIR/SOOP/SOOP_CO2"

declare -r BACKUP_RECIPIENT=benedicte.pasquer@utas.edu.au

# is_imos_soop_co2_file
# check that the file from IMOS SOOP_CO2
# $1 - file name
is_imos_soop_co2_file() {
    local file=`basename $1`; shift
    echo $file | egrep -q '^IMOS_SOOP-CO2_'
}

# is_future_reef_map_file
# check that the file belongs toFuture Reef MAP project
# $1 - file name
is_future_reef_map_file() {
    local file=`basename $1`; shift
    echo $file | egrep -q '^FutureReefMap_'
}

# main
# $1 - file to handle
main() {
    local file=$1; shift
    log_info "Handling SOOP CO2 zip file '$file'"
    local recipient=`get_uploader_email $file`
    if [ -n "$recipient" ]; then
        echo "" | notify_by_email $recipient "Processing new underway CO2 zip file '$file'"
    fi
    echo "" | notify_by_email $BACKUP_RECIPIENT "Processing new underway CO2 zip file '$file'"

    local tmp_dir=`mktemp -d`
    chmod a+rx $tmp_dir
    local tmp_zip_manifest=`mktemp`

    unzip_file $file $tmp_dir $tmp_zip_manifest
    if [ $? -ne 0 ]; then
        rm -f $tmp_zip_manifest
        rm -rf --preserve-root $tmp_dir
        file_error "Error unzipping"
    fi

    local nc_file
    nc_file=`grep ".*.nc" $tmp_zip_manifest | head -1`
    if [ $? -ne 0 ]; then
        rm -f $tmp_zip_manifest
        rm -rf --preserve-root $tmp_dir
        file_error "Cannot find NetCDF file in zip bundle"
    fi

    log_info "Processing '$nc_file'"

    local tmp_nc_file=`make_writable_copy $tmp_dir/$nc_file`

    local tmp_nc_file_with_sig
    local checks='cf imos:1.3'

    if is_imos_soop_co2_file $tmp_nc_file; then
        tmp_nc_file_with_sig=`trigger_checkers_and_add_signature $tmp_nc_file $BACKUP_RECIPIENT $checks`
    elif is_future_reef_map_file $tmp_nc_file; then
        checks='cf'
        tmp_nc_file_with_sig=`trigger_checkers_and_add_signature $tmp_nc_file $BACKUP_RECIPIENT $checks`
    else
        file_error "Not an underway CO2 file '$nc_file'"
        rm -f $tmp_zip_manifest $tmp_nc_file_with_sig $tmp_nc_file
        rm -rf --preserve-root $tmp_dir
    fi
    tmp_nc_file=$tmp_nc_file_with_sig

    local path
    path=`$SCRIPTPATH/dest_path.py $tmp_nc_file` || file_error "Cannot generate path for "`basename $tmp_nc_file`

    s3_put $tmp_nc_file $path/`basename $nc_file` && rm -f $tmp_dir/$nc_file

    local extracted_file
    for extracted_file in `find $tmp_dir -type f`; do
        local file_basename=`basename $extracted_file`
        s3_put_no_index $extracted_file $path/$file_basename
    done
    if [ -n "$recipient" ]; then
           echo "" | notify_by_email $recipient "Successfully published SOOP_CO2 file '$path' "
    fi
    echo "" | notify_by_email $BACKUP_RECIPIENT "Successfully published SOOP_CO2 file '$path'"

    rm -f $file # remove zip file
    #Dangerous, but necessary, since there might be a hierarchy in the zip file provided
    rm -rf --preserve-root $tmp_dir
}


main "$@"
