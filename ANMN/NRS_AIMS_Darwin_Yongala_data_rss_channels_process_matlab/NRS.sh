#!/bin/bash
APP_NAME=ANMN_NRS_DAR_YON_DOWNLOAD
DIR=/tmp
lockfile=${DIR}/${APP_NAME}.lock
{
  if ! flock -n 9
  then
    echo "Program already running. Unable to lock $lockfile, exiting" 2>&1
    exit 1
  fi



    #get the path of the directory in which a bash script is located FROM that bash script
    #does not work with symbolic link
    #DIR_SCRIPT="$( cd "$( dirname "$0" )" && pwd )"

    #should work all the time
    DIR_SCRIPT=$(dirname $(readlink -f "$0"))

    echo START PROGRAM

    ## this part of the code reads  the config.txt
    configfile=${DIR_SCRIPT}/config.txt

    ii=0
    while read line; do
    if [[ "$line" =~ ^[^#]*= ]]; then
            #http://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-bash-variable
            name[ii]=`echo $line | cut -d'=' -f 1 | sed -e 's/^ *//' -e 's/ *$//'`
            value[ii]=`echo $line | cut -d'=' -f 2- | sed -e 's/^ *//' -e 's/ *$//'`
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

        if [[ "${name[jj]}" =~ "dataOpendapRsync.path" ]] ; then
                 rsyncSourcePath=${value[jj]} ;
        fi

        if [[ "${name[jj]}" =~ "destinationProductionData.path" ]] ; then
                rsyncDestinationPath=${value[jj]} ;
        fi


        if [[ "${name[jj]}" =~ "siteDAR.name" ]] ; then
             siteDAR=${value[jj]} ;    
        fi


        if [[ "${name[jj]}" =~ "siteYON.name" ]] ; then
             siteYON=${value[jj]} ;    
        fi

    done

    # launch python script
    ${pythonPath} ${scriptpath}"/subroutines/NRS.py" 2>&1 | tee  /tmp/log_NRS.log

    #rsync between rsyncSourcePath and rsyncDestinationPath
    rsync --size-only --itemize-changes --delete-before  --stats -uhvrD  --progress ${rsyncSourcePath}/opendap/${siteDAR}/ ${rsyncDestinationPath}/${siteDAR}/ ;
    rsync --size-only --itemize-changes --delete-before  --stats -uhvrD  --progress ${rsyncSourcePath}/opendap/${siteYON}/ ${rsyncDestinationPath}/${siteYON}/ ;
    #send email of log
    #mail -s "NRS current job"  ${email1} -v < /tmp/log_NRS.log;
    #mail -s "NRS current job"  ${email2} -v < /tmp/log_NRS.log;

} 9>"$lockfile"
