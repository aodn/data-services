#!/bin/bash

# test hierarchy buildup for given file
test_hierarchy_build() {
    local tmp_input=`mktemp`

    cat <<EOF > $tmp_input
IMOS_OceanCurrent_HV_20150101T000000Z_GSLA_FV02_NRT00_C-20150105T221527Z.nc.gz NRT00 OceanCurrent/GSLA/NRT00/2015
IMOS_OceanCurrent_HV_20130101T000000Z_GSLA_FV02_NRT00_C-20130913T013931Z.nc.gz NRT00 OceanCurrent/GSLA/NRT00/2013

IMOS_OceanCurrent_HV_19950101T000000Z_GSLA_FV02_DM00_C-20130916T010427Z.nc.gz DM00 OceanCurrent/GSLA/DM00/1995
IMOS_OceanCurrent_HV_20140101T000000Z_GSLA_FV02_DM00_C-20150111T224141Z.nc.gz DM00 OceanCurrent/GSLA/DM00/2014

IMOS_OceanCurrent_HV_1993_C-20150521T030649Z.nc.gz DM00/yearfiles OceanCurrent/GSLA/DM00/yearfiles
EOF

    local line
    IFS=$'\n'
    for line in `cat $tmp_input`; do
        unset IFS
        line=`echo $line | tr -s " "` # squeeze spaces
        local file=`echo $line | cut -d' ' -f1`
        local expected_type=`echo $line | cut -d' ' -f2`
        local expected_hierarchy=`echo $line | cut -d' ' -f3`

        local type=`get_type $file`
        local hierarchy=`get_hierarchy $file $type`
        local basename_file=`basename $file`

        assertEquals "type $file"      "$expected_type"            "$type"
        assertEquals "hierarchy $file" "$expected_hierarchy/$file" "$hierarchy"
    done

    rm -f $tmp_input
}

# unknown types
test_unknown_type() {
    local file="IMOS_OceanCurrent_HV_20150101T000000Z_GSLA_FV02_C-20150105T221527Z.nc.gz"
    local type=`get_type $file`
    assertEquals "type $file" "" "$type"
}

test_match_regex() {
    local good_files bad_files
    good_files="$good_files IMOS_OceanCurrent_HV_20150101T000000Z_GSLA_FV02_NRT00_C-20150105T221527Z.nc.gz"
    good_files="$good_files IMOS_OceanCurrent_HV_20130101T000000Z_GSLA_FV02_NRT00_C-20130913T013931Z.nc.gz"
    good_files="$good_files IMOS_OceanCurrent_HV_19950101T000000Z_GSLA_FV02_DM00_C-20130916T010427Z.nc.gz"
    good_files="$good_files IMOS_OceanCurrent_HV_20140101T000000Z_GSLA_FV02_DM00_C-20150111T224141Z.nc.gz"
    good_files="$good_files IMOS_OceanCurrent_HV_1993_C-20150521T030649Z.nc.gz"

    bad_files="$bad_files IMOS_OceanCurrent_HV_20150101T000000Z_GSLA_FV02_NRT_C-20150105T221527Z.nc.gz"
    bad_files="$bad_files IMOS_OceanCurrent_HV_20150101T000000Z_GSLA_FV02_NRT_C.nc.gz"
    bad_files="$bad_files prefix.IMOS_OceanCurrent_HV_20150101T000000Z_GSLA_FV02_NRT00_C-20150105T221527Z.nc.gz"

    local file
    for file in $good_files; do
        regex_filter $file
        assertEquals "regex $file" 0 $?
    done

    local file
    for file in $bad_files; do
        regex_filter $file
        assertNotEquals "regex $file" 0 $?
    done
}

