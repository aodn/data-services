#!/bin/bash

################
# S3 FUNCTIONS #
################

# make object public on s3
# $1 - destination on s3
s3_make_public() {
    local dst=$1; shift
    s3cmd --config=$S3CMD_CONFIG --acl-public setacl $dst || file_error $src "Could not set ACL on '$dst'"
}
export -f s3_make_public

# make object private on s3
# $1 - destination on s3
s3_make_private() {
    local dst=$1; shift
    s3cmd --config=$S3CMD_CONFIG --acl-private setacl $dst || file_error $src "Could not set private ACL on '$dst'"
}
export -f s3_make_private

########################
# S3 PRIVATE FUNCTIONS #
########################

# moves file to s3 bucket
# $1 - file to move
# $2 - destination on s3
# $3 - index as (object name)
_s3_put() {
    local src=$1; shift
    local dst=$1; shift
    local index_as=$1; shift

    _set_permissions $src || file_error $src "Could not set permissions on '$src'"
    [ x"$index_as" != x ] && index_file $src $index_as
    log_info "Moving '$src' -> '$dst'"
    s3cmd --config=$S3CMD_CONFIG put $src $dst || file_error $src "Could not push to S3 '$src' -> '$dst'"
    rm -f $src
}
export -f _s3_put

# TODO this function should be removed!
# moves file to s3 bucket, never fail and don't delete source file
# $1 - file to move
# $2 - destination on s3
# $3 - index as (object name)
_s3_put_never_fail() {
    local src=$1; shift
    local dst=$1; shift
    local index_as=$1; shift

    test -f $S3CMD_CONFIG || return 1 # fail immediately if config is missing

    _set_permissions $src || return 1
    [ x"$index_as" != x ] && index_file $src $index_as
    log_info "Moving '$src' -> '$dst'"
    s3cmd --config=$S3CMD_CONFIG put $src $dst || log_error $src "Could not push to S3 '$src' -> '$dst'"
}
export -f _s3_put_never_fail
