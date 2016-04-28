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

    test -f $src || file_error "Not a regular file"

    log_info "Moving '$src' -> '$dst'"

    $S3CMD --no-preserve sync $src $dst || file_error "Could not push to S3 '$src' -> '$dst'"
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

# list recursively a folder on s3 and returns list of fullpath of file objects
# $1 - path of folder on s3
s3_ls_recur() {
    local folder=${1%/}; shift # remove trailing slash
    local object

    for object in `s3lsv -a -b imos-data -k $folder/`; do
        # check if object is a folder
        if `echo "$object" | grep -E -q '\/$'`; then
            s3_ls_recur "$object"
        else
            echo "$object" | grep -o -E "$folder.*$"
        fi
    done
}
export -f s3_ls_recur

# download recursively s3 objects from a given folder object
# ex: s3_dl_recur_latest_version UWA /tmp/download_test
# $1 - path of folder on s3
# $2 - path of output folder where files will be downloaded keeping same structure
s3_dl_recur_latest_version() {
    local folder=$1; shift
    local output_folder=$1; shift
    [ -z "$output_folder" ] && { echo "output_folder is empty"; return 1; }
    mkdir -p $output_folder  || return 1

    # only keeping uniq filename objects
    local file_list=`s3_ls_recur $folder | uniq | sort`
    local object
    local obj_info

    for object in $file_list; do
        obj_info=`s3lsv -a -b imos-data -k $object`
        # if more than one version of same object, we reverse sort the second column(date) and take the first line
        # i.e. the lastest object version
        # date format is yyyy-mm-ddTHH:MM:SS
        obj_info=`echo $obj_info | sort -b -r -k 2.1,2.4 -k 2.6,2.7 -k 2.9,2.10 -k 2.12,2.13 -k 2.15,2.16 -k 2.18,2.19 | head -1`

        obj_vers=`echo "$obj_info" | awk {'print $1'}`
        obj_name=`echo "$obj_info" | awk {'print $3'}`
        obj_date=`echo "$obj_info" | awk {'print $2'}`

        mkdir -p `dirname $output_folder/$obj_name`
        echo "Downloading $obj_name"
        s3lsv -a -b imos-data -k $obj_name -o $output_folder/$obj_name -v $obj_vers
    done
}
export -f s3_dl_recur_latest_version
