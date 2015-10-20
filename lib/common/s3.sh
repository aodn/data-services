#!/bin/bash

################
# S3 FUNCTIONS #
################

# delete a file from s3 bucket (and call indexing)
# $1 - path on s3 (relative)
s3_del() {
    local object_name=$1; shift
    unindex_file $object_name || return 1
    s3_del_no_index $object_name
}
export -f s3_del

# delete a file from s3 bucket
# $1 - path on s3 (relative)
s3_del_no_index() {
    local object_name=$1; shift
    local dst=$S3_BUCKET/$object_name

    log_info "Deleting '$object_name'"

    if ! s3cmd --config=$S3CMD_CONFIG del $dst; then
        log_error "Could not delete '$dst'"
        return 1
    fi
}
export -f s3_del_no_index

# moves file to s3 bucket (and call indexing)
# $1 - file to move
# $2 - path on s3 (relative)
s3_put() {
    local src=$1; shift
    local object_name=$1; shift
    [ x"$object_name" != x ] && index_file $src $object_name || file_error "Could not be indexed as '$object_name'"
    s3_put_no_index $src $object_name
}
export -f s3_put

# moves file to s3 bucket
# $1 - file to move
# $2 - path on s3 (relative)
s3_put_no_index() {
    local src=$1; shift
    local object_name=$1; shift
    local dst=$S3_BUCKET/$object_name

    _set_permissions $src || file_error "Could not set permissions on '$src'"
    test -f $src || file_error "Not a regular file"

    log_info "Moving '$src' -> '$dst'"

    s3cmd --no-preserve --config=$S3CMD_CONFIG sync $src $dst || file_error "Could not push to S3 '$src' -> '$dst'"
    rm -f $src
}
export -f s3_put_no_index

########################
# S3 PRIVATE FUNCTIONS #
########################

# TODO this function should be removed!
# moves file to s3 bucket, never fail and don't delete source file
# $1 - file to move
# $2 - destination on s3
# $3 - index as (object name)
_s3_put_never_fail() {
    local src=$1; shift
    local dst=$1; shift
    local index_as=$1; shift

    test -f $S3CMD_CONFIG || return 1

    _set_permissions $src || return 1
    log_info "Moving '$src' -> '$dst'"
    s3cmd --config=$S3CMD_CONFIG put $src $dst || log_error $src "Could not push to S3 '$src' -> '$dst'"
}
export -f _s3_put_never_fail
