#!/bin/bash

#####################
# RSYNC LOG PARSING #
#####################

# returns a list of files that were added in an rsync itemized list
# $1 - input file
get_rsync_additions() {
    local rsync_output_file=$1; shift

    grep '^>f......... ' $rsync_output_file | tr -s " " | cut -d' ' -f2
}
export -f get_rsync_additions

# returns a list of files that were deleted in an rsync itemized list
# $1 - input file
get_rsync_deletions() {
    local rsync_output_file=$1; shift

    grep '^\*deleting ' $rsync_output_file | tr -s " " | cut -d' ' -f2
}
export -f get_rsync_deletions

####################
# LFTP LOG PARSING #
####################

# returns a list of files that were added in an lftp log
# $1 - input file
# $2 - base of local directory lftp synced to
get_lftp_additions() {
    local lftp_output_file=$1; shift
    local local_base=$1; shift

    local line
    while read line; do
        if _is_lftp_addition "$line"; then
            _get_lftp_file_addition "$line" | sed -e "s#^$local_base/##"
        fi
    done < $lftp_output_file
}
export -f get_lftp_additions

# returns a list of files that were deleted in an lftp log
# $1 - input file
# $2 - base of local directory lftp synced to
get_lftp_deletions() {
    local lftp_output_file=$1; shift
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
    # sample line is:
    # get -O /tmp/argo/dac/csio/2900322 ftp://ftp.ifremer.fr/ifremer/argo/dac/csio/2900322/2900322_Rtraj.nc
    # we take the basename from the `ftp://` part and add it to the
    # /tmp/argo/dac/... part
    local path_basename=`basename ${line[3]}`
    echo ${line[2]}/$path_basename
    unset line
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
