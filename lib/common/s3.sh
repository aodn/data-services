#!/bin/bash

################
# S3 FUNCTIONS #
################

# get a file from s3
# $1 - path on s3 (relative)
# $2 - destination path
s3_get() {
    local object_name=$1; shift
    local output=$1; shift
    $S3CMD get $S3_BUCKET/$object_name $output
}
export -f s3_get

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

    if ! $S3CMD del $dst; then
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

    s3_put_no_index_keep_file $src $object_name
    rm -f $src
}
export -f s3_put_no_index

# moves file to s3 bucket, keep original file
# $1 - file to move
# $2 - path on s3 (relative)
s3_put_no_index_keep_file() {
    local src=$1; shift
    local object_name=$1; shift
    local dst=$S3_BUCKET/$object_name
    local mime=''

    test -f $src || file_error "Not a regular file"

    if echo $S3CMD | grep -v -q mocked; then
        if [[ $src =~ \.gz$ ]]; then
            mime='application/gzip'
        elif [[ $src =~ \.nc$ ]]; then
            mime='application/octet-stream'
        elif [[ $src =~ \.csv$ ]]; then
            mime='text/csv'
        elif [[ $src =~ \.pdf$ ]]; then
            mime='application/pdf'
        elif [[ $src =~ \.png$ ]]; then
            mime='image/png'
        elif [[ $src =~ \.jpg$ ]]; then
            mime='image/jpeg'
        fi
    fi

    log_info "Moving '$src' -> '$dst'"

    if [ -z $mime ]; then
      # use guess mime
      $S3CMD --no-preserve sync $src $dst || file_error "Could not push to S3 '$src' -> '$dst'"
    else
      $S3CMD -m $mime --no-preserve sync $src $dst || file_error "Could not push to S3 '$src' -> '$dst'"
    fi
}
export -f s3_put_no_index_keep_file

# list folder on s3
# $1 - path of folder on s3
s3_ls() {
    local path=$1; shift
    # path must not end with /, we'll add the / later when listing
    if [[ "${path: -1}" = "/" ]]; then
        path=${path::-1}
    fi

    $S3CMD ls $S3_BUCKET/$path/ | tr -s " " | cut -d' ' -f4 | sed -e "s#^$S3_BUCKET/$path/##"
}
export -f s3_ls
