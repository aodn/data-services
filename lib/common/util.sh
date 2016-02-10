#!/bin/bash

############################
# HELPER PRIVATE FUNCTIONS #
############################

# generate graveyard file name. flattens name by changing all / to _ and adds
# timestamp. example:
# /mnt/opendap/1/file.nc -> _mnt_opendap_1_file.nc.TIMESTAMP
# $1 - full path to file
_graveyard_file_name() {
    local file=$1; shift
    local graveyard_file_name=`echo $file | sed -e 's#/#_#g'`
    graveyard_file_name="$graveyard_file_name".$TRANSACTION_ID
    echo $graveyard_file_name
}
export -f _graveyard_file_name

# a wrapper for mv, with retries. useful because NFS might fail sometimes for
# no apparent reason
# $1 - source file
# $2 - destination
_mv_retry() {
    local src=$1; shift
    local dst=$1; shift
    local -i MAX_RETRIES=3
    local -i i
    for i in `seq 1 $MAX_RETRIES`; do
        mv -n -- $src $dst
        if [ $? -ne 0 ]; then
            log_error "Could not move '$src' -> '$dst', attempt $i/$MAX_RETRIES"
            sudo chmod 00444 $dst; rm -f $dst
            sleep 0.1
        else
            return 0
        fi
    done
    return 1
}
export -f _mv_retry

# bulk index/unindex files using talend
# $1 - directory to cd to before running harvester
# $2 - base to index files with (prefix, such as IMOS/Argo)
# $3 - file containing list of files to index
# "$@" - extra parameters to $HARVESTER_TRIGGER
_bulk_index_operation() {
    local cd_to=$1; shift
    local base=$1; shift
    local file_list=$1; shift

    test -z "$HARVESTER_TRIGGER" && log_info "Indexing disabled" && return 0

    log_info "Bulk indexing/unindexing files from '$file_list'"

    local tmp_harvester_output=`mktemp`
    local log_file=`get_log_file $LOG_DIR $file_list`
    (cd $cd_to && cat $file_list | $HARVESTER_TRIGGER --stdin -b $base "$@" >& $tmp_harvester_output)
    local -i retval=$?

    cat $tmp_harvester_output >> $log_file
    rm -f $tmp_harvester_output
    if [ $retval -ne 0 ]; then
        # log to specific log file and not the main log file
        log_error "Bulk indexing failed for '$file_list', verbose log saved at '$log_file'"
    fi

    return $retval
}
export -f _bulk_index_operation

# bulk index files using talend
# $1 - directory to cd to before running harvester
# $2 - base to index files with (prefix, such as IMOS/Argo)
# $3 - file containing list of files to index
index_files_bulk() {
    local cd_to=$1; shift
    local base=$1; shift
    local file_list=$1; shift
    _bulk_index_operation $cd_to $base $file_list
}
export -f index_files_bulk

# bulk unindex files using talend
# $1 - directory to cd to before running harvester
# $2 - base to index files with (prefix, such as IMOS/Argo)
# $3 - file containing list of files to index
unindex_files_bulk() {
    local cd_to=$1; shift
    local base=$1; shift
    local file_list=$1; shift
    _bulk_index_operation $cd_to $base $file_list --delete
}
export -f unindex_files_bulk

# calls talend to index a file
# $1 - source file to index (must be a real file)
# $2 - object name to index as
index_file() {
    local src=$1; shift
    local object_name=$1; shift

    test -z "$HARVESTER_TRIGGER" && log_info "Indexing disabled" && return 0

    log_info "Indexing file '$object_name', source file '$src'"
    chmod +r $src

    local tmp_harvester_output=`mktemp`
    local log_file=`get_log_file $LOG_DIR $src`
    $HARVESTER_TRIGGER -f $src,$object_name >& $tmp_harvester_output
    local -i retval=$?

    cat $tmp_harvester_output >> $log_file
    rm -f $tmp_harvester_output
    if [ $retval -ne 0 ]; then
        # log to specific log file and not the main log file
        log_error "Indexing file failed for '$src', verbose log saved at '$log_file'"
    fi

    return $retval
}
export -f index_file

