#!/bin/bash

export SCRIPTPATH="$DATA_SERVICES_DIR/SOOP/SOOP_ASF_SST_XBT/soop_asf_sst_pipeline"
declare -r BACKUP_RECIPIENT=laurent.besnard@utas.edu.au
for f in $DATA_SERVICES_DIR/lib/netcdf/*; do [ -f "$f" ] && source "$f"; done
for f in $DATA_SERVICES_DIR/lib/common/*; do [ -f "$f" ] && source "$f"; done


# is_soop_asf_sst_file
# check that the file belongs to SOOP-SST subfacility
# $1 - netcdf file
is_soop_asf_sst_file() {
    local file=`basename $1`; shift
    echo $file | egrep -q '^IMOS_SOOP-SST_[A-Z]*_[0-9]{8}T[0-9]{6}Z_.*_FV0[0-1]_C-[0-9]{8}T[0-9]{6}Z.nc$|^IMOS_SOOP-ASF_[A-Z]*_[0-9]{8}T[0-9]{6}Z_.*_FV0[0-1]_C-[0-9]{8}T[0-9]{6}Z.nc$|^IMOS_SOOP-ASF_FMT_[0-9]{8}T[0-9]{6}Z_.*_FV02.nc$'
}

# temporary function to modify the original netcdf produced by bom to make
# it pass the compliance checker
# $1 - netcdf file
# $2 - modified netcdf file
modify_nc_pass_checker() {
   local file=$1; shift
   local tmp_modified_file=$1; shift

   if check_netcdf $file; then
       $SCRIPTPATH/make_soop_asf_sst_checker_compliant.sh $file $tmp_modified_file
   else
       file_error $file "NetCDF file not valid"
       return
   fi
}

# tests to perform on netcdf file
# $1 - netcdf file
check_file_pass_test() {
    local file=$1; shift
    local original_file=$1; shift # we need this to delete the file from incoming in case of failure

   if ! check_netcdf $file; then rm $file; file_error $original_file "Not a valid NetCDF file"; fi
   if ! check_netcdf_cf $file; then rm $file; file_error $original_file "File is not CF compliant"; fi
   if ! check_netcdf_imos $file; then rm $file; file_error $original_file "File is not IMOS compliant"; fi
   #if ! netcdf_checker $file --test=imos --criteria=lenient; then rm $file; file_error $original_file "File is not IMOS compliant"; fi
}

# return the IMOS path of a given netcdf file
# $1 - netcdf file
get_file_hierarchy() {
    local file=$1; shift
    local path_hierarchy=`$SCRIPTPATH/destPath.py $file` || file_error $file "Could not determine destination path for file"

    [ x"$path_hierarchy" = x ] && file_error $file "Could not determine destination path for file"

    # add sub-facility directory
    path_hierarchy='SOOP/'$path_hierarchy
    echo $path_hierarchy
}

# main
# $1 - incoming file to handle
main() {
    local file=$1; shift
    log_info "Handling soop asf file '$file'"
    is_soop_asf_sst_file $file || file_error $file "Not an SOOP-SST or ASF file"
    check_netcdf $file || file_error $file "Not a valid NetCDF file"

    # create a new netcdf file to pass checker
    local basename_file=`basename $file`
    local tmp_modified_file=`mktemp -d`"/$basename_file"
    modify_nc_pass_checker $file $tmp_modified_file

    # check modified file with CF and IMOS checker
    check_file_pass_test $tmp_modified_file $file

    # get file path
    local path_hierarchy=`get_file_hierarchy $file`
    s3_put $tmp_modified_file IMOS/$path_hierarchy && rm -f $file
}


main "$@"
