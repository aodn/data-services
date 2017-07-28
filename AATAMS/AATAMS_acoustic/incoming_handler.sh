#!/bin/bash
# AATAMS_ACOUSTIC pipeline :
# input : ZIP file
#
# Requirements: the Zip archive must contain a TagMetadata.txt file 
# Datafiles must comply with format( required number of data field)
#
# B. Pasquer July2017

export PYTHONPATH="$DATA_SERVICES_DIR/lib/python"
export SCRIPTPATH="$DATA_SERVICES_DIR/AATAMS/AATAMS_acoustic"
declare -r DEST_PATH=IMOS/AATAMS/acoustic_tagging
declare -r BACKUP_RECIPIENT=benedicte.pasquer@utas.edu.au
declare -r ACOUSTIC_WIP_DIR=$WIP_DIR/acoustic_tagging; mkdir -p $ACOUSTIC_WIP_DIR
declare -r TAG_METADATA_FILE='TagMetadata.txt'

is_metadata() {
    local file=`basename $1`; shift
    echo $file | egrep -q "$TAG_METADATA_FILE" 
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
    else
       # copy to WIP to allow local harvesting (file used as context in harvester) 
       # and push to s3 for publication
       cp $tmp_dir/$metadata_file $ACOUSTIC_WIP_DIR/$TAG_METADATA_FILE
       s3_put_no_index $tmp_dir/$metadata_file $DEST_PATH/`basename $metadata_file`
       
       # delete file reference from the manifest
       sed -i "/$metadata_file/d" "$tmp_zip_manifest"
    fi

    # Check if file is corrupt/have right format
    local extracted_file
    for extracted_file in `cat $tmp_zip_manifest`; do
       log_info "Processing file '$extracted_file'. Checking format"
       local is_valid_csv
       is_valid_csv=`$SCRIPTPATH/check_csv.py $tmp_dir/$extracted_file`
       if [ $? -ne 0 ]; then
            file_error "File is corrupt or doesn't have enough columns  "$extracted_file
        fi
    done
    
     # index files in the zip manifest
    index_files_bulk $tmp_dir $DEST_PATH $tmp_zip_manifest
    if [ $? -ne 0 ]; then
        # unindex all files previously indexed 
        unindex_files_bulk $tmp_dir $DEST_PATH $tmp_zip_manifest 
        file_error "Failed indexing files, aborting operation. Unindexing files already indexed..."
    fi
    # pushing files to S3  
    for extracted_file in `cat $tmp_zip_manifest`; do
        s3_put_no_index_keep_file $tmp_dir/$extracted_file $DEST_PATH/$extracted_file || \
	    file_error "Failed uploading '$file', aborting operation..."
    done

    rm -f $tmp_zip_manifest; rm -f $zipfile;
    rm -rf --preserve-root $tmp_dir    
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