# calls talend to unindex a file
# $1 - object to delete index for
unindex_file() {
    local object_name=$1; shift

    test -z "$HARVESTER_TRIGGER" && log_info "Indexing disabled" && return 0

    log_info "Deleting indexed file '$object_name'"

    local tmp_harvester_output=`mktemp`
    local log_file=`get_log_file $LOG_DIR $object_name`
    # when in delete mode, no need to pass real path to file, however we need
    # to pass pairs of `real_file,relative_path`, so just pass $object_name as
    # the real path, it doesn't matter at all
    $HARVESTER_TRIGGER --delete -f $object_name,$object_name >& $tmp_harvester_output
    local -i retval=$?

    cat $tmp_harvester_output >> $log_file
    if [ $retval -ne 0 ]; then
        # log to specific log file and not the main log file
        log_error "Index deletion failed for '$object_name', verbose log saved at '$log_file'"
    fi

    return $retval
}
export -f unindex_file

# returns true (0) if file can/should be indexed, false (1) otherwise
# $1 - object name to index as
can_be_indexed() {
    local object_name=$1; shift

    # run with --noop, if it returns 0 file should be indexed
    $HARVESTER_TRIGGER --noop -f $object_name,$object_name >& /dev/null
}
export -f index_file

# moves file to production filesystem
# $1 - file to move
# $2 - destination on filesystem
# $3 - index as (object name)
_move_to_fs() {
    local src=$1; shift
    local dst=$1; shift
    local index_as=$1; shift

    if [ -f $dst ] || [ -d $dst ]; then
        file_error "'$dst' already exists"
        return 1
    fi

    local dst_dir=`dirname $dst`
    mkdir -p $dst_dir || file_error "Could not create directory '$dst_dir'"
    log_info "Moving '$src' -> '$dst'"
    _mv_retry $src $dst || file_error "Could not move '$src' -> '$dst'"
}
export -f _move_to_fs

# moves file to production filesystem, force deletion of file if it exists
# there already
# $1 - file to move
# $2 - destination on filesystem
# $3 - index as (object name)
_move_to_fs_force() {
    local src=$1; shift
    local dst=$1; shift
    local index_as=$1; shift

    if [ -f $dst ]; then
        _remove_file $dst || return 1
    fi
    _move_to_fs $src $dst $index_as
}
export -f _move_to_fs_force

# delete file in production filesystem
# $1 - file to move
_remove_file() {
    local file=$1; shift
    if [ ! -f $file ]; then
        log_error "Cannot remove '$file', does not exist"
        return 1
    else
        # create graveyard if it doesn't exist
        test -d $GRAVEYARD_DIR || mkdir -p $GRAVEYARD_DIR || return 1

        # handle files in production with 000 permissions before they are
        # moved to graveyard (nfs errors)
        sudo chmod 00444 $file

        local dst=$GRAVEYARD_DIR/`_graveyard_file_name $file`
        log_info "Removing '$file', buried in graveyard as '$dst'"
        if ! _mv_retry $file $dst; then
            log_error "Error renaming '$file' to '$dst'"
            return 1
        fi
        local file_dir=`dirname $file`
        _collapse_hierarchy $file_dir
    fi
}
export -f _remove_file

# collapses a hierarchy of a filesystem by recursively deleting empty
# directories until reaching a directory that's not empty
# $1 - directory to start with
_collapse_hierarchy() {
    local dir=$1; shift

    # as long as directory exists and is removable - continue
    while [ x"$dir" != x ] && [ "$dir" != "/" ] && test -d $dir && rmdir $dir >& /dev/null; do
        dir=`dirname $dir`
    done
    return 0
}
export -f _collapse_hierarchy

###########################
# FILE HANDLING FUNCTIONS #
###########################

# strips transaction id suffix from given file
# $1 - file
strip_transaction_id() {
    local file=$1; shift
    echo ${file%.*} # simply strip the suffix after the dot
}

# move file to error directory
# $1 - file to move
# "$@" - message to log
_file_error() {
    local file=$1; shift

    if [ ! -f $file ]; then
        log_error "'$file' is not a valid file, aborting."
        exit 1
    fi

    log_error "Could not process file '$file': $@"

    local dst_dir=$ERROR_DIR/$JOB_NAME
    local dst=$dst_dir/`basename $file`.$TRANSACTION_ID

    log_error "Moving '$file' -> '$dst'"
    mkdir -p $dst_dir || log_error "Could not create directory '$dst_dir'"
    _mv_retry $file $dst || log_error "Could not move '$file' -> '$dst'"

    [ -v CLEAN_UP_LIST ] && [ -n "$CLEAN_UP_LIST" ] && rm -rf --preserve-root $CLEAN_UP_LIST

    exit 1
}
export -f _file_error

# moves handled file to error directory
# "$@" - message to log
file_error() {
    _file_error $INCOMING_FILE "$@"
}
export -f file_error

