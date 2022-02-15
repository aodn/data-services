#!/bin/bash

############################
# HELPER PRIVATE FUNCTIONS #
############################

# calls talend to unindex a file
# $1 - object to delete index for
unindex_file() {
    local object_name=$1; shift

    test -z "$HARVESTER_TRIGGER" && log_info "Indexing disabled" && return 0

    log_info "Deleting indexed file '$object_name'"

    local tmp_harvester_output=`mktemp`
    local log_file=`get_log_file $LOG_DIR $object_name`
    # when in delete mode, no need to pass real path to file, however we need
    # to pass pairs of `real_file,relative_path`, so just pass $object_name as
    # the real path, it doesn't matter at all
    $HARVESTER_TRIGGER --delete -f $object_name,$object_name >& $tmp_harvester_output
    local -i retval=$?

    cat $tmp_harvester_output >> $log_file
    if [ $retval -ne 0 ]; then
        # log to specific log file and not the main log file
        log_error "Index deletion failed for '$object_name', verbose log saved at '$log_file'"
    fi

    return $retval
}
export -f unindex_file

# returns true (0) if file can/should be indexed, false (1) otherwise
# $1 - object name to index as
can_be_indexed() {
    local object_name=$1; shift

    # run with --noop, if it returns 0 file should be indexed
    $HARVESTER_TRIGGER --noop -f $object_name,$object_name >& /dev/null
}
export -f can_be_indexed
