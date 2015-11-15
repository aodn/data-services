#!/bin/bash

alias error_dir="cd $ERROR_DIR"
alias incoming_dir="cd $INCOMING_DIR"

declare -x -r PROJECTOFFICER_USER=`stat --printf="%U" $DATA_SERVICES_DIR/env`
alias sudo_project_officer="sudo -u $PROJECTOFFICER_USER -s"

alias po_s3_del="_po_command s3_del"

# run command in manual mode
# "$@" command to run
_po_command() {
    local tmp_command_file=`mktemp`
    local _user=`whoami`

    # build a file with the specified command, we'll run it with sudo
    echo "#!/bin/bash"                             >> $tmp_command_file
    echo "source $DATA_SERVICES_DIR/env"           >> $tmp_command_file
    echo "export JOB_NAME='MANUAL_COMMAND_'$_user" >> $tmp_command_file
    echo "log_info \"Running: '$@'\""              >> $tmp_command_file
    echo "$@"                                      >> $tmp_command_file

    chmod 755 $tmp_command_file
    sudo -u $PROJECTOFFICER_USER $tmp_command_file
    local -i retval=$?

    rm -f $tmp_command_file

    return $retval
}
