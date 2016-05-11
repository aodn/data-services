#!/usr/bin/env bash
declare -r AUV_CAMPAIGN_DATA_S3_BASE=IMOS/AUV
declare -r AUV_VIEWER_DATA_PATH=$AUV_CAMPAIGN_DATA_S3_BASE/auv_viewer_data

# returns the campaign name from a manifest file name
# $1 - file to handle
get_campaign_name() {
    local manifest_file=$1; shift
    campaign_name=`basename $manifest_file |  cut -d '-' -f1 | cut -d '_' -f2`
    [ -z "$campaign_name" ] && file_error 'could not guess the campaign name'
    echo $campaign_name
}

# returns the dive name from a manifest file name
# $1 - file to handle
get_dive_name() {
    local manifest_file=$1; shift
    dive_name=`basename $manifest_file  | cut -d '-' -f2 | cut -d '.' -f1`
    [ -z "$dive_name" ] && file_error 'could not guess the dive name'
    echo $dive_name
}

# returns the dive path from a manifest file name
# $1 - file to handle
dive_path() {
    local manifest_file=$1; shift

    local campaign_name=`get_campaign_name $manifest_file`
    local dive_name=`get_dive_name $manifest_file`

    [ -z "$AUV_CAMPAIGN_DATA_S3_BASE" ] && file_error 'AUV_CAMPAIGN_DATA_S3_BASE env unknown'

    echo $AUV_CAMPAIGN_DATA_S3_BASE/$campaign_name/$dive_name
}

# process a manifest file containing path to netcdf files only
# NetCDF files are harvested by a different harverster
# $1 - file to handle
process_manifest_netcdf() {
    local manifest_file=$1; shift
    local path_hierarchy=`dive_path $manifest_file`

    for netcdf_file in `cat $manifest_file`; do
        [ ! -f $netcdf_file ] && file_error "$netcdf_file not found"
        # files don't pass the checker yet
        s3_put $netcdf_file $path_hierarchy/hydro_netcdf/`basename $netcdf_file`
    done

    log_info "Successfully handled all AUV NetCDF files!" && rm $manifest_file
}

# process a manifest file containing path to the csv files used by the viewer
# all CSV files are harvested by the AUV_VIEWER_TRACKS harvester
# $1 - file to handle
process_manifest_csv_data() {
    local manifest_file=$1; shift
    local campaign_name=`get_campaign_name $manifest_file`

    for csv_file in `cat $manifest_file`; do
        # files don't pass the checker yet
        [ ! -f $csv_file ] && file_error "$csv_file not found"
        s3_put $csv_file $AUV_VIEWER_DATA_PATH/csv_outputs/$campaign_name/`basename $csv_file`
    done

    log_info "Successfully handled all AUV CSV output files!" && rm $manifest_file
}

# process a manifest file containing path to the csv reporting file used by the viewer
# $1 - file to handle
process_manifest_reporting_data() {
    local reporting_file=$1; shift

    s3_put $reporting_file $AUV_VIEWER_DATA_PATH/csv_outputs/auvReporting.csv
    log_info "Successfully handled all AUV reporting files!"
}

# process a manifest file containing path to the thumbnails used by the viewer
# Push thumbnails to s3 without indexing
# $1 - file to handle
process_manifest_thumbnail() {
    local manifest_file=$1; shift
    local campaign_name=`get_campaign_name $manifest_file`
    local dive_name=`get_dive_name $manifest_file`

    [ -z "$AUV_VIEWER_DATA_PATH" ] && file_error 'AUV_VIEWER_DATA_PATH env unknown'
    log_info "Handling AUV thumbnails files!"

    for thumbnail in `cat $manifest_file`; do
        s3_put_no_index $thumbnail $AUV_VIEWER_DATA_PATH/thumbnails/$campaign_name/$dive_name/i2jpg/`basename $thumbnail`
    done

    log_info "Successfully handled all AUV thumbnails files!" && rm $manifest_file
}

# process a manifest file containing path to the dive data to be pushed asynchronously to s3
# modify with extreme care !! should add unittests
# $1 - file to handle
process_manifest_dive() {
    local manifest_file=$1; shift
    local campaign_name=`get_campaign_name $manifest_file`

    [ -z "$AUV_CAMPAIGN_DATA_S3_BASE" ] && file_error 'AUV_CAMPAIGN_DATA_S3_BASE env unknown'

    log_info "Handling AUV data copy"
    for dive in `cat $manifest_file`; do
        find $dive -type f | awk -v pwd=$PWD '{print $1 " " $1}' | sed "s# .*$campaign_name# $AUV_CAMPAIGN_DATA_S3_BASE/$campaign_name#g" | async-upload.py
    done

    log_info "Successfully uploaded asynchronously all AUV data!" && rm $manifest_file
}

# process a manifest file containing path to pdf data reports to be pushed to s3
# $1 - file to handle
process_manifest_reports() {
    local manifest_file=$1; shift
    local campaign_name=`basename $manifest_file | cut -d '_' -f2 | cut -d '.' -f1`

    [ -z "$campaign_name" ] && file_error 'could not guess the campaign name'

    log_info "Handling AUV data reports copy to s3"
    for reports_path in `cat $manifest_file`; do
        log_info $report_path $manifest_file
        for file in `find $reports_path -type f`; do
            s3_put_no_index $file `echo $file | sed "s#.*$campaign_name#$AUV_CAMPAIGN_DATA_S3_BASE/$campaign_name#g"`
        done
    done

    log_info "Successfully uploaded all reports data!" && rm $manifest_file
}

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
    local manifest_file=$1; shift
    local regex='^manifest_.*r.*\.netcdf$|^manifest_.*-r.*\.csv$|^manifest_.*-r.*\.thumbnail$|^manifest_.*-r.*\.dive$|^auvReporting.csv$|^manifest_.*\.reports$'

    regex_filter "$regex" $manifest_file || file_error "Did not pass regex filter '$regex'"

    basename $manifest_file | grep -q -E '^manifest_.*-r.*\.netcdf$'    && process_manifest_netcdf $manifest_file
    basename $manifest_file | grep -q -E '^manifest_.*-r.*\.csv$'       && process_manifest_csv_data $manifest_file
    basename $manifest_file | grep -q -E '^manifest_.*-r.*\.thumbnail$' && process_manifest_thumbnail $manifest_file
    basename $manifest_file | grep -q -E '^auvReporting.csv$'           && process_manifest_reporting_data $manifest_file
    basename $manifest_file | grep -q -E '^manifest_.*\.reports$'       && process_manifest_reports $manifest_file
    basename $manifest_file | grep -q -E '^manifest_.*-r.*\.dive$'      && process_manifest_dive $manifest_file
}


main "$@"
