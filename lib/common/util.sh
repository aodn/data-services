#!/bin/bash

############################
# HELPER PRIVATE FUNCTIONS #
############################

# return a unique timestamp
_unique_timestamp() {
    date +%Y%m%d-%H%M%S
}
export -f _unique_timestamp

# generate graveyard file name. flattens name by changing all / to _ and adds
# timestamp. example:
# /mnt/opendap/1/file.nc -> _mnt_opendap_1_file.nc.TIMESTAMP
# $1 - full path to file
_graveyard_file_name() {
    local file=$1; shift
    local graveyard_file_name=`echo $file | sed -e 's#/#_#g'`
    graveyard_file_name="$graveyard_file_name".`_unique_timestamp`
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

# moves file to production filesystem
# $1 - file to move
_move_to_fs() {
    local src=$1; shift
    local dst=$1; shift

    if [ -f $dst ]; then
        file_error $src "'$dst' already exists"
        return 1
    fi

    log_info "Moving '$src' -> '$dst'"
    local dst_dir=`dirname $dst`
    mkdir -p $dst_dir || file_error $src "Could not create directory '$dst_dir'"
    _set_permissions $src || file_error $src "Could not set permissions on '$src'"
    mv $src $dst || file_error $src "Could not move '$src' -> '$dst'"
}
export -f _move_to_fs

# moves file to production filesystem, force deletion of file if it exists
# there already
# $1 - file to move
_move_to_fs_force() {
    local src=$1; shift
    local dst=$1; shift

    if [ -f $dst ]; then
        _remove_file $dst || return 1
    fi
    _move_to_fs $src $dst
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
        _set_permissions $file || file_error $file "Could not set permissions on '$file'"

        local dst=$GRAVEYARD_DIR/`_graveyard_file_name $file`
        log_info "Removing '$file', buried in graveyard as '$dst'"
        if ! mv $file $dst; then
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
    local dst=$dst_dir/`basename $file`.`_unique_timestamp`

    log_error "Moving '$file' -> '$dst'"
    mkdir -p $dst_dir || log_error "Could not create directory '$dst_dir'"
    mv $file $dst || log_error "Could not move '$file' -> '$dst'"

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

# moves file to opendap directory
# $1 - file to move
# $2 - relative path under filesystem
move_to_opendap() {
    local file=$1; shift
    local relative_path=$1; shift
    _move_to_fs $file $OPENDAP_DIR/$relative_path/`basename $file`
}
export -f move_to_opendap

# moves file to IMOS opendap directory
# $1 - file to move
# $2 - relative path under filesystem
move_to_opendap_imos() {
    local file=$1; shift
    local relative_path=$1; shift
    _move_to_fs $file $OPENDAP_IMOS_DIR/$relative_path/`basename $file`
}
export -f move_to_opendap_imos

# moves file to IMOS opendap directory, overriding existing files
# $1 - file to move
# $2 - relative path under filesystem
move_to_opendap_imos_force() {
    local file=$1; shift
    local relative_path=$1; shift
    _move_to_fs_force $file $OPENDAP_IMOS_DIR/$relative_path/`basename $file`
}
export -f move_to_opendap_imos_force

# moves file to public directory
# $1 - file to move
# $2 - relative path under filesystem
move_to_public() {
    local file=$1; shift
    local relative_path=$1; shift
    _move_to_fs $file $PUBLIC_DIR/$relative_path/`basename $file`
}
export -f move_to_public

# moves file to IMOS public directory
# $1 - file to move
# $2 - relative path under filesystem
move_to_public_imos() {
    local file=$1; shift
    local relative_path=$1; shift
    _move_to_fs $file $PUBLIC_IMOS_DIR/$relative_path/`basename $file`
}
export -f move_to_public_imos

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
