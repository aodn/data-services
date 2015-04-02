#!/bin/bash

############################
# HELPER PRIVATE FUNCTIONS #
############################

# return a unique timestamp
_unique_timestamp() {
    date +%Y%m%d-%H%M%S
}
export -f _unique_timestamp

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
    else
        log_info "Moving '$src' -> '$dst'"
        local dst_dir=`dirname $dst`
        mkdir -p $dst_dir || file_error $src "Could not create directory '$dst_dir'"
        _set_permissions $src || file_error $src "Could not set permissions on '$src'"
        mv $src $dst || file_error $src "Could not move '$src' -> '$dst'"
    fi
}
export -f _move_to_fs

# moves file to production filesystem
# $1 - file to move
_remove_file() {
    local file=$1; shift
    if [ ! -f $file ]; then
        log_error "Cannot remove '$file', does not exist"
        return 1
    else
        local dst="$GRAVEYARD/"
        log_info "Removing '$file' -> '$dst'"
        if ! mv $file $dst; then
            log_error "Cannot remove '$file' to '$dst'"
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

#####################
# UTILITY FUNCTIONS #
#####################

# returns uploader name (if any applicable) for given file
# $1 - netcdf file to check
get_uploader() {
    local file=$1; shift
    # TODO FTP/RSYNC UPLOADER PARSING HERE
}
export -f get_uploader

# sends an email
# $1 - recipient
# $2 - subject
# STDIN - message body
notify_by_email() {
    local recipient=$1; shift
    local subject="$1"; shift

    cat | mail -s "$subject" $recipient
}
export -f notify_by_email

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
