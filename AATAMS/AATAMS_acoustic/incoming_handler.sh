#!/bin/bash
# AATAMS_ACOUSTIC pipeline :
# input : ZIP file
#
# Requirements: the Zip archive must contain a TagMetadata.txt file 
# Datafiles must comply with format( required number of data field)
#
# B. Pasquer July2017

DEST_PATH=IMOS/AATAMS/acoustic_tagging
BACKUP_RECIPIENT=benedicte.pasquer@utas.edu.au
export PYTHONPATH="$DATA_SERVICES_DIR/lib/python"
export SCRIPTPATH="$DATA_SERVICES_DIR/AATAMS/AATAMS_acoustic"

is_metadata() {
    local file=`basename $1`; shift
    echo $file | egrep -q "TagMetadata.txt" 
}

#handle a  zip bundle
# $1 - zip file bundle
handle_zip_file() {
    local zipfile=$1; shift

    log_info "Handling AATAMS acoustic zip file '$zipfile'"
    
    local tmp_dir=`mktemp -d`
    chmod a+rx $tmp_dir
    local tmp_zip_manifest=`mktemp`

    unzip_file $zipfile $tmp_dir $tmp_zip_manifest
    if [ $? -ne 0 ]; then
        rm -rf --preserve-root $tmp_dir
        file_error "Error unzipping"
    fi
    
    # First find metadata file and push it to S3
    local metadata_file
    metadata_file=`grep ".*\.txt" $tmp_zip_manifest | head -1`

    if [ $? -ne 0 ]; then
        rm -rf --preserve-root $tmp_dir
        file_error "Cannot find metadata file in zip bundle"
    elif ! is_metadata $metadata_file ; then
        rm -f $tmp_zip_manifest; rm -rf --preserve-root $tmp_dir
	file_error "Failed REGEX. Metadata file name not recognised"
    else # push to S3
        s3_put_no_index $tmp_dir/$metadata_file $DEST_PATH/`basename $metadata_file`
    fi

    # Check if are corrupt/have right format

    local extracted_file
    for extracted_file in `cat $tmp_zip_manifest`; do
        if is_metadata $extracted_file ; then
            continue # skip already processed netcdf file
        else
            log_info "Extracted file '$extracted_file'"
            local is_valid_csv
            is_valid_csv=`$SCRIPTPATH/check_csv.py $tmp_dir/$extracted_file`
            if [ $? -ne 0 ]; then
                file_error "File is corrupt or doesn't have enough columns  "$extracted_file
            else #push to S3
                s3_put $tmp_dir/$extracted_file $DEST_PATH/$extracted_file 
            fi
        fi
	rm -f $zipfile
    done

    rm -f $tmp_zip_manifest; rm -rf --preserve-root $tmp_dir    
}


# main
# $1 - zip file to handle

# New Data  submitted as zip containing metadata(TagMetadata.txt) and data(csv) together. 
# Data Update submitted as zip with csv only. In this case we assume the metadata stored on S3 are valid. 
main() {
    local file=$1; shift

    if has_extension $file "zip"; then
        handle_zip_file $file
    else
        file_error $BACKUP_RECIPIENT "Unknown file extension "`basename $file`
    fi
}

main "$@"
