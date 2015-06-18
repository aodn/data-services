#!/bin/bash

# test _set_permissions function
test_set_permissions() {
    local tmp_file=`mktemp`
    alias sudo="" # mock sudo
    _set_permissions $tmp_file

    local file_perms=`stat --format=%a $tmp_file`

    assertEquals "$file_perms" "444"
}

# file staged to production, already exists
test_move_to_fs_file_exists() {
    local src_file=`mktemp`
    local dest_dir=`mktemp -d`
    local dest_file="$dest_dir/some_file"

    touch $dest_file # destination file exists

    _file_error_param=""
    function file_error() { _file_error_param=$1; }

    _move_to_fs $src_file $dest_file

    assertEquals "file_error called with source file" $_file_error_param $src_file

    unset _file_error_param
    rm -f $dest_dir/some_file; rm -f $src_file; rmdir $dest_dir
}

# file staged to production, didn't exist before
test_move_to_fs_new_file() {
    local src_file=`mktemp`
    local dest_dir=`mktemp -d`
    local dest_file="$dest_dir/some_file"

    _set_permissions_called_param=0
    function _set_permissions() { _set_permissions_called=$1; }

    _move_to_fs $src_file $dest_file

    assertTrue "File copied" "test -f $dest_file"
    assertEquals "_set_permissions called with source file" $_set_permissions_called $src_file

    unset _set_permissions_called
    rm -f $dest_dir/some_file; rmdir $dest_dir
}

# test the removal of file in production
test_remove_file_when_exists() {
    local prod_file=`mktemp`
    local prod_dir=`dirname $prod_file`

    export GRAVEYARD=`mktemp -d`
    _collapse_hierarchy_called_param=""
    function _collapse_hierarchy() { _collapse_hierarchy_called_param=$1; }

    _remove_file $prod_file
    return

    local dest_file="$GRAVEYARD/"`basename $prod_file`

    assertTrue "File moved" "test -f $dest_file"
    assertTrue "_collapse_hierarchy called with directory" $_collapse_hierarchy_called_param $prod_dir

    unset GRAVEYARD
    unset _collapse_hierarchy_called_param
    rm -f $GRAVEYARD/*; rmdir $GRAVEYARD
}

# test the removal of file in production
test_remove_file_when_is_directory() {
    local prod_dir=`mktemp -d`

    _remove_file $prod_dir
    local -i retval=$?

    assertEquals "_remove_file fails" $retval 1
    assertTrue "Does not remove directory" "test -d $prod_dir"

    rmdir $prod_dir
}

# test _collapse_hierarchy function
test_collapse_hierarchy() {
    local prod_dir=`mktemp -d`
    mkdir -p $prod_dir/1/2/3/4
    touch $prod_dir/1/2/some_file

    _collapse_hierarchy $prod_dir/1/2/3/4
    local -i retval=$?

    # those directories will be deleted
    assertFalse "Removes empty directories" "test -d $prod_dir/1/2/3/4"
    assertFalse "Removes empty directories" "test -d $prod_dir/1/2/3"

    assertTrue "Stops at a directory with a file" "test -d $prod_dir/1/2"
    assertTrue "Stops at a directory with a file" "test -d $prod_dir/1"
    assertTrue "Stops at a directory with a file" "test -d $prod_dir"
    assertTrue "Stops at a directory with a file" "test -f $prod_dir/1/2/some_file"

    rm -f $prod_dir/1/2/some_file;
    rmdir $prod_dir/1/2
    rmdir $prod_dir/1
    rmdir $prod_dir
}

##################
# SETUP/TEARDOWN #
##################

oneTimeSetUp() {
    function sudo() { "$@"; }
    function log_info() { true; }
    function log_error() { true; }
}

oneTimeTearDown() {
    true
}

setUp() {
    local dir=`dirname $0`
    source $dir/../../common/util.sh
}

tearDown() {
    true
}

# load and run shUnit2
. /usr/share/shunit2/shunit2
