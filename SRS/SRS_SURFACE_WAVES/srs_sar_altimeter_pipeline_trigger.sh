#!/usr/bin/env bash
# script to automate the creation of manifest files for NetCDF landed in the
# srs incoming directory
# requires fd
# author laurent besnard

fd_bin=`command -v fd`
[ -z $fd_bin ] && echo "please install fd to use this script" && exit 0

SRS_ALTI_DIR=$INCOMING_DIR/SRS/SURFACE_WAVES/altimeter/incoming
SRS_ALTI_MANIFEST_DIR=$SRS_ALTI_DIR/manifest_dir

declare -a sat_list_array
sat_list_array=(CRYOSAT-2 ENVISAT ERS-1 ERS-2 GEOSAT GFO HY-2 JASON-1 \
    JASON-2 JASON-3 SARAL SENTINEL-3A SENTINEL-3B TOPEX)

for i in "${sat_list_array[@]}"; do
    fd -t f -a -e nc "$i" $SRS_ALTI_DIR > $SRS_ALTI_MANIFEST_DIR/"$i".manifest
    split -d -l1024 $SRS_ALTI_MANIFEST_DIR/"$i".manifest \
        "$SRS_ALTI_MANIFEST_DIR"/srs_altimeter.$i. \
        --additional-suffix=.manifest
    rm -f $SRS_ALTI_MANIFEST_DIR/"$i".manifest
done

# manually done
#echo mv $SRS_ALTI_MANIFEST_DIR/* $INCOMING_DIR/SRS/SURFACE_WAVES/altimeter_trigger