test_get_previous_files() {
    function s3_ls() {
        echo "IMOS_OceanCurrent_HV_20130101T000000Z_GSLA_FV02_NRT00_C-20130913T013931Z.nc.gz"
        echo "IMOS_OceanCurrent_HV_20130102T000000Z_GSLA_FV02_NRT00_C-20130913T014016Z.nc.gz" # previous version
        echo "IMOS_OceanCurrent_HV_20130102T000000Z_GSLA_FV02_NRT00_C-20140912T024016Z.nc.gz" # previous version
        echo "IMOS_OceanCurrent_HV_20130102T000000Z_GSLA_FV02_NRT00_C-20160201T094111Z.nc.gz" # current version
        echo "IMOS_OceanCurrent_HV_20130103T000000Z_GSLA_FV02_NRT00_C-20130913T014646Z.nc.gz"
        echo "IMOS_OceanCurrent_HV_20130104T000000Z_GSLA_FV02_NRT00_C-20130913T014732Z.nc.gz"
        echo "IMOS_OceanCurrent_HV_20130105T000000Z_GSLA_FV02_NRT00_C-20130913T014818Z.nc.gz"
        echo "IMOS_OceanCurrent_HV_20130106T000000Z_GSLA_FV02_NRT00_C-20130913T014903Z.nc.gz"
        echo "IMOS_OceanCurrent_HV_20130107T000000Z_GSLA_FV02_NRT00_C-20130913T014949Z.nc.gz"
    }

    local previous_versions=`get_previous_versions IMOS/OceanCurrent/GSLA/NRT00/2013/IMOS_OceanCurrent_HV_20130102T000000Z_GSLA_FV02_NRT00_C-20160201T094111Z.nc.gz | xargs`
    local expected_previous_versions="IMOS/OceanCurrent/GSLA/NRT00/2013/IMOS_OceanCurrent_HV_20130102T000000Z_GSLA_FV02_NRT00_C-20130913T014016Z.nc.gz IMOS/OceanCurrent/GSLA/NRT00/2013/IMOS_OceanCurrent_HV_20130102T000000Z_GSLA_FV02_NRT00_C-20140912T024016Z.nc.gz"

    assertEquals "previous versions" "$expected_previous_versions" "$previous_versions"
}

test_get_previous_files_yearly_files() {
    # test also for yearly files
    function s3_ls() {
        echo "IMOS_OceanCurrent_HV_1994_C-20150521T031623Z.nc.gz"
        echo "IMOS_OceanCurrent_HV_1995_C-20150521T032432Z.nc.gz"
        echo "IMOS_OceanCurrent_HV_1996_C-20140521T033049Z.nc.gz" # previous version
        echo "IMOS_OceanCurrent_HV_1996_C-20150521T033049Z.nc.gz" # previous version
        echo "IMOS_OceanCurrent_HV_1996_C-20160201T033049Z.nc.gz" # previous version
        echo "IMOS_OceanCurrent_HV_1997_C-20150521T033755Z.nc.gz"
        echo "IMOS_OceanCurrent_HV_1998_C-20150521T034357Z.nc.gz"
        echo "IMOS_OceanCurrent_HV_1999_C-20150521T034853Z.nc.gz"
        echo "IMOS_OceanCurrent_HV_2000_C-20150521T035421Z.nc.gz"
        echo "IMOS_OceanCurrent_HV_2001_C-20150521T035914Z.nc.gz"
    }

    local previous_versions=`get_previous_versions IMOS/OceanCurrent/GSLA/DM00/yearfiles/IMOS_OceanCurrent_HV_1996_C-20160202T033049Z.nc.gz | xargs`
    local expected_previous_versions="IMOS/OceanCurrent/GSLA/DM00/yearfiles/IMOS_OceanCurrent_HV_1996_C-20140521T033049Z.nc.gz IMOS/OceanCurrent/GSLA/DM00/yearfiles/IMOS_OceanCurrent_HV_1996_C-20150521T033049Z.nc.gz IMOS/OceanCurrent/GSLA/DM00/yearfiles/IMOS_OceanCurrent_HV_1996_C-20160201T033049Z.nc.gz"

    assertEquals "previous versions yearly files" "$expected_previous_versions" "$previous_versions"
}

test_get_timestamp() {
    assertEquals "get timestamp" "2013-09-13T01:39:31" "`get_timestamp IMOS_OceanCurrent_HV_20130101T000000Z_GSLA_FV02_NRT00_C-20130913T013931Z.nc.gz`"
    assertEquals "get timestamp" "2013-09-13T01:49:03" "`get_timestamp IMOS_OceanCurrent_HV_20130106T000000Z_GSLA_FV02_NRT00_C-20130913T014903Z.nc.gz`"

    assertEquals "get timestamp yearly" "2015-05-21T03:59:14" "`get_timestamp IMOS_OceanCurrent_HV_2001_C-20150521T035914Z.nc.gz`"
}

##################
# SETUP/TEARDOWN #
##################

oneTimeSetUp() {
    INCOMING_HANDLER=`dirname $0`/incoming_handler.sh
}

oneTimeTearDown() {
    true
}

setUp() {
    source $INCOMING_HANDLER
}

tearDown() {
    true
}

# load and run shUnit2
. /usr/share/shunit2/shunit2
