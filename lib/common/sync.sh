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

    grep '^\*deleting ' $rsync_output_file | tr -s " " | cut -d' ' -f2 | \
        grep -v "/$" # ignore deleted directories
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

    grep "^get -O " $lftp_output_file | _parse_lftp_file_addition_line | \
        sed -e "s#^$local_base/##"
}
export -f get_lftp_additions

# returns a list of files that were deleted in an lftp log
# $1 - input file
# $2 - base of local directory lftp synced to
get_lftp_deletions() {
    local lftp_output_file=$1; shift
    local local_base=$1; shift

    grep "^rm " $lftp_output_file | cut -d' ' -f2 | \
        sed -e "s#^file:$local_base/##"
}
export -f get_lftp_deletions

# returns file from lftp itemized addition line
# STDIN - line
_parse_lftp_file_addition_line() {
    local line
    while read line; do
        line=(${line// / })
        # sample line is:
        # get -O /tmp/argo/dac/csio/2900322 ftp://ftp.ifremer.fr/ifremer/argo/dac/csio/2900322/2900322_Rtraj.nc
        # we take the basename from the `ftp://` part and add it to the
        # /tmp/argo/dac/... part
        local path_basename=`basename ${line[3]}`
        echo ${line[2]}/$path_basename
    done
}
export -f _parse_lftp_file_addition_line
