#!/bin/bash

###########
# LOGGING #
###########

# returns path of log file for specific
# $1 - base log directory (usually $LOG_DIR)
# $2 - file being handled (sets context for logging)
get_log_file() {
    local log_dir=$1/$JOB_NAME; shift
    local file=`basename $1`; shift
    mkdir -p $log_dir
    echo $log_dir/${file}.$TRANSACTION_ID.log
}
export -f get_log_file

# log a message
# $1 - log level
# STDIN - log message
_log_msg() {
    local log_level=$1; shift

    local msg
    while read -e msg; do
        logger -t $JOB_NAME -p ${SYSLOG_FACILITY}.${log_level} -- "$msg"
    done
}
export -f _log_msg

# log an error message
# "$@" - log message
log_error() {
    echo "$@" | _log_msg "error"
}
export -f log_error

# log a warning message
# "$@" - log message
log_warn() {
    echo "$@" | _log_msg "warning"
}
export -f log_warn

# log an information message
# "$@" - log message
log_info() {
    echo "$@" | _log_msg "info"
}
export -f log_info

# log a stdout/stderr message
# STDIN - log message
log_out() {
    cat | _log_msg "debug"
}
export -f log_out
