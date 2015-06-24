#!/bin/bash

#############################
# NETCDF CHECKING FUNCTIONS #
#############################

export NETCDF_CHECKER=/usr/local/bin/netcdf-checker

# a wrapper to run the netcdf checker
# $1 - file
# "$@" - netcdf check arguments
_netcdf_checker() {
    local file=$1; shift
    local tmp_checker_output=`mktemp`
    $NETCDF_CHECKER $file "$@" >& $tmp_checker_output
    if [ $? -ne 0 ]; then
        # log to specific log file and not the main log file
        local log_file=`get_log_file $LOG_DIR $file`
        cat $tmp_checker_output >> $log_file; rm -f $tmp_checker_output
        log_error "NetCDF checker failed, verbose log saved at '$log_file'"
        return 1
    fi
    rm -f $tmp_checker_output
}
export -f _netcdf_checker

# checks a netcdf file
# $1 - netcdf file to check
check_netcdf() {
    local file=$1; shift
    ncdump -h $file >& /dev/null
}
export -f check_netcdf

# checks a netcdf file for CF compliance
# $1 - netcdf file to check
check_netcdf_cf() {
    local file=$1; shift
    _netcdf_checker $file --test=cf
}
export -f check_netcdf_cf

# checks a netcdf file for IMOS compliance
# $1 - netcdf file to check
check_netcdf_imos() {
    local file=$1; shift
    _netcdf_checker $file --test=imos
}
export -f check_netcdf_imos

# checks a netcdf file for an IMOS facility compliance
# $1 - netcdf file to check
# $2 - facility specific plugin
check_netcdf_facility() {
    local file=$1; shift
    local facility=$1; shift
    _netcdf_checker $file --test=$facility
}
export -f check_netcdf_facility

