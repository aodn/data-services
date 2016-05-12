#######################################
# unit tests for srs oc path hierachy #
#######################################
test_srs_file_path() {
    local tmp_input=`mktemp`
    cat <<EOF > $tmp_input
SRS/OC/gridded/aqua/P1D/2015/12                      A.P1D.20151201T000000Z.aust.chl_gsm.nc
SRS/OC/gridded/aqua/P1D/2015/12                      A.P1D.20151201T000000Z.aust.chl_oc3.nc
SRS/OC/gridded/aqua/P1D/2015/12                      A.P1D.20151201T000000Z.aust.dt.nc
SRS/OC/gridded/aqua/P1D/2015/12                      A.P1D.20151201T000000Z.aust.ipar.nc
SRS/OC/gridded/aqua/P1D/2015/12                      A.P1D.20151201T000000Z.aust.K_490.nc
SRS/OC/gridded/aqua/P1D/2015/12                      A.P1D.20151201T000000Z.aust.l2_flags.nc
SRS/OC/gridded/aqua/P1D/2015/12                      A.P1D.20151201T000000Z.aust.nanop_brewin2010at.nc
SRS/OC/gridded/aqua/P1D/2015/12                      A.P1D.20151201T000000Z.aust.nanop_brewin2012in.nc
SRS/OC/gridded/aqua/P1D/2015/12                      A.P1D.20151201T000000Z.aust.npp_vgpm_eppley_gsm.nc
SRS/OC/gridded/aqua/P1D/2015/12                      A.P1D.20151201T000000Z.aust.npp_vgpm_eppley_oc3.nc
SRS/OC/gridded/aqua/P1D/2015/12                      A.P1D.20151201T000000Z.aust.owtd.nc
SRS/OC/gridded/aqua/P1D/2015/12                      A.P1D.20151201T000000Z.aust.par.nc
SRS/OC/gridded/aqua/P1D/2015/12                      A.P1D.20151201T000000Z.aust.picop_brewin2010at.nc
SRS/OC/gridded/aqua/P1D/2015/12                      A.P1D.20151201T000000Z.aust.picop_brewin2012in.nc
SRS/OC/gridded/aqua/P1D/2015/12                      A.P1D.20151201T000000Z.aust.sst.nc
SRS/OC/gridded/aqua/P1D/2015/12                      A.P1D.20151201T000000Z.aust.tsm_clark16.nc
SRS/OC/gridded/seawifs/P1H/1998/10                   S.P1H.19981019T031100Z.overpass.chl_oc4.nc
SRS/OC/gridded/seawifs/P1H/1998/10                   S.P1H.19981019T031100Z.overpass.npp_vgpm_eppley_oc4.nc
SRS/OC/gridded/seawifs/P1H/1998/10                   S.P1H.19981019T031100Z.overpass.tsm_clark.nc
SRS/OC/gridded/contributed/SO-Johnson/chl/1m/aqua    A20100322010059.L3m_MO_SO_Chl_9km.Johnson_SO_Chl.nc
SRS/OC/gridded/contributed/SO-Johnson/chl/8d/aqua    A20100322010059.L3m_8D_SO_Chl_9km.Johnson_SO_Chl.nc
SRS/OC/gridded/contributed/SO-Johnson/chl/1m/seawifs S20100322010059.L3m_MO_SO_Chl_9km.Johnson_SO_Chl.nc
SRS/OC/gridded/contributed/SO-Johnson/chl/8d/seawifs S20100322010059.L3m_8D_SO_Chl_9km.Johnson_SO_Chl.nc
EOF

    local line
    IFS=$'\n'
    for line in `cat $tmp_input`; do
        unset IFS
        line=`echo $line | tr -s " "` # squeeze spaces
        local expected_hierarchy=`echo $line | tr -s " " | cut -d' ' -f1`
        local file=`echo $line | tr -s " " | cut -d' ' -f2`

        local hierarchy=`srs_file_path $file`
        local basename_file=`basename $file`

        assertEquals "hierarchy $file" "$expected_hierarchy/$file" "$hierarchy"
    done

    rm -f $tmp_input
}

##################
# SETUP/TEARDOWN #
##################

oneTimeSetUp() {
    INCOMING_HANDLER=`dirname $0`/oc_destination_path.sh
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
source /usr/share/shunit2/shunit2
