#!/bin/bash

# test _graveyard_file_name
test_graveyard_file_name() {
    local tmp_file=`mktemp`
    export TRANSACTION_ID="TIMESTAMP"

    # absolute path
    assertEquals "_mnt_opendap_1_file.nc.TIMESTAMP" `_graveyard_file_name /mnt/opendap/1/file.nc`
    assertEquals "_mnt_opendap_1_file.nc_.TIMESTAMP" `_graveyard_file_name /mnt/opendap/1/file.nc/`

    # relative path
    assertEquals "opendap_1_ACORN_file.nc.TIMESTAMP" `_graveyard_file_name opendap/1/ACORN/file.nc`

    # make sure there are no new slashes in the name
    assertFalse "_graveyard_file_name /mnt/opendap/1/file.nc | grep '/'"
    unset TRANSACTION_ID
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

    export INCOMING_FILE=$src_file
    _file_error_param=""
    function _file_error() { _file_error_param=$1; }

    _move_to_fs $src_file $dest_file

    assertEquals "file_error called with source file" $_file_error_param $src_file
    unset INCOMING_FILE

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
Wed Jun 24 12:44:22 2015 [pid 3] [user5] OK UPLOAD: Client "1.1.1.3", "/ANFOG/realtime/slocum_glider/StormBay20150616/unit287_track_mission.png", 23103 bytes, 103.59Kbyte/sec
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

    assertEquals "user1@email.com" `get_uploader_email /var/incoming/ANFOG/realtime/slocum_glider/StormBay20150616/unit286_track_24hr.png`
    assertEquals "user2@email.com" `get_uploader_email /var/incoming/ANFOG/realtime/slocum_glider/StormBay20150616/unit286_track_48hr.png`
    assertEquals "user3@email.com" `get_uploader_email /var/incoming/ANFOG/realtime/slocum_glider/StormBay20150616/unit286_track_mission.png`
    assertEquals "user5@email.com" `get_uploader_email /var/incoming/ANFOG/realtime/slocum_glider/StormBay20150616/unit287_track_mission.png`

    assertFalse "should ignore failed uploads" "get_uploader_email /var/incoming/AM/pco2_mooring_data_KANGAROO_5.csv"

    assertEquals "user5@email.com" `get_uploader_email /var/incoming/sst/ghrsst/L3C-1d/index.nc`
    assertEquals "user6@email.com" `get_uploader_email /var/incoming/sst/ghrsst/L3C-3d/index.nc`

    rm -f $ftp_log $rsync_log $email_lookup_file ${email_lookup_file}.db
}

# test rsync log parsing functions
test_sync_rsync() {
    local rsync_itemized=`mktemp`

    cat <<EOF > $rsync_itemized
*deleting   c
.d..t...... ./
>f.st...... a
>f+++++++++ b
EOF

    local rsync_deletions=`mktemp`
    local rsync_deletions_expected=`mktemp`
    echo "c" >> $rsync_deletions_expected
    get_rsync_deletions $rsync_itemized > $rsync_deletions
    assertTrue "rsync deletions" "cmp -s $rsync_deletions $rsync_deletions_expected"

    local rsync_additions=`mktemp`
    local rsync_additions_expected=`mktemp`
    echo "a" >> $rsync_additions_expected
    echo "b" >> $rsync_additions_expected
    get_rsync_additions $rsync_itemized > $rsync_additions
    assertTrue "rsync additions" "cmp -s $rsync_additions $rsync_additions_expected"

    rm -f $rsync_itemized \
        $rsync_deletions $rsync_deletions_expected \
        $rsync_additions $rsync_deletions_expected
}


