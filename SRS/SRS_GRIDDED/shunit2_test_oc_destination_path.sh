########################################
# unit tests for srs sst path hierachy #
########################################
test_srs_file_path() {
    local tmp_input=`mktemp`
    cat <<EOF > $tmp_input
SRS/OC/gridded/aqua/1d/2015/12                            A20151201.aust.chl_gsm.nc
SRS/OC/gridded/aqua/1d/2015/12                            A20151201.aust.chl_oc3.nc
SRS/OC/gridded/aqua/1d/2015/12                            A20151201.aust.dt.nc
SRS/OC/gridded/aqua/1d/2015/12                            A20151201.aust.ipar.nc
SRS/OC/gridded/aqua/1d/2015/12                            A20151201.aust.K_490.nc
SRS/OC/gridded/aqua/1d/2015/12                            A20151201.aust.l2_flags.nc
SRS/OC/gridded/aqua/1d/2015/12                            A20151201.aust.nanop_brewin2010at.nc
SRS/OC/gridded/aqua/1d/2015/12                            A20151201.aust.nanop_brewin2012in.nc
SRS/OC/gridded/aqua/1d/2015/12                            A20151201.aust.npp_vgpm_eppley_gsm.nc
SRS/OC/gridded/aqua/1d/2015/12                            A20151201.aust.npp_vgpm_eppley_oc3.nc
SRS/OC/gridded/aqua/1d/2015/12                            A20151201.aust.owtd.nc
SRS/OC/gridded/aqua/1d/2015/12                            A20151201.aust.par.nc
SRS/OC/gridded/aqua/1d/2015/12                            A20151201.aust.picop_brewin2010at.nc
SRS/OC/gridded/aqua/1d/2015/12                            A20151201.aust.picop_brewin2012in.nc
SRS/OC/gridded/aqua/1d/2015/12                            A20151201.aust.sst.nc
SRS/OC/gridded/aqua/1d/2015/12                            A20151201.aust.tsm_clark16.nc
SRS/OC/gridded/aqua/1m/2015                               201501.par.nc
SRS/OC/gridded/aqua/1mNy                                  2003-2014.05.chl_gsm_mean.nc
SRS/OC/gridded/aqua/1y                                    2006.sst_mean.nc
SRS/OC/gridded/aqua/12mNy                                 2003-2014.01-12.chl_gsm_mean_mean_mean.nc
SRS/OC/gridded/aqua/12mNy                                 2003-2014x01-12.chl_gsm_mean_mean.nc
SRS/OC/gridded/contributed/nasa-global-oc/1d/aqua/2015    A20150101.L3m_DAY_CHL_chlor_a_4km.nc
SRS/OC/gridded/contributed/nasa-global-oc/1d/terra/2015   T20150101.L3m_DAY_CHL_chlor_a_4km.nc
SRS/OC/gridded/contributed/nasa-global-oc/1d/seawifs/2010 S20101010.L3m_DAY_CHL_chlor_a_9km.nc
SRS/OC/gridded/contributed/SO-Johnson/chl/1m/aqua         A20100322010059.L3m_MO_SO_Chl_9km.Johnson_SO_Chl.nc
SRS/OC/gridded/contributed/SO-Johnson/chl/1m/seawifs      S20100322010059.L3m_MO_SO_Chl_9km.Johnson_SO_Chl.nc
SRS/OC/gridded/contributed/SO-Johnson/chl/8d/aqua         A20100322010059.L3m_8D_SO_Chl_9km.Johnson_SO_Chl.nc
SRS/OC/gridded/contributed/SO-Johnson/chl/8d/seawifs      S20100322010059.L3m_8D_SO_Chl_9km.Johnson_SO_Chl.nc
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
