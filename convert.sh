#! /bin/bash
#
# convert netCDF file from IMOS to OceanSITES convention
# (using nco tools: ncks, ncatted and ncrename)
#
# usage: convert.sh infile

ATTED='ncatted -Oh'
RENAME='ncrename -Oh'
GETATT=$PYTHONPATH/oceansites/trunk/getattr.sh

# create output filename
PLATFORM=$($GETATT $1 platform_code)
DEPLOYMENT=$($GETATT $1 deployment_code | sed 's/PULSE-//')
DATAMODE=D
ID=OS_${PLATFORM}_${DEPLOYMENT}_$DATAMODE
NCOUT=$ID.nc
echo Output file: $NCOUT

# copy input file
cp -v $1 $NCOUT


## attributes to add/overwrite
echo Setting attributes ...
# global
$ATTED  -a data_type,global,o,c,"OceanSITES time-series data" \
        -a format_version,global,o,c,"1.2" \
	-a data_mode,global,o,c,$DATAMODE  \
        -a network,global,o,c,"IMOS"  \
        -a references,global,o,c,"http://www.oceansites.org, http://imos.org.au/sots.html"  \
        -a id,global,o,c,$ID  \
        -a area,global,o,c,"Southern Ocean"  \
        -a update_interval,global,o,c,"void"  \
        -a institution,global,o,c,"Commonwealth Scientific and Industrial Research Organisation (CSIRO)" \
        -a source,global,o,c,"Mooring observation" \
        -a naming_authority,global,o,c,"OceanSITES" \
        -a data_centre,global,o,c,"IMOS" \
        -a citation,global,o,c,"Integrated Marine Observing System, 2012, 'Pulse 8 Mooring Data', [Data access URL], accessed [date-of-access]" \
        -a conventions,global,o,c,"CF-1.5, OceanSITES 1.2" \
        $NCOUT
# variable
$ATTED  -a standard_name,TIME,o,c,"time" \
        -a QC_indicator,TIME,o,b,0 \
        -a QC_procedure,TIME,o,b,0 \
        $NCOUT


## attributes to delete
echo Deleting attributes ...
# global
ARG=''
for att in Latitude \
           Longitude \
           quality_control_set \
           product_type \
           field_trip_id \
           field_trip_description \
           level \
           file_version ; do
    ARG=$ARG'  -a '$att',global,d,,'
done
$ATTED  $ARG  $NCOUT
# variable
$ATTED  -a quality_control_set,,d,, \
        -a long_name,TIME,d,, \
        $NCOUT


## attribute values to change
echo Converting global attributes to string ...
# geospatial_*_min/max convert to string
ARG=''
for att in geospatial_lat_min \
	   geospatial_lon_min \
	   geospatial_lat_max \
	   geospatial_lon_max \
	   geospatial_vertical_min \
	   geospatial_vertical_max; do
    ARG=$ARG'  -a '$att',global,m,c,'$($GETATT $NCOUT $att)
done
$ATTED $ARG $NCOUT


## attributes to rename
echo Renaming attributes ...
$RENAME -a .date_created,date_update  \
        -a .abstract,summary \
        -a .data_centre,data_assembly_center  \
        -a .data_centre_email,contact \
        -a .principal_investigator,pi_name \
        -a .principal_investigator_email,pi_email \
        -a .sensor,sensor_name \
        -a .conventions,Conventions \
        $NCOUT
