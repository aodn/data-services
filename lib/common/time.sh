#!/bin/bash

##################
# TIME FUNCTIONS #
##################

# return true if rhs timestamp is after lhs. sample usage:
# timestamp_is_increasing 2015-11-30T19:21:08 2015-11-30T19:31:09
# returns true in this case
# $1 - lhs timestamp (ISO8601)
# $2 - rhs timestamp (ISO8601)
timestamp_is_increasing() {
    local lhs=`date --utc -d "$1" "+%s"`; shift
    local rhs=`date --utc -d "$1" "+%s"`; shift
    [ $rhs -gt $lhs ]
}
export -f timestamp_is_increasing
