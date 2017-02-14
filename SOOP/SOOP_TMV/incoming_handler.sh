#!/bin/bash
# Processing of SOOP-TMV raltime and delayedmode data
# Realtime data : zip archived,  log files pushed as is to S3
# Delayed mode : 3 type of DM file produced by toolbox :FV00,FV01,FV02
# FV00 and FV01 archived, FV02 pushed to S3

declare -r BACKUP_RECIPIENT=benedicte.pasquer@utas.edu.au

# check that the file belongs to SOOP_TMV subfacility
# $1 - file name
is_soop_tmv_file() {
    local file=`basename $1`; shift
    echo $file | egrep -q '^IMOS_SOOP-TMV_'
}

# check that the file is FV02
is_FV02_product_file() {
    local file=`basename $1`; shift
    echo $file | egrep -q '_FV02_'
}

#check that file is SOOP_TMV NRT file 
is_soop_tmv_nrt() {
    local file=`basename $1`; shift
    echo $file | egrep -q '^EPA_SOOP_TMV1'
}	

#check that file nrt metadata file
is_nrt_metadata() {
    local file=`basename $1`; shift
    echo $file | egrep -q 'meta.txt$'
}

#handle_zip_file
# $1 - file_name
# realtime data sent in zip ; original zip archived 
# realtime data pushed to S3 as is 
handle_zip_file() {
    local zip_file=$1; shift
    log_info "Handling SOOP TMV ZIP  '$zip_file'"
    is_soop_tmv_nrt $zip_file || file_error "Not a SOOP TMV NRT zip file"

    local tmp_dir=`mktemp -d`
    chmod a+rx $tmp_dir
    local tmp_zip_manifest=`mktemp`

    unzip_file $zip_file $tmp_dir $tmp_zip_manifest
    if [ $? -ne 0 ]; then
        rm -f $tmp_zip_manifest
        rm -rf --preserve-root $tmp_dir
        file_error $recipient "Error unzipping '$zip_file'"
    fi

    local extracted_file    
    for extracted_file in `cat $tmp_zip_manifest`; do
        local basename_extracted_file=`basename $extracted_file`
        if is_nrt_metadata $extracted_file; then
            echo "Skipping "$basename_extracted_file
        else
            local path
            path=`$DATA_SERVICES_DIR/SOOP/SOOP_TMV/dest_path.py set_destination_path $extracted_file 'S3' 'NRT'`
            if [ $? -ne 0 ]; then
   	        rm -rf --preserve-root $tmp_dir 
                file_error "Cannot generate path for NRT file"
            fi
	    s3_put_no_index $tmp_dir/$extracted_file IMOS/$path/$basename_extracted_file
	         
        fi
    done

    local path_to_archive
    path_to_archive=`$DATA_SERVICES_DIR/SOOP/SOOP_TMV/dest_path.py set_destination_path $zip_file 'archive' 'NRT'` 
    
    move_to_archive $zip_file IMOS/$path_to_archive

    # cleaning
    rm -rf --preserve-root $tmp_dir
 }
    
# handle_netdf_file 
# $1 - file to handle
# 3 type of netcdf file can be processed:
# FV00 : raw NRT log file converted to netCDF: moved to archive
# FV01 : QCed version on FV00 : moved to archive 
# FV02 : 10 sec average product : pushed to S3
#
handle_netcdf_file() {
    local nc_file=$1; shift
    local checks='cf imos:1.4'
    log_info "Handling SOOP TMV file '$nc_file'"

    is_soop_tmv_file $nc_file || file_error "Not a SOOP TMV file"
    
    if is_FV02_product_file $nc_file; then

        local tmp_nc_file_with_sig
        tmp_nc_file_with_sig=`trigger_checkers_and_add_signature $nc_file $BACKUP_RECIPIENT $checks`
        if [ $? -ne 0 ]; then
            rm -f $tmp_nc_file_with_sig
            return 1
        fi
        
        local path
        path=`$DATA_SERVICES_DIR/SOOP/SOOP_TMV/dest_path.py set_destination_path $nc_file 'S3' 'DM'`
        if [ $? -ne 0 ]; then
            rm -f $tmp_nc_file_with_sig
            file_error "Cannot generate path for NetCDF file"
        fi

        local tmp_plot_dir=`mktemp -d`
        $DATA_SERVICES_DIR/SOOP/SOOP_TMV/create_plot.py $tmp_nc_file_with_sig $tmp_plot_dir
        if [ $? -ne 0 ]; then
            rm -f $tmp_nc_file_with_sig; rmdir $tmp_plot_dir
            file_error "Failed creating figures"
        fi

        s3_put $tmp_nc_file_with_sig IMOS/$path/`basename $nc_file` && \
        rm -f $tmp_nc_file_with_sig

        local plot_file
        for plot_file in $tmp_plot_dir/*; do
            s3_put_no_index $plot_file IMOS/$path/`basename $plot_file`
            if [ $? -ne 0 ]; then
                rm -f $tmp_plot_dir/*; rmdir $tmp_plot_dir
            fi
        done

        rmdir $tmp_plot_dir
        rm -f $nc_file

    else   #FV00 and FV01
        local path_to_archive
	path_to_archive=`$DATA_SERVICES_DIR/SOOP/SOOP_TMV/dest_path.py set_destination_path \
		$nc_file 'archive' 'DM'`    
	move_to_archive $nc_file IMOS/$path_to_archive
    fi
}

main() {
    local file=$1; shift
    
    if has_extension $file "zip"; then # file is NRT 
        handle_zip_file $file
    elif has_extension $file "nc"; then # file is DM
        handle_netcdf_file $file
    else
        file_error_and_report_to_uploader $BACKUP_RECIPIENT "Unknown file extension "`basename $file`
    fi
}
main "$@"
