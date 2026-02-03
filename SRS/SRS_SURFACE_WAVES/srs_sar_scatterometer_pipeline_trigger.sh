#!/usr/bin/env bash
# script to automate the creation of manifest files for NetCDF landed in the
# srs scatterometer incoming directory
# requires fd
# author laurent besnard

fd_bin=$(command -v fd)
[ -z $fd_bin ] && echo "please install fd to use this script" && exit 0

SRS_SCATT_DIR=$INCOMING_DIR/SRS/SURFACE_WAVES/scatterometer/incoming
SRS_SCATT_MANIFEST_DIR=$SRS_SCATT_DIR/manifest_dir

declare -a sat_list_array
sat_list_array=(METOP-A METOP-B METOP-C ERS-1 ERS-2 QUIKSCAT OCEANSAT-2
  RAPIDSCAT OceanSat-3 HY-2B HY-2C)

for i in "${sat_list_array[@]}"; do
  fd -t f -a -e nc "$i" $SRS_SCATT_DIR >$SRS_SCATT_MANIFEST_DIR/"$i".manifest
  split -d -l1024 $SRS_SCATT_MANIFEST_DIR/"$i".manifest \
    "$SRS_SCATT_MANIFEST_DIR"/srs_altimeter.$i. \
    --additional-suffix=.manifest
  rm -f $SRS_SCATT_MANIFEST_DIR/"$i".manifest
done

# manually done
#echo mv $SRS_SCATT_MANIFEST_DIR/* $INCOMING_DIR/SRS/SURFACE_WAVES/scatterometer/trigger
