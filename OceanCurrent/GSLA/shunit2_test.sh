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
