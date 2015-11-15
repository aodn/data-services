#!/bin/bash

# test hierarchy buildup for given file
test_hierarchy_build() {
    local tmp_input=`mktemp`

    cat <<EOF > $tmp_input
IMOS_ACORN_RV_20100530T220000Z_BFCV_FV00_radial.nc radial BFCV/2010/05/30
IMOS_ACORN_RV_20110423T160000Z_CRVT_FV00_radial.nc radial CRVT/2011/04/23
IMOS_ACORN_RV_20120316T200500Z_CSP_FV00_radial.nc  radial CSP/2012/03/16
IMOS_ACORN_RV_20130209T214000Z_CWI_FV00_radial.nc  radial CWI/2013/02/09
IMOS_ACORN_RV_20140102T035500Z_FRE_FV00_radial.nc  radial FRE/2014/01/02
IMOS_ACORN_RV_20151228T020000Z_GHED_FV00_radial.nc radial GHED/2015/12/28
IMOS_ACORN_RV_20161121T003000Z_GUI_FV00_radial.nc  radial GUI/2016/11/21
IMOS_ACORN_RV_20171014T060000Z_LANC_FV00_radial.nc radial LANC/2017/10/14
IMOS_ACORN_RV_20180907T210500Z_LEI_FV00_radial.nc  radial LEI/2018/09/07
IMOS_ACORN_RV_20190825T053500Z_NNB_FV00_radial.nc  radial NNB/2019/08/25
IMOS_ACORN_RV_20200718T140000Z_NOCR_FV00_radial.nc radial NOCR/2020/07/18
IMOS_ACORN_RV_20210611T085000Z_RRK_FV00_radial.nc  radial RRK/2021/06/11
IMOS_ACORN_RV_20220504T010000Z_SBRD_FV00_radial.nc radial SBRD/2022/05/04
IMOS_ACORN_RV_20230401T012000Z_TAN_FV00_radial.nc  radial TAN/2023/04/01

IMOS_ACORN_V_20180910T010000Z_BONC_FV00_sea-state.nc vector BONC/2018/09/10
IMOS_ACORN_V_20140804T010000Z_TURQ_FV00_sea-state.nc vector TURQ/2014/08/04

IMOS_ACORN_RV_20120507T053500Z_CSP_FV01_radial.nc radial_quality_controlled CSP/2012/05/07
IMOS_ACORN_RV_20130408T142000Z_CWI_FV01_radial.nc radial_quality_controlled CWI/2013/04/08
IMOS_ACORN_RV_20140309T012500Z_FRE_FV01_radial.nc radial_quality_controlled FRE/2014/03/09
IMOS_ACORN_RV_20150210T001000Z_GUI_FV01_radial.nc radial_quality_controlled GUI/2015/02/10
IMOS_ACORN_RV_20160111T023500Z_LEI_FV01_radial.nc radial_quality_controlled LEI/2016/01/11
IMOS_ACORN_RV_20171212T044500Z_NNB_FV01_radial.nc radial_quality_controlled NNB/2017/12/12
IMOS_ACORN_RV_20181113T123000Z_RRK_FV01_radial.nc radial_quality_controlled RRK/2018/11/13
IMOS_ACORN_RV_20191014T192000Z_TAN_FV01_radial.nc radial_quality_controlled TAN/2019/10/14

IMOS_ACORN_W_20090808T023000Z_CBG_FV01_wavespec.nc gridded_1h-avg-wave-spectra_QC CBG/2009/08/08
IMOS_ACORN_W_20090801T023000Z_CBG_FV01_wavespec.nc gridded_1h-avg-wave-spectra_QC CBG/2009/08/01

IMOS_ACORN_MW_20110228T073000Z_CBG_FV01_windp.nc gridded_1h-avg-wind-map_QC CBG/2011/02/28
IMOS_ACORN_MW_20110921T063000Z_SAG_FV01_windp.nc gridded_1h-avg-wind-map_QC SAG/2011/09/21

IMOS_ACORN_W_20110921T053000Z_SAG_FV01_wavep.nc gridded_1h-avg-wave-site-map_QC SAG/2011/09/21
IMOS_ACORN_W_20110921T053000Z_CSP_FV01_wavep.nc gridded_1h-avg-wave-station-map_QC CSP/2011/09/21
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

        assertEquals "type $file"      "$expected_type"                                 "$type"
        assertEquals "hierarchy $file" "ACORN/$expected_type/$expected_hierarchy/$file" "$hierarchy"
    done

    rm -f $tmp_input
}

# unknown types
test_unknown_type() {
    local file="IMOS_ACORN_RV_20171212T044500Z_NNB_FV01_unknown.nc"
    local type=`get_type $file`
    assertEquals "type $file" "" "$type"
}

test_match_regex() {
    regex_filter() {
        local acorn_regex='^IMOS_ACORN_[[:alpha:]]{1,2}_[[:digit:]]{8}T[[:digit:]]{6}Z_[[:alpha:]]{3,4}_FV0[01]_(radial|sea-state|wavespec|windp|wavep)\.nc$'
        echo $1 | grep -E $acorn_regex -q
    }

    local good_files bad_files
    good_files="$good_files IMOS_ACORN_RV_20171014T060000Z_LANC_FV00_radial.nc"
    good_files="$good_files IMOS_ACORN_RV_20161121T003000Z_GUI_FV00_radial.nc"
    good_files="$good_files IMOS_ACORN_V_20180910T010000Z_BONC_FV00_sea-state.nc"
    good_files="$good_files IMOS_ACORN_RV_20120507T053500Z_CSP_FV01_radial.nc"
    good_files="$good_files IMOS_ACORN_W_20090808T023000Z_CBG_FV01_wavespec.nc"
    good_files="$good_files IMOS_ACORN_MW_20110921T083000Z_SAG_FV01_windp.nc"
    good_files="$good_files IMOS_ACORN_W_20110921T053000Z_SAG_FV01_wavep.nc"
    good_files="$good_files IMOS_ACORN_W_20110921T053000Z_CSP_FV01_wavep.nc"

    bad_files="$bad_files IMOS_ACON_RV_20171014T060000Z_LANC_FV00_radial.nc"
    bad_files="$bad_files IMOS_ACORN_RV_201611203000Z_GUI_FV00_radial.nc"
    bad_files="$bad_files IMOS_ACORN_V_20180910T010000Z_BONC_FV00_sea-se.nc"
    bad_files="$bad_files IMOS_ACORN_RV_20120507T053500Z_FV01_radial.nc"
    bad_files="$bad_files IMOS_ACORN_RV_20191014T192000Z_TAN_FV01_radial.nc.some_suffix"
    bad_files="$bad_files prefix.IMOS_ACORN_RV_20191014T192000Z_TAN_FV01_radial.nc"

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
    PATH_GENERATION=`dirname $0`/path_generation.sh
    PATH_GENERATION_NO_MAIN=`mktemp`
    sed -e 's/^main .*//' $PATH_GENERATION > $PATH_GENERATION_NO_MAIN
}

oneTimeTearDown() {
    rm -f $PATH_GENERATION_NO_MAIN
}

setUp() {
    source $PATH_GENERATION_NO_MAIN
}

tearDown() {
    true
}

# load and run shUnit2
. /usr/share/shunit2/shunit2
