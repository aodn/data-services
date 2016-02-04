#!/usr/bin/env bash
# RUNS from NSP or TPAC with writing access
# $path_prefix variable might need to be modified
# This script modifies all SRS SST files to be CF compliant. The filename
# is also changed (in the python part) to get rid of the file version.
#
# A text file ($mod_filename_list) containing the original filename and its new filename
# will be used to create a sql script to upload new names in the database
# author laurent besnard, 2016


main() {
    local products_names="L3C-1d L3C-1dS L3C-3d  L3P L3S-14d L3S-1d L3S-1dS L3S-1m L3S-1mS L3S-3d L3S-6d L3U L3U-S"
    local path_prefix="/mnt/opendap/2/SRS/sst/ghrsst"
    local mod_filename_list="/mnt/ebs/wip/list_sst_filenames_to_modify.txt"
    local script_dir=`$(dirname $0)`

    # modify files product dir at a time
    for p in $products_names; do
        if [ ! -d $path_prefix/$p ]; then
            continue
        fi

        # need to look for symbolic links. we exclude all RT and 2016 folders
        for f in `find $path_prefix/$p -type f -not -path "*/2016/*" -not -path "*/RT/*" -follow`; do
          if echo $f | grep -q -E '[0-9]{14}.*.nc$|[0-9]{14}.*.nc4'; then # we exclude all other files, some are names .nc.BadVar, really ? on prod dataset ?
              new_netcdf_filename=`python $script_dir/bomGhrsstToCf.py $f`

              # create a space separated text file containing in $1 the original filename, in $2 the new filename (no path, filename only)
              # example
              # 20160102152000-ABOM-L3S_GHRSST-SSTskin-AVHRR_D-1d_night-v02.0-fv01.0.nc 20160102152000-ABOM-L3S_GHRSST-SSTskin-AVHRR_D-1d_night.nc
              echo `basename $f` `basename $new_netcdf_filename` >> $mod_filename_list
          fi
        done
    done
}


main "$@"
