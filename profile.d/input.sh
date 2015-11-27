#!/bin/bash

# error files auto complete
# $1 - facility
_error_files() {
    local facility=$1; shift
    local file
    for file in `find $ERROR_DIR/$facility -type f 2> /dev/null`; do
        basename $file
    done
}

# outputs all facilities
_facilities() {
    ls -1 $DATA_SERVICES_DIR/watch.d
}

# facilities auto complete
_autocomplete_aliases() {
    local prev=${COMP_WORDS[COMP_CWORD-1]}
    local cur=${COMP_WORDS[COMP_CWORD]}

    case ${COMP_CWORD} in
        1)
            local facilities=`_facilities | xargs`
            COMPREPLY=($(compgen -W "${facilities}" ${cur}))
            ;;
        2)
            local error_files=`_error_files $prev | xargs`
            COMPREPLY=($(compgen -W "${error_files}" ${cur}))
            ;;
        *)
            COMPREPLY=()
            ;;
    esac
}

# returns log file
_log_file() {
    echo $LOG_DIR/process.log
}

# returns older log file
_log_file_older() {
    echo $LOG_DIR/process.log.1
}

# normalize file by stripping transaction id (suffix)
# $1 - file to normalize
_normalize_file() {
    local file=$1; shift
    # quite rudimentary, just strip everything after the last dot
    echo ${file%.*}
}

# return report for file
# $1 - facility file belongs to
# $2 - file to get report for
_file_report() {
    local facility=$1; shift
    local file=$1; shift
    test -f $LOG_DIR/$facility/$file.log && cat $LOG_DIR/$facility/$file.log
}

# dumps error file in a readable format to stdout
# $1 - facility file belongs to
# $2 - file to show
_get_error_file_readable() {
    local facility=$1; shift
    local file=$1; shift
    local file_normalized=`_normalize_file $file`
    if [ ${file_normalized##*.} = "nc" ]; then # if file ends with .nc
        ncdump -h $ERROR_DIR/$facility/$file
    else
        cat $ERROR_DIR/$facility/$file
    fi
}

# shows input processing log
# $1 - facility (optional)
input_log() {
    local facility=$1; shift
    local file=$1; shift
    if [ x"$facility" != x ]; then
        if [ x"$file" != x ]; then
            local tmp_main_log_file=`mktemp`
            cat `_log_file_older` `_log_file` | grep "\b$facility: " | grep `_normalize_file $file` > $tmp_main_log_file

            local tmp_report=`mktemp`
            _file_report $facility $file > $tmp_report

            local tmp_file_output=`mktemp`
            _get_error_file_readable $facility $file > $tmp_file_output

            less $tmp_report $tmp_file_output $tmp_main_log_file
            rm -f $tmp_report $tmp_file_output $tmp_main_log_file
        else
            cat `_log_file_older` `_log_file` | grep "\b$facility: " | less
        fi
    else
        cat `_log_file_older` `_log_file` | less
    fi
}

# shows input processing log (with tail)
# $1 - facility (optional)
input_logf() {
    local facility=$1; shift
    if [ x"$facility" != x ]; then
        tail -f `_log_file` | grep "\b$facility: "
    else
        tail -f `_log_file`
    fi
}

complete -o bashdefault -o default -o nospace -F _autocomplete_aliases input_log 2>/dev/null \
    || complete -o default -o nospace -F _autocomplete_aliases input_log

complete -o bashdefault -o default -o nospace -F _autocomplete_aliases input_logf 2>/dev/null \
    || complete -o default -o nospace -F _autocomplete_aliases input_logf

# return relative path of incoming dir for facility given
# $1 - facility name
_incoming_dir_for_facility() {
    local facility=$1; shift
    jq -r ".path[0]" $DATA_SERVICES_DIR/watch.d/${facility}.json 2> /dev/null
}

# moves file back to incoming directory, try to reprocess them
# $1 - facility
# "$@" - files to move, if left blank, reprocess all files for facility
reprocess_files() {
    local facility=$1; shift

    local incoming_dir=`_incoming_dir_for_facility $facility`
    if [ x"$incoming_dir" = x ]; then
        echo "Error evaluating incoming directory for '$facility'"
        return 1
    fi

    if [ ! -d "$INCOMING_DIR/$incoming_dir" ]; then
        echo "'$INCOMING_DIR/$incoming_dir' is not a directory"
        return 1
    fi

    local src_file
    for src_file in "$@"; do
        src_file=$ERROR_DIR/$facility/$src_file
        if [ ! -f $src_file ]; then
            echo "'$src_file' is not a file"
            return 1
        fi

        dst_file=`basename $src_file`
        dst_file=`strip_transaction_id $dst_file`
        echo "Moving '$src_file' -> '$INCOMING_DIR/$incoming_dir/$dst_file'"
        mv $src_file $INCOMING_DIR/$incoming_dir/$dst_file
    done
}

complete -o bashdefault -o default -o nospace -F _autocomplete_aliases reprocess_files 2>/dev/null \
    || complete -o default -o nospace -F _autocomplete_aliases reprocess_files
