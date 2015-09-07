#!/bin/bash

################
# S3 FUNCTIONS #
################

# make object public on s3
# $1 - path on s3 (relative)
s3_make_public() {
    local object_name=$1; shift
    local dst=$S3_BUCKET/$object_name

    log_info "Setting ACL public on '$dst'"

    local tmp_object=`mktemp`
    if ! s3cmd --config=$S3CMD_CONFIG get $dst $tmp_object; then
        log_error "Could not download '$dst'"
        return 1
    fi

    index_file $tmp_object $object_name
    local -i retval=$?
    rm -f $tmp_object

    if [ $retval -ne 0 ]; then
        log_error "Could not index '$object_name'"
        return 1
    fi

    if ! s3cmd --config=$S3CMD_CONFIG --acl-public setacl $dst; then
        log_error "Could not set public ACL on '$dst'"
        return 1
    fi
}
export -f s3_make_public

# make object private on s3
# $1 - path on s3 (relative)
s3_make_private() {
    local object_name=$1; shift
    local dst=$S3_BUCKET/$object_name

    log_info "Setting ACL private on '$object_name'"

    unindex_file $index_as || return 1

    if ! s3cmd --config=$S3CMD_CONFIG --acl-private setacl $dst; then
        log_error "Could not set private ACL on '$dst'"
        return 1
    fi
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
    [ x"$index_as" != x ] && index_file $src $index_as || file_error $src "Could not be indexed as '$index_as'"
    log_info "Moving '$src' -> '$dst'"
    s3cmd --config=$S3CMD_CONFIG put $src $dst || file_error $src "Could not push to S3 '$src' -> '$dst'"
    rm -f $src
}
export -f _s3_put

# moves file to s3 bucket, set ACL as private and does not index file!
# $1 - file to move
# $2 - destination on s3
_s3_put_private() {
    local src=$1; shift
    local dst=$1; shift

    _set_permissions $src || file_error $src "Could not set permissions on '$src'"
    log_info "Moving '$src' -> '$dst'"
    s3cmd --config=$S3CMD_CONFIG --acl-private put $src $dst || file_error $src "Could not push to S3 '$src' -> '$dst'"
    rm -f $src
}
export -f _s3_put_private

# delete a file from s3 bucket
# $1 - object name on s3 to delete
# $2 - name of object in index
_s3_rm() {
    local dst=$1; shift
    local index_as=$1; shift

    [ x"$index_as" != x ] && unindex_file $index_as || return 1
    log_info "Deleting '$dst'"
    s3cmd --config=$S3CMD_CONFIG rm $dst
}
export -f _s3_rm

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
    [ x"$index_as" != x ] && index_file $src $index_as
    log_info "Moving '$src' -> '$dst'"
    s3cmd --config=$S3CMD_CONFIG put $src $dst || log_error $src "Could not push to S3 '$src' -> '$dst'"
}
export -f _s3_put_never_fail
