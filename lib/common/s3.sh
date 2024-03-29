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

# list the different versions of a s3 object
# see https://github.com/aodn/chef/blob/master/doc/README.data-tools.md
# $1 - s3 object path. example IMOS/SRS/SST/ghrsst/L3S-1dS/dn/2017/20170112111000-ABOM-L3S_GHRSST-SSTfnd-AVHRR_D-1d_dn_Southern.nc
s3_obj_info() {
    local s3_obj_path=$1; shift
    s3lsv -a -b imos-data -k $s3_obj_path
}
export -f s3_obj_info

# download s3 object version
# see https://github.com/aodn/chef/blob/master/doc/README.data-tools.md
# $1 - s3 object path
# $2 - s3 obect version
# $3 - writable output dir
s3_get_obj_ver() {
    local s3_obj_path=$1; shift
    local s3_obj_ver=$1; shift
    local output_dir=$1; shift
    mkdir -p $output_dir

    local obj_name=`basename $s3_obj_path`

    s3lsv -a -b imos-data -k $s3_obj_path -o $output_dir/$obj_name -v $s3_obj_ver
    echo $output_dir/$obj_name
}
export -f s3_get_obj_ver