# test lftp synchronization functions
test_lftp_sync() {
    local lftp_log=`mktemp`

    # log generated by running:
    # lftp -e "mirror -e --parallel=10 --log=/tmp/lftp.log /ifremer/argo/dac /tmp/argo/dac; quit" ftp.ifremer.fr

    cat <<EOF > $lftp_log
get -O /tmp/argo/dac/kma/2900170/profiles ftp://ftp.ifremer.fr/ifremer/argo/dac/kma/2900170/profiles/D2900170_007.nc
chmod 644 file:/tmp/argo/dac/csio/2900313/2900313_meta.nc
rm file:/tmp/argo/dac/nmdis/2901615/2901615_prof.nc.should_delete
chmod 644 file:/tmp/argo/dac/csio/2900313/2900313_prof.nc
get -O /tmp/argo/dac/kma/2900170/profiles ftp://ftp.ifremer.fr/ifremer/argo/dac/kma/2900170/profiles/D2900170_006.nc
get -O /tmp/argo/dac/meds/2900193 ftp://ftp.ifremer.fr/ifremer/argo/dac/meds/2900193/2900193_tech.nc
chmod 644 file:/tmp/argo/dac/csio/2900313/2900313_tech.nc
chmod 755 file:/tmp/argo/dac/csio/2900313/profiles
mkdir file:/tmp/argo/dac/csio/2900322
rm file:/tmp/argo/dac/nmdis/2901615/2901615_prof.nc.should_delete2
get -O /tmp/argo/dac/csio/2900322 ftp://ftp.ifremer.fr/ifremer/argo/dac/csio/2900322/2900322_Rtraj.nc
get -O /tmp/argo/dac/kordi/2900202 ftp://ftp.ifremer.fr/ifremer/argo/dac/kordi/2900202/2900202_tech.nc
EOF

    local lftp_expected_additions=`mktemp`
    cat <<EOF > $lftp_expected_additions
kma/2900170/profiles/D2900170_007.nc
kma/2900170/profiles/D2900170_006.nc
meds/2900193/2900193_tech.nc
csio/2900322/2900322_Rtraj.nc
kordi/2900202/2900202_tech.nc
EOF

    local lftp_expected_deletions=`mktemp`
    cat <<EOF > $lftp_expected_deletions
nmdis/2901615/2901615_prof.nc.should_delete
nmdis/2901615/2901615_prof.nc.should_delete2
EOF

    local lftp_additions=`mktemp`
    local lftp_deletions=`mktemp`

    get_lftp_additions $lftp_log "/tmp/argo/dac" > $lftp_additions
    get_lftp_deletions $lftp_log "/tmp/argo/dac" > $lftp_deletions

    assertTrue "cmp -s $lftp_additions $lftp_expected_additions"
    assertTrue "cmp -s $lftp_deletions $lftp_expected_deletions"

    rm -f $lftp_log $lftp_additions $lftp_deletions
}

#################################
# unit test for netcdf-utils.sh #
#################################


# test_nc_has_variable
test_nc_has_variable() {
    assertTrue "NetCDF file has TIME variable" "nc_has_variable $NETCDF_FILE_TEST TIME"
    assertTrue "NetCDF file has history dimension" "nc_has_variable $NETCDF_FILE_TEST history"
}

# test_nc_has_variable_att
test_nc_has_variable_att() {
    assertTrue "NetCDF has unit att for the TIME variable" "nc_has_variable_att $NETCDF_FILE_TEST TIME units"
}

# test_nc_get_variable_att
test_nc_get_variable_att() {
    assertEquals "NetCDF get unit att for the TIME variable" "days since 1950-01-01 00:00:00Z" "`nc_get_variable_att $NETCDF_FILE_TEST TIME units`"
    assertEquals "NetCDF get _FillValue att for the TIME variable" "-9999" "`nc_get_variable_att $NETCDF_FILE_TEST TIME _FillValue`"
}

# test_nc_get_variable_values
test_nc_get_variable_values() {
    local variable_values=`mktemp`
    cat <<EOF > $variable_values
-41.268002
-41.268002
-41.267899
EOF
    assertEquals "NetCDF get first 3 LATITUDE values" "`cat $variable_values`" "`nc_get_variable_values $NETCDF_FILE_TEST LATITUDE | head -3`"
    rm $variable_values
}

