#!/bin/bash

# given a file, build its hierarchy
# $1 - file
build_hierarchy_for_file() {
    local file=$1; shift

    local file_basename=`basename $file`

    # by default, use radial as the type
    local type=radial

    # if file has '_sea-state.' in it, it's a vector
    if echo $file_basename | grep -q '_sea-state\.'; then
        type=vector
    fi

    local station_name=`echo $file_basename | cut -d_ -f5`

    local year=`echo $file_basename | cut -d_ -f4 | cut -c1-4`
    local month=`echo $file_basename | cut -d_ -f4 | cut -c5-6`
    local day=`echo $file_basename | cut -d_ -f4 | cut -c7-8`

    echo "$type/$station_name/$year/$month/$day"
}

# set permissions on file
# $1 - file to set permissions on
set_permissions() {
    local file=$1; shift
    chmod 664 $file
}

# fix permissions from base directory and iterate in until reaching a file
# if we get a base directory of '/mnt/aa' and a hierarchy of 'a/b/c/r.nc' we'll
# make sure that all the directories below have the correct permissions:
# * /mnt/aa/a
# * /mnt/aa/a/b
# * /mnt/aa/a/b/c
#
# $1 - base directory
# $2 - hierarchy of directories
set_hierarchy_permissions() {
    local base_dir=$1; shift
    local file_hierarchy=$1; shift

    local current_dir=$base_dir

    # iterate on all parts and fix permissions if necessary, start with
    # $base_dir and append parts from $file_hierarchy as you go, setting
    # permissions on every part
    IFS="/"
    for part in $file_hierarchy; do
        current_dir="$current_dir/$part"
        chmod 775 "$current_dir"
    done
    unset IFS
}

# move a file from a flat hierarchy to a nested one (year/month/day)
# $1 - file to move
# $2 - output directory
move_file_to_hierarchy() {
    local file=$1; shift
    local out_dir=$1; shift

    local file_hierarchy=`build_hierarchy_for_file $file`

    mkdir -p $out_dir/$file_hierarchy/ && \
        set_hierarchy_permissions $out_dir $file_hierarchy && \
        cp $file $out_dir/$file_hierarchy/ && \
        set_permissions $out_dir/$file_hierarchy/`basename $file` && \
        rm -f $file
}

main() {
    local in_dir=$1; shift
    local out_dir=$1; shift

    [ x"$in_dir"  = x ] || [ ! -d $in_dir  ] && echo "input directory does not exist"  && return 1
    [ x"$out_dir" = x ] || [ ! -d $out_dir ] && echo "output directory does not exist" && return 1

    local file
    for file in `find $in_dir -type f -name \*.nc`; do
        move_file_to_hierarchy $file $out_dir
    done
}

main "$@"
