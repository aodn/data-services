#!/bin/bash

######################
# CORE FUNCTIONALITY #
######################
# test hierarchy buildup for given file
test_hierarchy_build_for_file_radial() {
	source $BUILD_DIR_HIERARCHY_NO_MAIN
    local dir_hierarchy=`build_hierarchy_for_file IMOS_ACORN_RV_20140710T113000Z_GUI_FV00_radial.nc`

    assertEquals "building hierarchy from file" $dir_hierarchy "radial/GUI/2014/07/10"
}

# test hierarchy buildup for given file
test_hierarchy_build_for_file_vector() {
	source $BUILD_DIR_HIERARCHY_NO_MAIN
    local dir_hierarchy=`build_hierarchy_for_file IMOS_ACORN_V_20140804T010000Z_TURQ_FV00_sea-state.nc`

    assertEquals "building hierarchy from file" $dir_hierarchy "vector/TURQ/2014/08/04"
}

# test moving file to directory buildup for given file
test_move_file() {
	source $BUILD_DIR_HIERARCHY_NO_MAIN

    local in_dir=`mktemp -d`
    local out_dir=`mktemp -d`

    touch $in_dir/IMOS_ACORN_RV_20140709T005500Z_FRE_FV00_radial.nc
    chmod 666 $in_dir/IMOS_ACORN_RV_20140709T005500Z_FRE_FV00_radial.nc

    move_file_to_hierarchy $in_dir/IMOS_ACORN_RV_20140709T005500Z_FRE_FV00_radial.nc $out_dir

    assertTrue 'file moved' "[ -f '${out_dir}/radial/FRE/2014/07/09/IMOS_ACORN_RV_20140709T005500Z_FRE_FV00_radial.nc' ]"

    # safely cleanup out_dir
    rm $out_dir/radial/FRE/2014/07/09/IMOS_ACORN_RV_20140709T005500Z_FRE_FV00_radial.nc

    # remove hierarchy safely
    find $out_dir -type d -empty | tac | xargs -L1 rmdir

    rmdir $in_dir
}

# test permissions on target file and directories
test_permissions_after_move() {
	source $BUILD_DIR_HIERARCHY_NO_MAIN

    local in_dir=`mktemp -d`
    local out_dir=`mktemp -d`

    touch $in_dir/IMOS_ACORN_RV_20130709T005500Z_CWI_FV00_radial.nc
    chmod 666 $in_dir/IMOS_ACORN_RV_20130709T005500Z_CWI_FV00_radial.nc

    # change permissions on a directory we know is going to be created
    mkdir -p ${out_dir}/radial/CWI/2013/07/09
    chmod 777 ${out_dir}/radial/CWI/2013/07/09
    chmod 777 ${out_dir}/radial/CWI/2013/07
    chmod 777 ${out_dir}/radial/CWI/2013
    chmod 777 ${out_dir}/radial/CWI

    move_file_to_hierarchy $in_dir/IMOS_ACORN_RV_20130709T005500Z_CWI_FV00_radial.nc $out_dir

    assertEquals 'correct permissions' '664' `stat -c "%a" ${out_dir}/radial/CWI/2013/07/09/IMOS_ACORN_RV_20130709T005500Z_CWI_FV00_radial.nc`

    assertEquals 'correct permissions on directories' '775' `stat -c "%a" ${out_dir}/radial/CWI/2013/07/09`
    assertEquals 'correct permissions on directories' '775' `stat -c "%a" ${out_dir}/radial/CWI/2013/07`
    assertEquals 'correct permissions on directories' '775' `stat -c "%a" ${out_dir}/radial/CWI/2013`
    assertEquals 'correct permissions on directories' '775' `stat -c "%a" ${out_dir}/radial/CWI`

    # safely cleanup out_dir
    rm $out_dir/radial/CWI/2013/07/09/IMOS_ACORN_RV_20130709T005500Z_CWI_FV00_radial.nc

    # remove hierarchy safely
    find $out_dir -type d -empty | tac | xargs -L1 rmdir

    rmdir $in_dir
}

##################
# SETUP/TEARDOWN #
##################

oneTimeSetUp() {
	BUILD_DIR_HIERARCHY=`dirname $0`/build-dir-hierarchy.sh
	BUILD_DIR_HIERARCHY_NO_MAIN=`mktemp`
	sed -e 's/^main .*//' $BUILD_DIR_HIERARCHY > $BUILD_DIR_HIERARCHY_NO_MAIN
}

oneTimeTearDown() {
	rm -f $BUILD_DIR_HIERARCHY_NO_MAIN
}

setUp() {
	true
}

tearDown() {
	true
}

# load and run shUnit2
. /usr/share/shunit2/shunit2