# test_nc_get_variable_min
test_nc_get_variable_min() {
    assertEquals "NetCDF get min LATITUDE value" "-41.369400" "`nc_get_variable_min $NETCDF_FILE_TEST LATITUDE`"
}

# test_nc_get_variable_max
test_nc_get_variable_max() {
    assertEquals "NetCDF get max LATITUDE value" "-37.984299" "`nc_get_variable_max $NETCDF_FILE_TEST LATITUDE`"
}

# test_nc_get_time_min
test_nc_get_time_min() {
    assertEquals "NetCDF get TIME min values" "2015-01-05T00:01:59Z" "`nc_get_time_min $NETCDF_FILE_TEST`"
}

# test_nc_get_time_max
test_nc_get_time_max() {
    assertEquals "NetCDF get TIME max values" "2015-01-05T23:51:59Z" "`nc_get_time_max $NETCDF_FILE_TEST`"
}

# test_nc_get_gatt_value
test_nc_get_gatt_value() {
    local attname
    local keywords_value=`mktemp`

    # empty attribute
    attname=abstract
    assertEquals "NetCDF get abstract gatt value" "" "`nc_get_gatt_value $NETCDF_FILE_TEST $attname`"

    # multiline attribute
    cat <<EOF > $keywords_value
Oceans>Ocean Temperature>Sea Surface \n", \
"Temperature,Oceans>Ocean Winds>Surface Winds,Atmosphere>Atmospheric \n", \
"Pressure>Atmospheric \n", \
"Pressure,Atmosphere>Precipitation>Precipitation Rate,Atmosphere>Atmospheric \n", \
"Water Vapor>Humidity,Atmosphere>Atmospheric Winds>Surface \n", \
"Winds,Atmosphere>Atmospheric Temperature>Air Temperature,Atmosphere>Atmospheric \n", \
"Radiation>Shortwave Radiation,Atmosphere>Atmospheric Radiation>Longwave \n", \
"Radiation,Atmosphere>Atmospheric Radiation>Net Radiation,Atmosphere>Atmospheric \n", \
"Radiation>Radiative Flux,Oceans>Ocean Heat Budget>Heat Flux,Oceans>Ocean \n", \
"Heat Budget>Longwave Radiation,Oceans>Ocean Heat Budget>Shortwave Radiation
EOF

    attname=keywords
    assertEquals "NetCDF get keywords gatt value" "`cat $keywords_value`" "`nc_get_gatt_value $NETCDF_FILE_TEST $attname`"
    rm $keywords_value

    # lastr attribute
    attname=voyage_number
    assertEquals "NetCDF get voyage_numer gatt value" "" "`nc_get_gatt_value $NETCDF_FILE_TEST $attname`"
}

