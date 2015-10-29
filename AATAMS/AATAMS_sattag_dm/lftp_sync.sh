#!/bin/bash

source $DATA_SERVICES_DIR/env

declare -r FTP_SOURCE=smuc.st-and.ac.uk
declare -r FTP_USER=IMOS
declare -r FTP_PASSWORD=Xav_Access
declare -r ZIPPED_DIR=$WIP_DIR/aatams_sattag_dm/zipped
declare -r UNZIPPED_DIR=$WIP_DIR/aatams_sattag_dm/unzipped
declare -r REQUIRED_TABLES="haulout_orig cruise ctd diag summary"
declare -r ERROR_DIR_AATAMS_SATTAG_DM=$ERROR_DIR/aatams_sattag_dm

# sync files from remote AATAMS ftp server
# $1 - ftp source
# $2 - destination directory
sync_files() {
    local ftp_source=$1; shift
    local dir=$1; shift
    local log_file=$LOG_DIR/AATAMS/aatams_sattag_dm/nrt_lftp.log
    mkdir -p `dirname $log_file`
    lftp -e "open -u $FTP_USER,$FTP_PASSWORD $ftp_source; lcd $dir; mirror -e --parallel=10 --exclude-glob *_ODV.zip -vvv --log=$log_file; quit"
}

# unzip given zip files in directory to destination directory
# $1 - source directory with zip files
# $2 - destination directory to unzip to
unzip_files() {
    local zipped_dir=$1; shift
    local unzipped_dir=$1; shift

    local -i retval=0

    local zip_file
    for zip_file in `find $zipped_dir -type f -name *.zip`; do
        unzip -o -d $unzipped_dir $zip_file
        let retval=$retval+$? # accumulate result
    done

    return $?
}

# remove all corrupted mdb files in given directory
# $1 - directory with mdb files
remove_corrupted_files() {
    local dir=$1; shift
    local mdb_file
    for mdb_file in `find $dir -type f`; do
        if ! mdb_has_tables $mdb_file $REQUIRED_TABLES; then
            echo "Moving '$mdb_file' to '$ERROR_DIR_AATAMS_SATTAG_DM'"
            mkdir -p $ERROR_DIR_AATAMS_SATTAG_DM
            mv $mdb_file $ERROR_DIR_AATAMS_SATTAG_DM
        else
            echo "File '$mdb_file' has all tables ('$REQUIRED_TABLES')"
        fi
    done
}

# main
main() {
    mkdir -p $ZIPPED_DIR $UNZIPPED_DIR
    sync_files $FTP_SOURCE $ZIPPED_DIR && \
        unzip_files $ZIPPED_DIR $UNZIPPED_DIR

    remove_corrupted_files $UNZIPPED_DIR
}

main "$@"
