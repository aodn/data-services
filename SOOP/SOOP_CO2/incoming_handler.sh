#!/bin/bash

export SCRIPTPATH="$DATA_SERVICES_DIR/SOOP/SOOP_CO2"

declare -r BACKUP_RECIPIENT=benedicte.pasquer@utas.edu.au

# is_imos_soop_co2_file
# check that the file from IMOS SOOP_CO2
# $1 - file name
is_imos_soop_co2_file() {
  local file=`basename $1`; shift
  echo $file | egrep -q '^IMOS_SOOP-CO2_'
}

# is_future_reef_map_file
# check that the file belongs toFuture Reef MAP project
# $1 - file name
is_future_reef_map_file() {
  local file=`basename $1`; shift
  echo $file | egrep -q '^FutureReefMap_'
}

# is_valid_path
# check validity of generated path to storage
# $1 path
is_valid_path() {
  local path=$1; shift
  local VALID_REGEX="^(IMOS/SOOP/SOOP-CO2|Future_Reef_MAP/underway/RTM-Wakmatha)/"
  echo $path | egrep -q "$VALID_REGEX"
}
# notify_recipients
# notify uploader and backup recipient about status of uploaded file
# $1 - file name
# $2 - message
notify_recipients() {
  local message="$1"; shift
  local recipient
  recipient=`get_uploader_email $INCOMING_FILE` || recipient=$BACKUP_RECIPIENT

  echo "" | notify_by_email $recipient "$message"
}

# handles realtime text file (other txt file sent to error, should be not be uploaded alone)
# generate netcdf version of txt file.Set path to storage based on txt file name
# archive original txt file
# push to S3
# $1 - txt file
handle_txt_file() {
  local file=$1; shift
  log_info "Handling SOOP CO2 RT file '$file'"
  local checks='cf imos:1.4'
  local path
  path=`$SCRIPTPATH/dest_path.py $file`

  if [ $? -ne 0 ] || [ x"$path" = x ]; then
    file_error "Could not evaluate path for '$file'"
  fi
  # generate netcdf file with full path
  nc_file=`$SCRIPTPATH/create_CO2_netcdf_from_txt.py $file`
  if [ $? -ne 0 ] || [ x"$nc_file" = x ]; then
    file_error "Error creating a netcdf from '$file'"
  fi

  local tmp_file_with_sig
  tmp_file_with_sig=`trigger_checkers_and_add_signature $nc_file $BACKUP_RECIPIENT $checks`
  if [ $? -ne 0 ]; then
    file_error "Error in NetCDF checking"
    rm -f  $tmp_nc_file_with_sig
  fi

  s3_put $tmp_file_with_sig $path/`basename $nc_file`

  # archive original file
  move_to_archive $file $path
}

# handles a single netcdf file, return path in which file is stored
# $1 - netcdf file
handle_netcdf_file() {
  local file=$1; shift

  log_info "Handling SOOP CO2 file '$file'"

  echo "" | notify_by_email $BACKUP_RECIPIENT "Processing new underway CO2 file "`basename $file`

  local tmp_file_with_sig
  local checks

  if is_imos_soop_co2_file $file; then
    checks='cf imos:1.4'
  elif is_future_reef_map_file $file; then
    checks='cf'
  else
    file_error_and_report_to_uploader $BACKUP_RECIPIENT "Not an underway CO2 file "`basename $file`
  fi

  tmp_file_with_sig=`trigger_checkers_and_add_signature $file $BACKUP_RECIPIENT $checks`
  if [ $? -ne 0 ]; then
    file_error "Error in NetCDF checking"
    rm -f  $tmp_nc_file_with_sig
  fi

  log_info "TMP file '$tmp_file_with_sig'"
  local path
  path=`$SCRIPTPATH/dest_path.py $file` || file_error "Cannot generate path for "`basename $file`

  s3_put $tmp_file_with_sig $path/`basename $file` 1>/dev/null

  notify_recipients "Successfully published SOOP_CO2 voyage '$path'"
  echo $path
}

# handle a soop_co2 zip bundle
# $1 - zip file bundle
handle_zip_file() {
  local file=$1; shift
  log_info "Handling SOOP CO2 zip file '$file'"

  echo "" | notify_by_email $BACKUP_RECIPIENT "Processing new underway CO2 zip file '$file'"

  local tmp_dir=`mktemp -d`
  chmod a+rx $tmp_dir
  local tmp_zip_manifest=`mktemp`

  unzip_file $file $tmp_dir $tmp_zip_manifest
  if [ $? -ne 0 ]; then
    rm -f $tmp_zip_manifest
    rm -rf --preserve-root $tmp_dir
    file_error_and_report_to_uploader  $BACKUP_RECIPIENT "Error unzipping file "`basename $file`
  fi

  local nc_file
  nc_file=`grep ".*\.nc" $tmp_zip_manifest | head -1`
  if [ $? -ne 0 ]; then
    rm -f $tmp_zip_manifest
    rm -rf --preserve-root $tmp_dir
    file_error_and_report_to_uploader $BACKUP_RECIPIENT "Cannot find NetCDF file in zip bundle "`basename $file`
  fi

  log_info "Processing '$nc_file'"

  local path_to_storage
  path_to_storage=`handle_netcdf_file $tmp_dir/$nc_file`

  if is_valid_path $path_to_storage; then
    local extracted_file
    for extracted_file in `cat $tmp_zip_manifest`; do
      local file_basename=`basename $extracted_file`

      if ! has_extension $file_basename "nc"; then
        s3_put_no_index $tmp_dir/$extracted_file $path_to_storage/$file_basename
      fi
    done
  else
    file_error "Cannot generate path for `basename $nc_file`"
  fi
  rm -f $file # remove zip file
  #Dangerous, but necessary, since there might be a hierarchy in the zip file provided
  rm -rf --preserve-root $tmp_dir
}

# main
# $1 - file to handle
# pipeline handling either:
# 1-process zip file containing data file (.nc) , txt, doc or xml files
# script handles new and reprocessed files
# 2-process single delayed mode netcdf file
# 3-process realtime txt files
main() {
  local file=$1; shift

  if has_extension $file "zip"; then
    handle_zip_file $file
  elif has_extension $file "nc"; then
    handle_netcdf_file $file
  elif has_extension $file "txt"; then
    handle_txt_file $file
  else
    file_error $BACKUP_RECIPIENT "Unknown file extension "`basename $file`
  fi
}

main "$@"
