#!/bin/bash

# returns true (0) if given mdb (MS ACCESS) file is valid and has tables,
# return false otherwise
# $1 - mdb file
# "$@" - tables mdb file should contain
mdb_has_tables() {
    local file=$1; shift
    local mdb_tables
    mdb_tables=`mdb-tables $file` || return 1 # not a valid mdb file

    local missing_tables=""
    local table
    for table in "$@"; do
        if ! echo $mdb_tables | grep -q "\b$table\b"; then
            missing_tables="$missing_tables $table"
        fi
    done

    if [ x"$missing_tables" = x ]; then
        return 0
    else
        missing_tables=${missing_tables:1} # remove leading space
        echo "Table(s) '$missing_tables' missing in file '$file'"
        return 1
    fi
}