# test__nc_get_time_values
test__nc_get_time_values() {
    local time_values=`mktemp`

    cat <<EOF > $time_values
"2015-01-05 00:01:59.999993", "2015-01-05 00:07:0.000015", "2015-01-05 00:11:59.999997", "2015-01-05 00:17:0.000020", "2015-01-05 00:22:0.000002", "2015-01-05 00:26:59.999984", "2015-01-05 00:32:0.000006", "2015-01-05 00:36:59.999988", "2015-01-05 00:42:0.000011", "2015-01-05 00:46:59.999993", "2015-01-05 00:52:0.000015", "2015-01-05 00:56:59.999997", "2015-01-05 01:02:0.000020", "2015-01-05 01:07:0.000002", "2015-01-05 01:11:59.999984", "2015-01-05 01:17:0.000006", "2015-01-05 01:21:59.999988", "2015-01-05 01:27:0.000011", "2015-01-05 01:31:59.999993", "2015-01-05 01:37:0.000015", "2015-01-05 01:47:0.000020", "2015-01-05 01:52:0.000002", "2015-01-05 02:02:0.000006", "2015-01-05 02:06:59.999988", "2015-01-05 02:12:0.000011", "2015-01-05 02:22:0.000015", "2015-01-05 02:26:59.999997", "2015-01-05 02:37:0.000002", "2015-01-05 02:41:59.999984", "2015-01-05 03:22:0.000002", "2015-01-05 03:36:59.999988", "2015-01-05 04:07:0.000002", "2015-01-05 04:11:59.999984", "2015-01-05 04:47:0.000020", "2015-01-05 04:52:0.000002", "2015-01-05 05:02:0.000006", "2015-01-05 05:12:0.000011", "2015-01-05 05:16:59.999993", "2015-01-05 05:22:0.000015", "2015-01-05 05:26:59.999997", "2015-01-05 05:32:0.000020", "2015-01-05 05:37:0.000002", "2015-01-05 05:41:59.999984", "2015-01-05 05:47:0.000006", "2015-01-05 05:51:59.999988", "2015-01-05 05:57:0.000011", "2015-01-05 06:01:59.999993", "2015-01-05 06:11:59.999997", "2015-01-05 06:17:0.000020", "2015-01-05 06:22:0.000002", "2015-01-05 06:26:59.999984", "2015-01-05 06:32:0.000006", "2015-01-05 06:36:59.999988", "2015-01-05 06:42:0.000011", "2015-01-05 06:46:59.999993", "2015-01-05 06:52:0.000015", "2015-01-05 06:56:59.999997", "2015-01-05 07:02:0.000020", "2015-01-05 07:07:0.000002", "2015-01-05 07:11:59.999984", "2015-01-05 07:17:0.000006", "2015-01-05 07:21:59.999988", "2015-01-05 07:27:0.000011", "2015-01-05 07:31:59.999993", "2015-01-05 07:37:0.000015", "2015-01-05 07:41:59.999997", "2015-01-05 07:47:0.000020", "2015-01-05 07:52:0.000002", "2015-01-05 07:56:59.999984", "2015-01-05 08:02:0.000006", "2015-01-05 08:06:59.999988", "2015-01-05 08:12:0.000011", "2015-01-05 08:16:59.999993", "2015-01-05 08:22:0.000015", "2015-01-05 08:26:59.999997", "2015-01-05 08:32:0.000020", "2015-01-05 08:37:0.000002", "2015-01-05 08:41:59.999984", "2015-01-05 08:47:0.000006", "2015-01-05 08:51:59.999988", "2015-01-05 08:57:0.000011", "2015-01-05 09:01:59.999993", "2015-01-05 09:07:0.000015", "2015-01-05 09:11:59.999997", "2015-01-05 09:17:0.000020", "2015-01-05 09:22:0.000002", "2015-01-05 09:26:59.999984", "2015-01-05 09:32:0.000006", "2015-01-05 09:36:59.999988", "2015-01-05 09:42:0.000011", "2015-01-05 09:46:59.999993", "2015-01-05 09:52:0.000015", "2015-01-05 09:56:59.999997", "2015-01-05 10:02:0.000020", "2015-01-05 10:07:0.000002", "2015-01-05 10:11:59.999984", "2015-01-05 10:17:0.000006", "2015-01-05 10:21:59.999988", "2015-01-05 10:27:0.000011", "2015-01-05 10:31:59.999993", "2015-01-05 10:37:0.000015", "2015-01-05 10:41:59.999997", "2015-01-05 10:47:0.000020", "2015-01-05 10:52:0.000002", "2015-01-05 10:56:59.999984", "2015-01-05 11:02:0.000006", "2015-01-05 11:06:59.999988", "2015-01-05 11:12:0.000011", "2015-01-05 11:16:59.999993", "2015-01-05 11:22:0.000015", "2015-01-05 11:26:59.999997", "2015-01-05 11:32:0.000020", "2015-01-05 11:37:0.000002", "2015-01-05 11:41:59.999984", "2015-01-05 11:47:0.000006", "2015-01-05 11:51:59.999988", "2015-01-05 11:57:0.000011", "2015-01-05 12:01:59.999993", "2015-01-05 12:07:0.000015", "2015-01-05 12:11:59.999997", "2015-01-05 12:17:0.000020", "2015-01-05 12:22:0.000002", "2015-01-05 12:26:59.999984", "2015-01-05 12:32:0.000006", "2015-01-05 12:36:59.999988", "2015-01-05 12:42:0.000011", "2015-01-05 12:46:59.999993", "2015-01-05 12:52:0.000015", "2015-01-05 13:02:0.000020", "2015-01-05 13:07:0.000002", "2015-01-05 13:11:59.999984", "2015-01-05 13:17:0.000006", "2015-01-05 13:21:59.999988", "2015-01-05 13:27:0.000011", "2015-01-05 13:31:59.999993", "2015-01-05 13:37:0.000015", "2015-01-05 13:41:59.999997", "2015-01-05 13:47:0.000020", "2015-01-05 13:52:0.000002", "2015-01-05 13:56:59.999984", "2015-01-05 14:02:0.000006", "2015-01-05 14:06:59.999988", "2015-01-05 14:12:0.000011", "2015-01-05 14:16:59.999993", "2015-01-05 14:22:0.000015", "2015-01-05 14:26:59.999997", "2015-01-05 14:32:0.000020", "2015-01-05 14:37:0.000002", "2015-01-05 14:41:59.999984", "2015-01-05 14:47:0.000006", "2015-01-05 14:51:59.999988", "2015-01-05 14:57:0.000011", "2015-01-05 15:01:59.999993", "2015-01-05 15:07:0.000015", "2015-01-05 15:11:59.999997", "2015-01-05 15:17:0.000020", "2015-01-05 15:22:0.000002", "2015-01-05 15:26:59.999984", "2015-01-05 15:32:0.000006", "2015-01-05 15:36:59.999988", "2015-01-05 15:42:0.000011", "2015-01-05 15:46:59.999993", "2015-01-05 15:52:0.000015", "2015-01-05 15:56:59.999997", "2015-01-05 16:02:0.000020", "2015-01-05 16:07:0.000002", "2015-01-05 16:11:59.999984", "2015-01-05 16:17:0.000006", "2015-01-05 16:21:59.999988", "2015-01-05 16:27:0.000011", "2015-01-05 16:31:59.999993", "2015-01-05 16:37:0.000015", "2015-01-05 16:41:59.999997", "2015-01-05 16:47:0.000020", "2015-01-05 16:52:0.000002", "2015-01-05 16:56:59.999984", "2015-01-05 17:02:0.000006", "2015-01-05 17:06:59.999988", "2015-01-05 17:12:0.000011", "2015-01-05 17:16:59.999993", "2015-01-05 17:22:0.000015", "2015-01-05 17:26:59.999997", "2015-01-05 17:32:0.000020", "2015-01-05 17:37:0.000002", "2015-01-05 17:41:59.999984", "2015-01-05 17:47:0.000006", "2015-01-05 17:51:59.999988", "2015-01-05 17:57:0.000011", "2015-01-05 18:01:59.999993", "2015-01-05 18:07:0.000015", "2015-01-05 18:11:59.999997", "2015-01-05 18:17:0.000020", "2015-01-05 18:22:0.000002", "2015-01-05 18:26:59.999984", "2015-01-05 18:32:0.000006", "2015-01-05 18:36:59.999988", "2015-01-05 18:42:0.000011", "2015-01-05 18:46:59.999993", "2015-01-05 18:52:0.000015", "2015-01-05 18:56:59.999997", "2015-01-05 19:02:0.000020", "2015-01-05 19:07:0.000002", "2015-01-05 19:11:59.999984", "2015-01-05 19:17:0.000006", "2015-01-05 19:21:59.999988", "2015-01-05 19:27:0.000011", "2015-01-05 19:31:59.999993", "2015-01-05 19:37:0.000015", "2015-01-05 19:41:59.999997", "2015-01-05 19:47:0.000020", "2015-01-05 19:52:0.000002", "2015-01-05 19:56:59.999984", "2015-01-05 20:02:0.000006", "2015-01-05 20:06:59.999988", "2015-01-05 20:12:0.000011", "2015-01-05 20:16:59.999993", "2015-01-05 20:22:0.000015", "2015-01-05 20:26:59.999997", "2015-01-05 20:32:0.000020", "2015-01-05 20:37:0.000002", "2015-01-05 20:41:59.999984", "2015-01-05 20:47:0.000006", "2015-01-05 20:51:59.999988", "2015-01-05 20:57:0.000011", "2015-01-05 21:01:59.999993", "2015-01-05 21:07:0.000015", "2015-01-05 21:11:59.999997", "2015-01-05 21:17:0.000020", "2015-01-05 21:22:0.000002", "2015-01-05 21:26:59.999984", "2015-01-05 21:32:0.000006", "2015-01-05 21:36:59.999988", "2015-01-05 21:42:0.000011", "2015-01-05 21:46:59.999993", "2015-01-05 21:52:0.000015", "2015-01-05 21:56:59.999997", "2015-01-05 22:02:0.000020", "2015-01-05 22:07:0.000002", "2015-01-05 22:11:59.999984", "2015-01-05 22:17:0.000006", "2015-01-05 22:21:59.999988", "2015-01-05 22:27:0.000011", "2015-01-05 22:31:59.999993", "2015-01-05 22:37:0.000015", "2015-01-05 22:41:59.999997", "2015-01-05 22:47:0.000020", "2015-01-05 22:52:0.000002", "2015-01-05 22:56:59.999984", "2015-01-05 23:02:0.000006", "2015-01-05 23:06:59.999988", "2015-01-05 23:12:0.000011", "2015-01-05 23:16:59.999993", "2015-01-05 23:22:0.000015", "2015-01-05 23:26:59.999997", "2015-01-05 23:32:0.000020", "2015-01-05 23:37:0.000002", "2015-01-05 23:41:59.999984", "2015-01-05 23:47:0.000006", "2015-01-05 23:51:59.999988"
EOF

    assertEquals "NetCDF get time values" "`cat $time_values`" "`_nc_get_time_values $NETCDF_FILE_TEST`"
    rm $time_values
}

