#!/bin/bash

# test _graveyard_file_name
test_graveyard_file_name() {
    local tmp_file=`mktemp`
    function _unique_timestamp() { echo "TIMESTAMP"; }

    # absolute path
    assertEquals "_mnt_opendap_1_file.nc.TIMESTAMP" `_graveyard_file_name /mnt/opendap/1/file.nc`
    assertEquals "_mnt_opendap_1_file.nc_.TIMESTAMP" `_graveyard_file_name /mnt/opendap/1/file.nc/`

    # relative path
    assertEquals "opendap_1_ACORN_file.nc.TIMESTAMP" `_graveyard_file_name opendap/1/ACORN/file.nc`

    # make sure there are no new slashes in the name
    assertFalse "_graveyard_file_name /mnt/opendap/1/file.nc | grep '/'"
}

# test _set_permissions function
test_set_permissions() {
    local tmp_file=`mktemp`
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

# file staged to production, already exists
test_move_to_fs_file_exists_with_force() {
    local src_file=`mktemp`
    echo "new_file_content" > $src_file
    local dest_dir=`mktemp -d`
    local dest_file="$dest_dir/some_file"

    function _graveyard_file_name() { echo "graveyard_file_name"; }

    export GRAVEYARD_DIR=`mktemp -d`

    touch $dest_file # destination file exists

    _move_to_fs_force $src_file $dest_file

    assertTrue "some_file moved to graveyard" "test -f $GRAVEYARD_DIR/graveyard_file_name"
    assertTrue "new file is now in production" "test -f $dest_dir/some_file"

    local new_file_content=`cat $dest_dir/some_file`
    assertEquals "new file has correct content" "$new_file_content" "new_file_content"

    rm -f $dest_dir/some_file; rm -f $src_file; rmdir $dest_dir
    rm -f $GRAVEYARD_DIR/*; rmdir $GRAVEYARD_DIR
    unset _file_error_param
    unset GRAVEYARD_DIR
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

    export GRAVEYARD_DIR=`mktemp -d`
    _collapse_hierarchy_called_param=""
    function _collapse_hierarchy() { _collapse_hierarchy_called_param=$1; }

    _remove_file $prod_file
    return

    local dest_file="$GRAVEYARD_DIR/"`basename $prod_file`

    assertTrue "File moved" "test -f $dest_file"
    assertTrue "_collapse_hierarchy called with directory" $_collapse_hierarchy_called_param $prod_dir

    rm -f $GRAVEYARD_DIR/*; rmdir $GRAVEYARD_DIR
    unset _collapse_hierarchy_called_param
    unset GRAVEYARD_DIR
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

# test get_relative_path
test_get_relative_path() {
    assertEquals "test.nc" `get_relative_path /mnt/opendap/1/test.nc /mnt/opendap/1`
    assertEquals "test.nc" `get_relative_path /mnt/opendap/1/test.nc /mnt/opendap/1/`
    assertEquals "1/test.nc" `get_relative_path /mnt/opendap/1/test.nc /mnt/opendap`
    assertEquals "/mnt/opendap/1/test.nc" `get_relative_path /mnt/opendap/1/test.nc`
}

# test get_uploader_email
test_get_uploader_email() {
    local ftp_log=`mktemp`
    local rsync_log=`mktemp`
    local email_lookup_file=`mktemp`

    export INCOMING_DIR=/var/incoming

    function _log_files_ftp() { echo $ftp_log; }
    function _log_files_rsync() { echo $rsync_log; }
    function _email_lookup_file() { echo $email_lookup_file; }

    cat <<EOF > $ftp_log
Wed Jun 24 12:44:21 2015 [pid 3] [user1] OK UPLOAD: Client "1.1.1.1", "/realtime/slocum_glider/StormBay20150616/unit286_track_24hr.png", 23022 bytes, 111.31Kbyte/sec
Wed Jun 24 12:46:51 2015 [pid 3] CONNECT: Client "1.1.1.4"
Wed Jun 24 12:44:21 2015 [pid 3] [user2] OK UPLOAD: Client "1.1.1.2", "/realtime/slocum_glider/StormBay20150616/unit286_track_48hr.png", 23090 bytes, 114.94Kbyte/sec
Wed Jun 24 12:44:22 2015 [pid 3] [user3] OK UPLOAD: Client "1.1.1.3", "/realtime/slocum_glider/StormBay20150616/unit286_track_mission.png", 23103 bytes, 103.59Kbyte/sec
Wed Jun 24 12:46:51 2015 [pid 3] CONNECT: Client "1.1.1.2"
Wed Jun 24 12:46:51 2015 [pid 3] CONNECT: Client "1.1.1.3"
Wed Jun 24 12:55:07 2015 [pid 3] [user4] FAIL UPLOAD: Client "1.1.1.4", "/AM/pco2_mooring_data_KANGAROO_5.csv", 0.00Kbyte/sec
EOF

    cat <<EOF > $rsync_log
2015/06/24 14:13:05 [8979] recv unknown [2.2.2.2] srs_staging (user5) sst/ghrsst/L3C-1d/index.nc 5683476
2015/06/24 14:13:05 [8979] recv unknown [3.3.3.3] srs_staging (user6) sst/ghrsst/L3C-3d/index.nc 5686584
EOF

    cat <<EOF > $email_lookup_file
user1: user1@email.com
user2: user2@email.com
user3: user3@email.com
user4: user4@email.com
user5: user5@email.com
user6: user6@email.com
EOF
    newaliases -oA$email_lookup_file

    assertEquals "user1@email.com" `get_uploader_email /var/incoming/realtime/slocum_glider/StormBay20150616/unit286_track_24hr.png`
    assertEquals "user2@email.com" `get_uploader_email /var/incoming/realtime/slocum_glider/StormBay20150616/unit286_track_48hr.png`
    assertEquals "user3@email.com" `get_uploader_email /var/incoming/realtime/slocum_glider/StormBay20150616/unit286_track_mission.png`

    get_uploader_email /var/incoming/AM/pco2_mooring_data_KANGAROO_5.csv
    assertFalse "should ignore failed uploads" "get_uploader_email /var/incoming/AM/pco2_mooring_data_KANGAROO_5.csv"

    assertEquals "user5@email.com" `get_uploader_email /var/incoming/sst/ghrsst/L3C-1d/index.nc`
    assertEquals "user6@email.com" `get_uploader_email /var/incoming/sst/ghrsst/L3C-3d/index.nc`

    rm -f $ftp_log $rsync_log $email_lookup_file ${email_lookup_file}.db
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
    source $dir/../../common/email.sh
}

tearDown() {
    true
}

# load and run shUnit2
. /usr/share/shunit2/shunit2
