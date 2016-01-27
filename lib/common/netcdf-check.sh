#!/bin/bash

#############################
# NETCDF CHECKING FUNCTIONS #
#############################

export NETCDF_CHECKER=/usr/local/bin/netcdf-checker

# a wrapper to run the netcdf checker
# $1 - file
# "$@" - netcdf check arguments
netcdf_checker() {
    local file=$1; shift
    local tmp_checker_output=`mktemp`
    local tmp_checker_errors=`mktemp`
    export UDUNITS2_XML_PATH="$DATA_SERVICES_DIR/lib/udunits2/udunits2.xml"
    $NETCDF_CHECKER $file "$@" > $tmp_checker_output 2> $tmp_checker_errors
    local -i retval=$?

    if [ $retval -ne 0 ]; then
        # log to specific log file and not the main log file
        local log_file=`get_log_file $LOG_DIR $file`
        cat $tmp_checker_errors $tmp_checker_output >> $log_file
        if [ $retval == 2 ]; then
            log_error "WARNING! Exceptions occurred while running checker (details in log)."
        fi
        log_error "File did not pass all compliance checks, verbose log saved at '$log_file'"
    fi
    rm -f $tmp_checker_output $tmp_checker_errors

    return $retval
}
export -f netcdf_checker

# dumps the netcdf checker report for a given file to stdout
# $1 - file
get_netcdf_checker_report() {
    local file=$1; shift
    local log_file=`get_log_file $LOG_DIR $file`
    cat $log_file
}
export -f get_netcdf_checker_report

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
    return 1
    netcdf_checker $file --test=cf
}
export -f check_netcdf_cf

# checks a netcdf file for IMOS compliance
# $1 - netcdf file to check
check_netcdf_imos() {
    local file=$1; shift
    netcdf_checker $file --test=imos
}
export -f check_netcdf_imos

# checks a netcdf file for an IMOS facility compliance
# $1 - netcdf file to check
# $2 - facility specific plugin
check_netcdf_facility() {
    local file=$1; shift
    local facility=$1; shift
    netcdf_checker $file --test=$facility
}
export -f check_netcdf_facility

# return the path where the compliance checker code is checked out
_get_checker_code_dir() {
    dirname `readlink -f $NETCDF_CHECKER`
}
export -f _get_checker_code_dir

# return the current commit hash of the checker
_get_checker_commit_hash() {
    cd `_get_checker_code_dir` && \
        git log -1 --format=format:'%H'
}
export -f _get_checker_commit_hash

# return the date/time of the current commit of the checker
_get_checker_commit_date() {
    cd `_get_checker_code_dir` && \
        git log -1 --format=format:'%ci'
}
export -f _get_checker_commit_date

# add/update global attributes in a netCDF file to record the fact
# that it has passed the checker.
#   - compliance_checker_version (including commit has e.g. "1.1.1 (77dd26bbc8852e1aeeaf7523ab084f552d6f5fe9)")
#   - compliancd_checker_last_updated (date/time e.g "2015-11-16 17:51:07 +1100")
#   - history (append e.g. "passed CF compliance checks")
# Arguments:
# $1 - file
# "$@" - checker suites passed
add_checker_signature() {
    local file=$1; shift

    local checker_version=`$NETCDF_CHECKER --version`
    local version_number=`echo $checker_version | egrep 'IOOS compliance checker version' | egrep -o '[0-9.]+$'`

    local commit_hash=`_get_checker_commit_hash`
    local last_updated=`_get_checker_commit_date`

    # convert to UTC
    local date_format='%F %T %Z'
    last_updated=`date --date="$last_updated" -u +"$date_format"`

    local history=`date -u +"$date_format"`": passed compliance checks: $@ ($checker_version)"

    # append as a new line if previous history exists
    nc_has_gatt $file 'history' && history="\n$history"

    nc_set_att -Oh -a compliance_checker_version,global,o,c,"$version_number ($commit_hash)" $file && \
    nc_set_att -Oh -a compliance_checker_last_updated,global,o,c,"$last_updated" $file && \
    nc_set_att -Oh -a history,global,a,c,"$history" $file || \
	log_error "Could not update global attributes in '$file'"
}
export -f add_checker_signature

# trigger netcdf checker for file
# $1 - file
# $2 - backup email recipient (passing 'null' implies no email sending)
# "$@" - suites (checkers) to trigger
trigger_checkers() {
    local file=$1; shift
    local backup_recipient=$1; shift

    error_handler=file_error
    if [ "$backup_recipient" != "null" ]; then
        error_handler="file_error_and_report_to_uploader $backup_recipient"
    fi

    check_netcdf $file || \
        $error_handler "Not a NetCDF file"

    local check_suite
    for check_suite in "$@"; do
        local checker_function="check_netcdf_${check_suite}"
        $checker_function $file || \
            $error_handler "NetCDF file does not comply with '${check_suite}' conventions"
    done
}
export -f trigger_checkers

# trigger netcdf checker for file. if all checks pass, make a temp
# copy of the file and add checker signature. print temp filename
# $1 - file
# $2 - backup email recipient (passing 'null' implies no email sending)
# "$@" - suites (checkers) to trigger
trigger_checkers_and_add_signature() {
    local file=$1; shift
    local backup_recipient=$1; shift

    trigger_checkers $file $backup_recipient $@

    if [ ${#@} == 0 ]; then
        # no compliance checks triggered, so no signature
        echo $file
    else
        local tmp_file
        tmp_file=`make_writable_copy $file` && \
            add_checker_signature $tmp_file $@ && \
            echo $tmp_file
    fi
}
export -f trigger_checkers_and_add_signature
