#!/bin/bash

####################
# LFTP LOG PARSING #
####################

# returns a list of files that were added in an lftp log
# $1 - input file
get_lftp_additions() {
    local lftp_output_file=$1; shift
    local ftp_base=$1; shift
    local local_base=$1; shift

    local line
    while read line; do
        if _is_lftp_addition "$line"; then
            _get_lftp_file_addition "$line" | sed -e "s#^$ftp_base/##"
        fi
    done < $lftp_output_file
}
export -f get_lftp_additions

# returns a list of files that were deleted in an lftp log
# $1 - input file
get_lftp_deletions() {
    local lftp_output_file=$1; shift
    local ftp_base=$1; shift
    local local_base=$1; shift

    local line
    while read line; do
        if _is_lftp_deletion "$line"; then
            _get_lftp_file_deletion "$line" | sed -e "s#^file:$local_base/##"
        fi
    done < $lftp_output_file
}
export -f get_lftp_deletions

# returns file in lftp itemized line
# $1 - line
_get_lftp_file_addition() {
    local line="$1"; shift
    line=(${line// / })
    echo ${line[3]}; unset line
    # equivalent to `echo $line | cut -d' ' -f4` but faster!
}
export -f _get_lftp_file_addition

# returns file in lftp itemized line
# $1 - line
_get_lftp_file_deletion() {
    local line="$1"; shift
    line=(${line// / })
    echo ${line[1]}; unset line
    # equivalent to `echo $line | cut -d' ' -f2` but faster!
}
export -f _get_lftp_file_deletion

# return 0 (true) if line is lftp deletion
# $1 - line
_is_lftp_deletion() {
    local line="$1"; shift
    [ "${line:0:3}" = "rm " ] && return 0

    return 1
}
export -f _is_lftp_deletion

# return 0 (true) if line is lftp addition
# $1 - line
_is_lftp_addition() {
    local line="$1"; shift
    [ "${line:0:7}" = "get -O " ] && return 0

    return 1
}
export -f _is_lftp_addition
