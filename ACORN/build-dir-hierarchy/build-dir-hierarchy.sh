#!/bin/bash

declare -r PARENT_PREFIX=radial

# given a file, build its hierarchy
# $1 - file
build_hierarchy_for_file() {
    local file=$1; shift

    local file_basename=`basename $file`

    local station_name=`echo $file_basename | cut -d_ -f5`

    local year=`echo $file_basename | cut -d_ -f4 | cut -c1-4`
    local month=`echo $file_basename | cut -d_ -f4 | cut -c5-6`
    local day=`echo $file_basename | cut -d_ -f4 | cut -c7-8`

    echo "$PARENT_PREFIX/$station_name/$year/$month/$day"
}

# move a file from a flat hierarchy to a nested one (year/month/day)
# $1 - file to move
# $2 - output directory
move_file_to_hierarchy() {
    local file=$1; shift
    local out_dir=$1; shift

    local file_hierarchy=`build_hierarchy_for_file $file`

    mkdir -p $out_dir/$file_hierarchy/ && \
        mv $file $out_dir/$file_hierarchy/
}

main() {
    local in_dir=$1; shift
    local out_dir=$1; shift

    [ x"$in_dir" = x  ] || [ ! -d $in_dir  ] && echo "input directory does not exist"  && return 1
    [ x"$out_dir" = x ] || [ ! -d $out_dir ] && echo "output directory does not exist" && return 1

    local file
    for file in `find $in_dir -type f -name \*.nc`; do
        move_file_to_hierarchy $file $out_dir
    done
}

main "$@"