# test_nc_del_empty_att
test_nc_del_empty_att() {
    local modified_nc_file=`mktemp`

    cp $NETCDF_FILE_TEST $modified_nc_file
    nc_del_empty_att $modified_nc_file

    assertTrue "NetCDF has gatt abstract" "nc_has_gatt $NETCDF_FILE_TEST abstract"
    assertTrue "NetCDF has gatt voyage_number" "nc_has_gatt $NETCDF_FILE_TEST voyage_number"

    assertFalse "NetCDF has empty gatt abstract removed" "nc_has_gatt $modified_nc_file abstract"
    assertFalse "NetCDF has empty gatt voyage_number removed" "nc_has_gatt $modified_nc_file voyage_number"
    rm $modified_nc_file
}

# test_nc_get_variable_type
test_nc_get_variable_type() {
      assertEquals "NetCDF get time types" "d" "`nc_get_variable_type $NETCDF_FILE_TEST TIME`"
      assertEquals "NetCDF get latitude types" "f" "`nc_get_variable_type $NETCDF_FILE_TEST LATITUDE`"
      assertEquals "NetCDF get longitude types" "s" "`nc_get_variable_type $NETCDF_FILE_TEST WIND_FLAG`"
      assertEquals "NetCDF get history types" "c" "`nc_get_variable_type $NETCDF_FILE_TEST history`"
}

##################
# SETUP/TEARDOWN #
##################

oneTimeSetUp() {
    function sudo() { "$@"; }
    function log_info() { true; }
    function log_error() { true; }
    NETCDF_FILE_TEST=`dirname $0`/test.nc
}

oneTimeTearDown() {
    true
}

setUp() {
    local dir=`dirname $0`
    source $dir/../../common/util.sh
    source $dir/../../common/email.sh
    source $dir/../../common/sync.sh
    source $dir/../../common/netcdf-utils.sh
}

tearDown() {
    true
}

# load and run shUnit2
. /usr/share/shunit2/shunit2
