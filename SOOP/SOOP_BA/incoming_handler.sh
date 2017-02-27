#!/bin/bash

declare -r BACKUP_RECIPIENT=benedicte.pasquer@utas.edu.au

# returns true (0) if file has a raw extension, which is one of:
# .ek5 .out .raw
# $1 - file
has_soop_ba_raw_extension() {
    local file=$1; shift
    has_extension $file "ek5" || \
        has_extension $file 'out' || \
        has_extension $file 'raw'
}

# is_soop_ba_file
# check that the file belongs to SOOP_BA subfacility
# $1 - file name
is_soop_ba_file() {
    local file=`basename $1`; shift
    echo $file | egrep -q '^IMOS_SOOP-BA_'
}

# returns 0 if directory has netcdf files, 1 otherwise
# $1 - path to directory
directory_has_netcdf_files() {
    local path=$1; shift
    s3_ls $path | grep -q "\.nc$"
}

# delete previous versions of a given file, returns 0 if anything was deleted,
# otherwise returns 1
# $1 - relative file path to delete previous versions of
delete_previous_versions() {
    local file=$1; shift
    local basename_file=`basename $file`

    local path=`dirname $file`
    local file_extension=`get_extension $file`

    local del_function='s3_del_no_index'
    local prev_versions_wildcard=".*\.${file_extension}$"

    if has_extension $file "nc"; then
        del_function='s3_del'
    elif has_extension $file "png" ||  has_extension $file "csv"; then
        local type=`echo $basename_file | cut -d '.' -f2`
        prev_versions_wildcard=".*\.${type}\.${file_extension}$"
    fi

    local prev_version_files=`s3_ls $path | grep "$prev_versions_wildcard" 2> /dev/null | xargs --no-run-if-empty -L1 basename | xargs`
    local prev_file
    for prev_file in $prev_version_files; do
        local basename_prev_file=`basename $prev_file`
        if [ $basename_prev_file != $basename_file ]; then
            log_info "Deleting '$basename_prev_file'"
            $del_function $path/$basename_prev_file || \
                file_error "Could not delete previous file '$basename_prev_file'"
        else
            log_info "Not deleting '$basename_prev_file', same name as new file"
        fi
    done
}
# notify_recipients
# notify uploader and backup recipient about status pof uploaded file
# $2 - message
notify_recipients() {
    local message="$1"; shift
    local recipient
    uploader_email=`get_uploader_email $INCOMING_FILE`

    if [ -n "$uploader_email" ]; then
        echo "" | notify_by_email $uploader_email "$message"
    fi
    echo "" | notify_by_email $BACKUP_RECIPIENT "$message"
}

# handles a single netcdf file, return path in which file is stored
# $1 - netcdf file
handle_netcdf_file() {
    local nc_file=$1; shift
    log_info "Processing '$nc_file'"
    echo "" | notify_by_email $BACKUP_RECIPIENT  "Processing new SOOP-BA file '$nc_file'"

#    local checks='cf imos:1.4'
    
    if ! is_soop_ba_file $nc_file; then
        file_error "Not a SOOP-BA file '$nc_file'" && notify_recipients "Not a SOOP-BA file " `basename $nc_file`
    else
	local tmp_nc_file=`make_writable_copy $nc_file` 
#        tmp_file_with_sig=`trigger_checkers_and_add_signature $nc_file $BACKUP_RECIPIENT $checks`
#    else
#        file_error_and_report_to_uploader $BACKUP_RECIPIENT "Not a SOOP-BA file '$nc_file'"
#        rm -f $tmp_file_with_sig $nc_file
#    fi
#    $tmp_nc_file=$tmp_file_with_sig 
        check_netcdf  $tmp_nc_file || \
	    file_error_and_report_to_uploader $BACKUP_RECIPIENT "Not a valid NetCDF file"
        if ! $DATA_SERVICES_DIR/SOOP/SOOP_BA/helper.py add_reporting_id $tmp_nc_file; then
	    rm -f $tmp_nc_file 
            file_error "Cannot add reporting_id"
        fi

        local path
        path=`$DATA_SERVICES_DIR/SOOP/SOOP_BA/helper.py dest_path $tmp_nc_file`
        if [ $? -ne 0 ]; then
            rm -f $tmp_nc_file
            file_error "Cannot generate path for NetCDF file"
        fi

        local -i is_update=0
        directory_has_netcdf_files IMOS/$path && is_update=1

        [ $is_update -eq 1 ] && delete_previous_versions IMOS/$path/`basename $nc_file`
        s3_put $tmp_nc_file IMOS/$path/`basename $nc_file` 1>/dev/null

        echo $path
	rm -f $nc_file
    fi
}


# handle a soop_ba zip bundle
# $1 - zip file bundle
handle_zip_file() {
    local file=$1; shift
    log_info "Handling SOOP BA zip file '$file'"

    echo "" | notify_by_email $BACKUP_RECIPIENT "Processing new SOOP_BA file '$file'"

    local tmp_dir=`mktemp -d`
    chmod a+rx $tmp_dir
    local tmp_zip_manifest=`mktemp`
    trap "rm -rf --preserve-root $tmp_dir && rm -f $file $tmp_zip_manifest" EXIT
    
    if ! is_soop_ba_file $file; then
         file_error "Not a SOOP-BA file '$file'" && notify_recipients "Not a SOOP-BA file " `basename $file`
    fi

    unzip_file $file $tmp_dir $tmp_zip_manifest
    if [ $? -ne 0 ]; then
	file_error "Error unzipping '$file'"
    fi

    local nc_file
    nc_file=`grep ".*.nc" $tmp_zip_manifest | head -1`

    if [ $? -ne 0 ]; then
         file_error "Cannot find NetCDF file in zip bundle"
    fi
    local path_to_storage=`handle_netcdf_file $tmp_dir/$nc_file`
    
    local -i is_update=0
    directory_has_netcdf_files IMOS/$path && is_update=1

    local extracted_file
    for extracted_file in `find $tmp_dir -type f`; do
        local basename_extracted_file=`basename $extracted_file`
        log_info "Extracted file '$basename_extracted_file'"
        if has_soop_ba_raw_extension $extracted_file; then
            log_info "Archiving '$extracted_file'"
            local path_to_raw=`echo $path_to_storage | cut -d '/' -f1,2`
            local path_to_data=`echo $path_to_storage | cut -d '/' -f3-`
            move_to_archive $extracted_file IMOS/$path_to_raw/raw/$path_to_data
        else
            [ $is_update -eq 1 ] && delete_previous_versions IMOS/$path_to_storage/$basename_extracted_file
            s3_put_no_index $extracted_file IMOS/$path_to_storage/$basename_extracted_file
        fi
    done

    # Dangerous, but necessary, since there might be a hierarchy in the zip file provided
}

# main
# $1 - file to handle
# pipeline handling either:
# processe zip file containing data file (.nc) , txt, doc or xml files
# script handles new and reprocessed files
main() {
    local file=$1; shift

    if has_extension $file "zip"; then
        handle_zip_file $file
    elif has_extension $file "nc"; then
        handle_netcdf_file $file
    else
        file_error "Unknown file extension '$file'"
    fi
    notify_recipients "Successfully published SOOP_BA file "`basename $file`
}

main "$@"

