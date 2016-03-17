########################################
# unit tests for srs sst path hierachy #
########################################
test_srs_file_path() {
    # not sure yet if those 2 file types need to be tested and added to the pipeline
    # 20140428-ABOM-L3P_GHRSST-SSTsubskin-AVHRR_MOSAIC_01km-AO_DAAC-v01-fv01_0.nc4

    local tmp_input=`mktemp`
    cat <<EOF > $tmp_input
SRS/SST/ghrsst/L3U-S/n09/1995       19950309232523-ABOM-L3U_GHRSST-SSTskin-AVHRR09_D-Des_Southern.nc
SRS/SST/ghrsst/L3U-S/n19/2015       20151204200948-ABOM-L3U_GHRSST-SSTskin-AVHRR19_D-Des_Southern.nc
SRS/SST/ghrsst/L3U/n09/1995         19950309232523-ABOM-L3U_GHRSST-SSTskin-AVHRR09_D-Asc.nc
SRS/SST/ghrsst/L3U/n19/2015         20151204200948-ABOM-L3U_GHRSST-SSTskin-AVHRR19_D-Asc.nc
SRS/SST/ghrsst/L3U/n09/1995         19950309232523-ABOM-L3U_GHRSST-SSTskin-AVHRR09_D-Des.nc
SRS/SST/ghrsst/L3U/n19/2015         20151204200948-ABOM-L3U_GHRSST-SSTskin-AVHRR19_D-Des.nc
SRS/SST/ghrsst/L3U/n09/1995         19950309232523-ABOM-L3U_GHRSST-SSTskin-AVHRR09_D-Asc.nc
SRS/SST/ghrsst/L3U/n19/2015         20151204200948-ABOM-L3U_GHRSST-SSTskin-AVHRR19_D-Asc.nc
SRS/SST/ghrsst/L3S-6d/day/2015      20151201152000-ABOM-L3S_GHRSST-SSTskin-AVHRR_D-6d_day.nc
SRS/SST/ghrsst/L3S-6d/dn/2015       20151201212000-ABOM-L3S_GHRSST-SSTfnd-AVHRR_D-6d_dn.nc
SRS/SST/ghrsst/L3S-6d/ngt/2015      20151202032000-ABOM-L3S_GHRSST-SSTskin-AVHRR_D-6d_night.nc
SRS/SST/ghrsst/L3S-3d/ngt/2015      20151203152000-ABOM-L3S_GHRSST-SSTskin-AVHRR_D-3d_night.nc
SRS/SST/ghrsst/L3S-3d/day/2015      20151203032000-ABOM-L3S_GHRSST-SSTskin-AVHRR_D-3d_day.nc
SRS/SST/ghrsst/L3S-3d/dn/2015       20151203092000-ABOM-L3S_GHRSST-SSTfnd-AVHRR_D-3d_dn.nc
SRS/SST/ghrsst/L3S-1mS/dn/2015      20151130231000-ABOM-L3S_GHRSST-SSTfnd-AVHRR_D-1m_dn_Southern.nc
SRS/SST/ghrsst/L3S-1m/ngt/2015      20151130032000-ABOM-L3S_GHRSST-SSTskin-AVHRR_D-1m_night.nc
SRS/SST/ghrsst/L3S-1m/dn/2015       20150131092000-ABOM-L3S_GHRSST-SSTfnd-AVHRR_D-1m_dn.nc
SRS/SST/ghrsst/L3S-1m/day/2015      20151130152000-ABOM-L3S_GHRSST-SSTskin-AVHRR_D-1m_day.nc
SRS/SST/ghrsst/L3S-1dS/dn/2015      20151204111000-ABOM-L3S_GHRSST-SSTfnd-AVHRR_D-1d_dn_Southern.nc
SRS/SST/ghrsst/L3S-1d/ngt/2015      20151204152000-ABOM-L3S_GHRSST-SSTskin-AVHRR_D-1d_night.nc
SRS/SST/ghrsst/L3S-1d/dn/2015       20151204092000-ABOM-L3S_GHRSST-SSTfnd-AVHRR_D-1d_dn.nc
SRS/SST/ghrsst/L3S-1d/day/2015      20151204032000-ABOM-L3S_GHRSST-SSTskin-AVHRR_D-1d_day.nc
SRS/SST/ghrsst/L3S-14d/ngt/2015     20151128032000-ABOM-L3S_GHRSST-SSTskin-AVHRR_D-14d_night.nc
SRS/SST/ghrsst/L3S-14d/dn/2015      20151127212000-ABOM-L3S_GHRSST-SSTfnd-AVHRR_D-14d_dn.nc
SRS/SST/ghrsst/L3S-14d/day/2015     20151127152000-ABOM-L3S_GHRSST-SSTskin-AVHRR_D-14d_day.nc
SRS/SST/ghrsst/L3C-3d/ngt/n19/2015  20151203152000-ABOM-L3C_GHRSST-SSTskin-AVHRR19_D-3d_night.nc
SRS/SST/ghrsst/L3C-3d/day/n19/2015  20151203032000-ABOM-L3C_GHRSST-SSTskin-AVHRR19_D-3d_day.nc
SRS/SST/ghrsst/L3C-1dS/ngt/n19/2015 20151204171000-ABOM-L3C_GHRSST-SSTskin-AVHRR19_D-1d_night_Southern.nc
SRS/SST/ghrsst/L3C-1dS/day/n19/2015 20151204051000-ABOM-L3C_GHRSST-SSTskin-AVHRR19_D-1d_day_Southern.nc
SRS/SST/ghrsst/L3C-1d/ngt/n19/2015  20151204152000-ABOM-L3C_GHRSST-SSTskin-AVHRR19_D-1d_night.nc
SRS/SST/ghrsst/L3C-1d/day/n19/2015  20151204032000-ABOM-L3C_GHRSST-SSTskin-AVHRR19_D-1d_day.nc
SRS/SST/ghrsst/L3S-1dS/dn/1999      19990207111000-ABOM-L3S_GHRSST-SSTfnd-AVHRR_D-1d_dn_Southern.nc
SRS/SST/ghrsst/L3S-1d/dn/2015       20150623092000-ABOM-L3S_GHRSST-SSTfnd-AVHRR_D-1d_dn.nc
SRS/SST/ghrsst/L3S-1d/day/2015      20151203032000-ABOM-L3S_GHRSST-SSTskin-AVHRR_D-1d_day.nc
SRS/SST/ghrsst/L3S-1d/ngt/2015      20151130152000-ABOM-L3S_GHRSST-SSTskin-AVHRR_D-1d_night.nc
SRS/SST/ghrsst/L3S-1d/dn/2015       20151203032000-ABOM-L3S_GHRSST-SSTskin-AVHRR_D-1d_dn.nc
SRS/SST/ghrsst/L3S-3d/dn/2015       20151203032000-ABOM-L3S_GHRSST-SSTskin-AVHRR_D-3d_dn.nc
SRS/SST/ghrsst/L3S-6d/dn/2015       20151203032000-ABOM-L3S_GHRSST-SSTskin-AVHRR_D-6d_dn.nc
SRS/SST/ghrsst/L3S-1m/dn/1992       19921231092000-ABOM-L3S_GHRSST-SSTfnd-AVHRR_D-1m_dn.nc
SRS/SST/ghrsst/L3C-3d/ngt/n19/2015  20150722152000-ABOM-L3C_GHRSST-SSTskin-AVHRR19_D-3d_night.nc
SRS/SST/ghrsst/L3C-1d/ngt/n19/2015  20151130152000-ABOM-L3C_GHRSST-SSTskin-AVHRR19_D-1d_night.nc
SRS/SST/ghrsst/L3U-S/n19/2013       20131011153743-ABOM-L3U_GHRSST-SSTskin-AVHRR19_D-Des_Southern.nc
SRS/SST/ghrsst/L3U/n19/2015         20151201185911-ABOM-L3U_GHRSST-SSTskin-AVHRR19_D-Des.nc
SRS/SST/ghrsst/L3U/mtsat1r/2010/07  20100726104543-ABOM-L3U_GHRSST-SSTskin-MTSAT_1R-CRTM.nc
SRS/SST/ghrsst/L3P/14d/2014         20140428-ABOM-L3P_GHRSST-SSTsubskin-AVHRR_MOSAIC_01km-AO_DAAC.nc
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
    INCOMING_HANDLER=`dirname $0`/sst_destination_path.sh
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