# uses file_error to handle a file error, also send email to specified recipient
# $1 - file to report
# $2 - recipient
# "$@" - message to log and subject for report email
file_error_and_report() {
    local recipient=$1; shift

    send_report $INCOMING_FILE $recipient "$@"
    _file_error $INCOMING_FILE "$@"
}
export -f file_error_and_report

# uses file_error to handle a file error, but also report the error to the
# uploader
# $1 - file to report
# $2 - backup recipient, in case we cannot determine uploader
# "$@" - message to log and subject for report email
file_error_and_report_to_uploader() {
    local backup_recipient=$1; shift

    send_report_to_uploader $INCOMING_FILE $backup_recipient "$@"
    _file_error $INCOMING_FILE "$@"
}
export -f file_error_and_report_to_uploader

# moves file to production filesystem
# $1 - file to move
# $2 - base path on production file system
# $3 - relative path on production file system aka object name
move_to_production_fs() {
    local file=$1; shift
    local base_path=$1; shift
    local object_name=$1; shift
    _move_to_fs $file $base_path/$object_name $object_name
}
export -f move_to_production_fs

# moves file to production filesystem/s3
# $1 - file to move
# $2 - base path on production file system
# $3 - relative path on production file system aka object name
move_to_production() {
    local file=$1; shift
    local base_path=$1; shift
    local object_name=$1; shift
    move_to_production_fs $file $base_path $object_name
}
export -f move_to_production

# moves file to production filesystem, overriding existing files
# $1 - file to move
# $2 - base path on production file system
# $3 - relative path on production file system aka object name
move_to_production_force() {
    local file=$1; shift
    local base_path=$1; shift
    local object_name=$1; shift
    _move_to_fs_force $file $base_path/$object_name $object_name
}
export -f move_to_production_force

# moves file to archive directory
# $1 - file to move
# $2 - relative path under filesystem
move_to_archive() {
    local file=$1; shift
    local relative_path=$1; shift
    _move_to_fs $file $ARCHIVE_DIR/$relative_path/`basename $file`
}
export -f move_to_archive

# returns relative path of file to given directory
# passing /mnt/1/test.nc /mnt results in 1/test.nc to be returned
# $1 - file
# $2 - directory
get_relative_path() {
    local file=$1; shift
    local path=$1; shift

    # empty $path? just return $file
    if [ -z $path ]; then
        echo $file; return
    fi

    # add trailing slash to given path
    if [[ "${path: -1}" != "/" ]]; then
        path="$path/"
    fi
    echo ${file##$path}
}
export -f get_relative_path

# returns relative path to incoming directory
# $1 - file
get_relative_path_incoming() {
    local file=$1; shift
    get_relative_path $file $INCOMING_DIR
}
export -f get_relative_path_incoming

# make a temporary, writable copy of a file, with the same basename
# print its full path
# $1 - file
make_writable_copy() {
    local file=$1; shift
    local file_basename=`basename $file`
    local tmp_file=`mktemp -t ${file_basename}.XXXXXX`
    cp $file $tmp_file && \
        chmod --reference=$file $tmp_file && \
        chmod u+w $tmp_file && \
        echo $tmp_file
}
export -f make_writable_copy

# returns extension of file
# $1 - file
get_extension() {
    local file=`basename $1`; shift
    [[ "$file" == *"."* ]] && echo ${file##*.}
}
export -f get_extension

# returns true (0) if file has given extension, false (1) otherwise
# $1 - file
# $2 - extension to compare with
has_extension() {
    local file=$1; shift
    local extension=$1; shift
    local file_extension=`get_extension $file`
    [ x"$file_extension" != x ] && [ "$extension" = "$file_extension" ]
}
export -f has_extension

# unzip a file and return a list of all extracted files (relative paths to
# given directory)
# $1 - file to unzip
# $2 - destination to unzip files
# $3 - file to write extracted files to (optional)
unzip_file() {
    local zip_file=$1; shift
    local dir=$1; shift
    local extracted_files_manifest=$1; shift

    if [ x"$extracted_files_manifest" = x ] || [ ! -f $extracted_files_manifest ]; then
        extracted_files_manifest=/dev/null
    fi

    # * unzip file
    # * search for extracting: or inflating: lines
    # * remove leading/trailing spaces
    # * strip relative path of directory
    unzip -o -d $dir $zip_file | \
        grep "extracting:\|inflating:" | \
        cut -d: -f2 | \
        sed -e 's#^\s\+##' -e 's#\s\+$##' -e "s#^$dir/##" > $extracted_files_manifest
}
export -f unzip_file
