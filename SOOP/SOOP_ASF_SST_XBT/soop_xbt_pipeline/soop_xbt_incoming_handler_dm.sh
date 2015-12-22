#!/bin/bash
DEFAULT_BACKUP_RECIPIENT=laurent.besnard@utas.edu.au
PATH_EVALUATION_EXECUTABLE='SOOP/SOOP_ASF_SST_XBT/soop_xbt_pipeline/destPath.py'
PATH_CREATE_PLOT_EXECUTABLE='SOOP/SOOP_ASF_SST_XBT/soop_xbt_pipeline/createPlot.py'

for f in $DATA_SERVICES_DIR/lib/netcdf/*; do [ -f "$f" ] && source "$f"; done

# returns non zero if file does not match regex filter
# $1 - regex to match with
# $2 - file to validate
regex_filter() {
    local regex="$1"; shift
    local file=`basename $1`; shift
    echo $file | grep -E $regex -q
}

# main
# $1 - file to handle
main() {
    local file=$1; shift
    local checks='cf imos'
    local regex='(^IMOS_SOOP-XBT_T_[[:digit:]]{8}T[[:digit:]]{6}Z_.*_FV0[01]_.*\.nc$|^XBT_T_[[:digit:]]{8}T[[:digit:]]{6}Z_.*_FV0[01]_.*\.nc$)'

    regex_filter "$regex" $file || file_error "Did not pass regex filter '$regex'"

    # modify original file to pass the checker
    local tmp_file=`mktemp`
    $DATA_SERVICES_DIR/SOOP/SOOP_ASF_SST_XBT/soop_xbt_pipeline/soop_xbt_netcdf_compliance.sh $file $tmp_file

    tmp_file=`trigger_checkers_and_add_signature $tmp_file $DEFAULT_BACKUP_RECIPIENT $checks` || return 1

    local path_hierarchy
    path_hierarchy=`$DATA_SERVICES_DIR/$PATH_EVALUATION_EXECUTABLE $file`
    if [ $? -ne 0 ] || [ x"$path_hierarchy" = x ]; then
        file_error "Could not evaluate path for '$file' using '$PATH_EVALUATION_EXECUTABLE'"
    fi

    # create plot on the fly
    local tmp_plot=`$DATA_SERVICES_DIR/$PATH_CREATE_PLOT_EXECUTABLE $tmp_file`
    if [ $? -ne 0 ] || [ x"$tmp_plot" = x ]; then
        file_error "Could not create plot for '$file' using '$PATH_CREATE_PLOT_EXECUTABLE'"
    fi

    s3_put $tmp_file IMOS/$path_hierarchy && rm -f $file

    local plot_path=`echo IMOS/$path_hierarchy | sed "s/\.nc$/.jpg/g"`
    s3_put_no_index $tmp_plot $plot_path && rm -f $plot_path
}

main "$@"
