#!/bin/bash

# Netcdf diff up to 4 files.
# Uses ncdump arguments as first arguments to parse to nc_diff
# source this file in your bash_rc to use it as a function
# this function is different from GG which uses diff with the advantage
# of using diff and the standad output but can only diff 2 files at once

# This function on the other hand uses vimdiff which opens an interactive shell
# which is less versatil, but can diff up to 4 files.
# author laurent.besnard@utas.edu.au
function nc_diff(){

    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]
    then
        echo "Usage: ${FUNCNAME[0]} [ncdump option(s)] file1.nc file2.nc ... file4.nc";
	echo "esc :qa! to exit diff mode"
        return 0;
    fi

    local command='vimdiff'; #vimdiff handles if a file does not exist so no need to check
    local option='';

    for ARG in "$@"; do
        if [ "${ARG: -3}" != ".nc" ]
        then
            option="$option $ARG";
        else
            command="$command <(ncdump $option $ARG)";
        fi
    done
    eval $command;
}

