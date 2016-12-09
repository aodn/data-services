#!/bin/bash

###########################
# EMAIL PRIVATE FUNCTIONS #
###########################

# returns a list of ftp log files in the system
_log_files_ftp() {
    local vsftpd_log_file=/var/log/vsftpd.log
    test -f $vsftpd_log_file && echo $vsftpd_log_file
}
export -f _log_files_ftp

# returns a list of rsync log files in the system
_log_files_rsync() {
    sudo cat /etc/rsyncd.conf | grep "log file = " | cut -d= -f2 | xargs
}
export -f _log_files_rsync

# returns uploader name if file was uploaded with ftp
# $1 - file uploaded
_get_uploader_ftp() {
    local file=$1; shift
    # an example ftp log line would look like:
    # Wed Jun 24 12:44:22 2015 [pid 3] [user3] OK UPLOAD: Client "1.1.1.1", "/realtime/file.nc", 23103 bytes, 103.59Kbyte/sec
    # an example file will be:
    # /var/incoming/facility/realtime/slocum_glider/StormBay20150616/unit286_track_mission.png
    # for the given file, we'll need to strip '/var/incoming' and then:
    # * facility
    # * realtime
    # * slocum_glider
    # * StormBay20150616
    # until we reach a basename of a file, then we give up

    local log_file
    for log_file in `_log_files_ftp`; do
        # start stripping the path until we get the best match
        local trimmed_file=`get_relative_path_incoming $file`
        log_info "Trimmed file '$trimmed_file'"

        while [[ $trimmed_file == *"/"* ]]; do # as long as string contains a slash
            local ftp_user=`test -f $log_file && sudo cat $log_file | grep ", \"/$trimmed_file\", " | grep " OK UPLOAD: " | tr -s " " | cut -d' ' -f8 | tail -1`
            log_info "Ftp User '$ftp_user'"

            # user will be in the form of "[user]", so strip the brackets
            [ x"$ftp_user" != x ] && echo ${ftp_user:1:-1} && return 0
            log_info "Ftp User trimmed '$ftp_user'"

            trimmed_file=${trimmed_file#*/} # remove first directory and keep going
        done
    done

    return 1
}
export -f _get_uploader_ftp

# returns uploader name if file was uploaded with rsync
# $1 - file uploaded
_get_uploader_rsync() {
    local file=$1; shift
    # an example rsync log line would look like:
    # 2015/06/24 14:13:05 [8979] recv unknown [2.2.2.2] srs_staging (user6) sst/ghrsst/L3C-1d/index.nc 5683476

    for log_file in `_log_files_rsync`; do
        local file=`get_relative_path_incoming $file`
        log_info "File '$file'"
        local rsync_user=`test -f $log_file && grep "\b$file\b" $log_file | tr -s " " | cut -d' ' -f8 | tail -1`
        log_info "Rsync User '$rsync_user'"
    done
    [ x"$rsync_user" = x ] && return 1

    # user will be in the form of "(user)", so strip the brackets
    echo ${rsync_user:1:-1}
}
export -f _get_uploader_rsync

# returns uploader name (if any applicable) for given file
# $1 - file uploaded
_get_uploader() {
    local file=$1; shift
    local uploader=""

    uploader=`_get_uploader_ftp $file` || \
        uploader=`_get_uploader_rsync $file`

    log_info "Uploader '$uploader'"
    echo $uploader
}
export -f _get_uploader

# returns the email lookup file which maps between usernames and their email
# addresses
_email_lookup_file() {
    echo $EMAIL_ALIASES
}
export -f _email_lookup_file

# returns email address of uploader
# $1 - username
_get_username_email() {
    local username=$1; shift
    log_info "Username '$username'"
    postmap -q $username `_email_lookup_file` 2> /dev/null
}
export -f _get_username_email

##########################
# EMAIL PUBLIC FUNCTIONS #
##########################

# sends an email
# $1 - recipient
# $2 - subject
# STDIN - message body
notify_by_email() {
    local recipient=$1; shift
    local subject="$1"; shift

    cat | MAILRC=$MAILX_CONFIG mail -s "$subject" $recipient
}
export -f notify_by_email

# sends an email to the uploader of the file, or to the person defined as a
# backup recipient with the report of the handled file
# $1 - file
# $2 - backup recipient (must be a valid email address)
# $3 - subject
send_report_to_uploader() {
    local file=$1; shift
    local backup_recipient=$1; shift
    local subject="$1"; shift

    local recipient
    recipient=`get_uploader_email $file` || recipient=$backup_recipient

    send_report $file $recipient "$subject"
}
export -f send_report_to_uploader

# sends netcdf checker report to specified recipient
# $1 - file
# $2 - recipient (must be a valid email address)
# $3 - subject
send_report() {
    local file=$1; shift
    local recipient=$1; shift
    local subject="$1"; shift

    log_info "Sending NetCDF Checker report to '$recipient'"
    get_netcdf_checker_report $file | notify_by_email $recipient "$subject"
}
export -f send_report

# returns email address of uploader
# $1 - uploaded file
get_uploader_email() {
    local file=$1; shift
    local uploader=`_get_uploader $file`
    local po='projectofficers@emii.org.au'

    if [ x"$uploader" != x ]; then
        local uploader_email=`_get_username_email $uploader`
        log_info "Uploader Email '$uploader_email'"
        if [ x"$uploader_email" != x ]; then
            echo $uploader_email
            return 0
        fi
    fi

    local error_msg = "Could not find uploader for file '$file'"
    log_error "'$error_msg'"
    log_error "Sending error email to '$po', Error: '$error_msg'"
    $error_msg | notify_by_email $po "$error_msg"
    return 1
}
export -f get_uploader_email
