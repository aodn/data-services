#!/bin/bash

export PYTHONPATH="$DATA_SERVICES_DIR/ABOS"
export SCRIPTPATH="$DATA_SERVICES_DIR/ABOS/SOTS"

declare -r BACKUP_RECIPIENT=marty.hidas@utas.edu.au


# main
# $1 - file to handle
main() {
    local file=$1; shift

    check_netcdf      $file || file_error_and_report_to_uploader $file $BACKUP_RECIPIENT "Not a valid NetCDF file"
    check_netcdf_cf   $file || file_error_and_report_to_uploader $file $BACKUP_RECIPIENT "File is not CF compliant"
    check_netcdf_imos $file || file_error_and_report_to_uploader $file $BACKUP_RECIPIENT "File is not IMOS compliant"
    echo $file | grep 'ABOS-SOTS' >/dev/null || file_error_and_report_to_uploader $file $BACKUP_RECIPIENT "Not an ABOS-SOTS file"

    local path_hierarchy
    path_hierarchy=`$SCRIPTPATH/destPath.py $file` || file_error $file "Could not determine destination path for file"
    [ x"$path_hierarchy" = x ] && file_error $file "Could not determine destination path for file"

    # archive previous version of file if found on opendap
    prev_version_files=`$SCRIPTPATH/previousVersions.py $file $OPENDAP_IMOS_DIR/$path_hierarchy` || file_error $file "Could not find previously published versions of file"

    if [ `echo $path_hierarchy | egrep -i 'real-time'` ]; then
        # realtime files, old versions can just be deleted
        for prev_file in $prev_version_files ; do
            rm -f $prev_file
        done
    else
        # delayed-mode file, old versions need to be archived
        for prev_file in $prev_version_files ; do
            move_to_production $prev_file $ARCHIVE_DIR $path_hierarchy/`basename $prev_file`
	    # move_to_archive $prev_file $path_hierarchy ???
        done
    fi

#    move_to_production_s3 $file IMOS/$path_hierarchy/`basename $file`
    move_to_production $file $OPENDAP_DIR/1 IMOS/opendap/$path_hierarchy/`basename $file`
}


main "$@"
