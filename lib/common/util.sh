#!/bin/bash

############################
# HELPER PRIVATE FUNCTIONS #
############################

# generate a unique transaction id
if [ -z $TRANSACTION_ID ]; then
    declare -r -x TRANSACTION_ID=`date +%Y%m%d-%H%M%S`
fi

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

# set standard permissions on target file
# $1 - file
_set_permissions() {
    local file=$1; shift
    local group=`id -g -n`

    # TODO eradicate use of sudo
    sudo chmod 00444 $file && sudo chown $USER:$group $file
}
export -f _set_permissions

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
        mv -n $src $dst
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

# calls talend to index a file
# $1 - source file to index (must be a real file)
# $2 - object name to index as
_index_file() {
    return # TODO we're not ready yet for that

    local src=$1; shift
    local object_name=$1; shift

    test -z "$HARVESTER_TRIGGER" && log_info "Indexing disabled" && return 0

    log_info "Indexing file '$object_name', source file '$src'"

    local tmp_harvester_output=`mktemp`
    local log_file=`get_log_file $LOG_DIR indexer`
    $HARVESTER_TRIGGER -f $src,$object_name >& $tmp_harvester_output
    local -i retval=$?

    cat $tmp_harvester_output >> $log_file
    if [ $retval -ne 0 ]; then
        # log to specific log file and not the main log file
        log_error "Indexing file failed for '$src', verbose log save at '$log_file'"
    fi

    return $retval
}
export -f _index_file

# moves file to s3 bucket
# $1 - file to move
# $2 - destination on s3
# $3 - index as (object name)
_move_to_s3() {
    local src=$1; shift
    local dst=$1; shift
    local index_as=$1; shift

    _set_permissions $src || file_error $src "Could not set permissions on '$src'"
    [ x"$index_as" != x ] && _index_file $src $index_as
    log_info "Moving '$src' -> '$dst'"
    s3cmd --config=$S3CMD_CONFIG put $src $dst || file_error $src "Could not push to S3 '$src' -> '$dst'"
    rm -f $src
}
export -f _move_to_s3

# TODO this function should be removed!
# moves file to s3 bucket, never fail and don't delete source file
# $1 - file to move
# $2 - destination on s3
# $3 - index as (object name)
_move_to_s3_never_fail() {
    local src=$1; shift
    local dst=$1; shift
    local index_as=$1; shift

    test -f $S3CMD_CONFIG || return 1 # fail immediately if config is missing

    _set_permissions $src || return 1
    [ x"$index_as" != x ] && _index_file $src $index_as
    log_info "Moving '$src' -> '$dst'"
    s3cmd --config=$S3CMD_CONFIG put $src $dst || log_error $src "Could not push to S3 '$src' -> '$dst'"
}
export -f _move_to_s3_never_fail

# moves file to production filesystem
# $1 - file to move
# $2 - destination on filesystem
# $3 - index as (object name)
_move_to_fs() {
    local src=$1; shift
    local dst=$1; shift
    local index_as=$1; shift

    if [ -f $dst ]; then
        file_error $src "'$dst' already exists"
        return 1
    fi

    local dst_dir=`dirname $dst`
    mkdir -p $dst_dir || file_error $src "Could not create directory '$dst_dir'"
    _set_permissions $src || file_error $src "Could not set permissions on '$src'"
    [ x"$index_as" != x ] && _index_file $src $index_as
    log_info "Moving '$src' -> '$dst'"
    _mv_retry $src $dst || file_error $src "Could not move '$src' -> '$dst'"
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

# moves file to error directory
# $1 - file to move
# "$@" - message to log
file_error() {
    local file=$1; shift

    log_error "Could not process file '$file': $@"

    local dst_dir=$ERROR_DIR/$JOB_NAME
    local dst=$dst_dir/`basename $file`.$TRANSACTION_ID

    log_error "Moving '$file' -> '$dst'"
    mkdir -p $dst_dir || log_error "Could not create directory '$dst_dir'"
    _mv_retry $file $dst || log_error "Could not move '$file' -> '$dst'"

    exit 1
}
export -f file_error

# uses file_error to handle a file error, also send email to specified recipient
# $1 - file to report
# $2 - recipient
# "$@" - message to log and subject for report email
file_error_and_report() {
    local file=$1; shift
    local recipient=$1; shift

    send_report $file $recipient "$@"
    file_error $file "$@"
}
export -f file_error_and_report

# uses file_error to handle a file error, but also report the error to the
# uploader
# $1 - file to report
# $2 - backup recipient, in case we cannot determine uploader
# "$@" - message to log and subject for report email
file_error_and_report_to_uploader() {
    local file=$1; shift
    local backup_recipient=$1; shift

    send_report_to_uploader $file $backup_recipient "$@"
    file_error $file "$@"
}
export -f file_error_and_report_to_uploader

# moves file to s3
# $1 - file to move
# $2 - relative path on s3 (object name)
move_to_production_s3() {
    local file=$1; shift
    local object_name=$1; shift
    # TODO _move_to_s3 $file $S3_BUCKET/$object_name $object_name
    _move_to_s3_never_fail $file $S3_BUCKET/$object_name $object_name
}
export -f move_to_production_s3

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
