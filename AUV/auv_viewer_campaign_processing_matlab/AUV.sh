#!/bin/bash
APP_NAME=AUV_VIEWER_DATA_PROCESS
DIR=/tmp
lockfile=${DIR}/${APP_NAME}.lock
{
  if ! flock -n 9
  then
    echo "Program already running. Unable to lock $lockfile, exiting" 2>&1
    exit 1
  fi


    #should work all the time
    DIR_SCRIPT=$(dirname $(readlink -f "$0"))


    ## this part of the code reads  the config.txt
    configfile=${DIR_SCRIPT}/config.txt

    ii=0
    while read line; do
    if [[ "$line" =~ ^[^#]*= ]]; then
            name[ii]=`echo $line | cut -d'=' -f 1`
                value[ii]=`echo $line | cut -d'=' -f 2-`
            ((ii++))
    fi
    done <$configfile

    # this part of the code finds the script.path value in the config.txt
    for (( jj = 0 ; jj < ${#value[@]} ; jj++ ));
    do
        if [[ "${name[jj]}" =~ "script.path" ]] ; then
             scriptpath=${value[jj]} ;
        fi

        if [[ "${name[jj]}" =~ "email1.log" ]] ; then
             email1=${value[jj]} ;
        fi

        if [[ "${name[jj]}" =~ "email2.log" ]] ; then
             email2=${value[jj]} ; 
        fi

        if [[ "${name[jj]}" =~ "python.path" ]] ; then
             pythonPath=${value[jj]} ;
        fi

        if [[ "${name[jj]}" =~ "auvViewerThumbnails.path" ]] ; then
             auvViewerThumbnailsPath=${value[jj]} ;
        fi

        if [[ "${name[jj]}" =~ "auvCSVOutput.path" ]] ; then
             auvCSVOutputPath=${value[jj]} ;
        fi

        if [[ "${name[jj]}" =~ "releasedCampaignOpendap.path" ]] ; then
             releasedCampaignOpendapPath=${value[jj]} ;
        fi

        if [[ "${name[jj]}" =~ "processedDataOutput.path" ]] ; then
             processedDataOutputPath=${value[jj]} ;
        fi
    done

    # launch python script
    ${pythonPath} ${scriptpath}"/subroutines/AUV.py" 2>&1 | tee  /tmp/log_AUV.log

    #rsync netcdf files from public to opendap see http://silentorbit.com/notes/2013/08/rsync-by-extension/
    rsync --size-only --itemize-changes --stats -vaR   --exclude='*.log' --prune-empty-dirs ${releasedCampaignPath}/./*/*/hydro_netcdf  ${releasedCampaignOpendap}/;
    #rsync --dry-run  --itemize-changes --stats  -vrD  --progress --include '*.nc' --include '*/**/hydro_netcdf'  --exclude='*.log' --prune-empty-dirs  -e ${releasedCampaignPath}/ ${releasedCampaignOpendap}/;


    #rsync images from WIP to thumbnails and remove from WIP
    rsync --size-only --itemize-changes --stats   --progress --remove-source-files -vrD --relative -a --prune-empty-dirs  ${processedDataOutputPath}/./*/*/i2jpg ${auvViewerThumbnailsPath}/;
    #rsync --dry-run --size-only --itemize-changes --stats   --progress --remove-source-files -vrD -a  --include="*/" --include="*.jpg" --exclude="*" --prune-empty-dirs  ${processedDataOutputPath}/ ${auvViewerThumbnailsPath}/;


    #rsync csv outputs used by talend from WIP to private
    rsync  --size-only --itemize-changes --stats   --progress -vrD  -a --exclude i2jpg/   --include '*.csv' --exclude '*.mat' --exclude '*.txt' --prune-empty-dirs  ${processedDataOutputPath}/ ${auvCSVOutputPath}/;


} 9>"$lockfile"
