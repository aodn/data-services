#!/bin/bash
#to call the script, either ./main.sh XBT  or ./main.sh ASF_SST
APP_NAME=SOOP_SST_ASF_XBT
DIR=/tmp
lockfile=${DIR}/${APP_NAME}.lock
{
  if ! flock -n 9
  then
    echo "Program already running. Unable to lock $lockfile, exiting" 2>&1
    exit 1
  fi


    #get the path of the directory in which a bash script is located FROM that bash script
    #should work all the time
    DIR_SCRIPT=$(dirname $(readlink -f "$0"))

    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games
    echo START PROGRAM

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

        # XBT
        if [[ "${name[jj]}" =~ "temporaryDataFolderSorted_XBT.path" ]] ; then
             temporaryDataFolderSorted_XBT=${value[jj]} ;
        fi

        if [[ "${name[jj]}" =~ "destinationProductionDataPublicSOOP_XBT.path" ]] ; then
             destinationProductionDataPublicSOOP_XBT=${value[jj]} ;
        fi

        if [[ "${name[jj]}" =~ "logFileXBT.name" ]] ; then
             logfileNameXBT=${value[jj]} ;
        fi


        # ASF SST
        if [[ "${name[jj]}" =~ "temporaryDataFolderSorted_ASF_SST.path" ]] ; then
             temporaryDataFolderSorted_ASF_SST=${value[jj]} ;
        fi
        if [[ "${name[jj]}" =~ "destinationProductionDataOpendapSOOP_ASF_SST.path" ]] ; then
             destinationProductionDataOpendapSOOP_ASF_SST=${value[jj]} ;
        fi

        if [[ "${name[jj]}" =~ "logFileASF_SST.path" ]] ; then
             logFileASF_SST=${value[jj]} ;
        fi



    done

    echo "$1"
    if [[ "$1" == "XBT" ]] ; then
        echo PROCESS XBT
        # launch python script to process XBT data
        python ${scriptpath}"/SOOP_XBT_RT.py" 2>&1 | tee  ${DIR}/${APP_NAME}".log1"

        # rsync data between rsyncSourcePath and rsyncDestinationPath
        rsyncSourcePath=$temporaryDataFolderSorted_XBT
        rsync  --itemize-changes  --stats -azhvrD --remove-source-files --progress ${rsyncSourcePath}/  ${destinationProductionDataPublicSOOP_XBT}/ ;
    fi

    if [[ "$1"  == "ASF_SST" ]] ; then
        echo PROCESS ASF SST
        python ${scriptpath}"/SOOP_BOM_ASF_SST.py" 2>&1 | tee  ${DIR}/${APP_NAME}".log2"

        # rsync data between rsyncSourcePath and rsyncDestinationPath
        rsyncSourcePath=$temporaryDataFolderSorted_ASF_SST
        rsync  --itemize-changes  --stats -azhvrD --remove-source-files  --progress ${rsyncSourcePath}/  ${destinationProductionDataOpendapSOOP_ASF_SST}/ ;
    fi

} 9>"$lockfile"
