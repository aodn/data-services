#!/bin/bash
export LOGNAME
export HOME
export PATH

APP_NAME='AATAMS_SATTAG_DM'
DIR=/tmp
lockfile=${DIR}/$APP_NAME.lock
{
  if ! flock -n 9
  then
    echo "Program already running. Unable to lock $lockfile, exiting" 2>&1
    exit 1
  fi


    #should work all the time - looks for the location of this script
    DIR_SCRIPT=$(dirname $(readlink -f "$0"))

   #ALL ENV VARIABLES . No yet fully used in this version
   # check if env variables exists. Else, export default value   MyVariable=${MyVariable:=SomeDefault}
   # OPENDAP_DIR=${OPENDAP_DIR:='/mnt/opendap'}                                #OpenDAP
   # PUBLIC_DIR=${PUBLIC_DIR:='/mnt/imos-t4/IMOS/public'}                      #Public
   # ARCHIVE_DIR=${ARCHIVE_DIR:='/mnt/imos-t4/IMOS/archive'}                   #Archive
   # INCOMING_DIR=${INCOMING_DIR:='/mnt/imos-t4/IMOS/staging'}                 #Incoming
   # OPENDAP_IMOS_DIR=${OPENDAP_IMOS_DIR:="$OPENDAP_DIR/1/IMOS/opendap"}       #IMOS OpenDAP
   # PUBLIC_IMOS_DIR=${PUBLIC_IMOS_DIR:="$PUBLIC_DIR"}                         #IMOS public
   # ARCHIVE_IMOS_DIR=${ARCHIVE_IMOS_DIR:="$ARCHIVE_DIR"}                      #IMOS archive
   # WIP_DIR=${WIP_DIR:='/tmp/wip'}                                            #Work In Progress tmp dir
   # DATA_SERVICES_DIR=${DATA_SERVICES_DIR:="$PWD"}                            #Where this git repo is deployed
   # LOG_DIR=${LOG_DIR:='/tmp/log'}                                            #Designated log dir

    
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
             scriptPath=${value[jj]} ;    
        fi


        if [[ "${name[jj]}" =~ "dataWIP.path" ]] ; then
             dataWIPPath=${value[jj]} ;    
        fi


        if [[ "${name[jj]}" =~ "australianTags.filepath" ]] ; then
             australianTagsFilePath=${value[jj]} ;    
        fi


        if [[ "${name[jj]}" =~ "dataDestination.path" ]] ; then
             dataDestinationPath=${value[jj]} ;
        fi

    done

    matlab -nodisplay -r "run  ('"${scriptPath}"/aatams_sattag_dm_main.m');exit;"  2>&1 | tee  ${DIR}/${APP_NAME}.log ;


    # remove empty directories see http://unix.stackexchange.com/questions/8430/how-to-remove-all-empty-directories-in-a-subtree
     if [ -d "$dataWIPPATH" ]; then
         while [ -n "$(find $dataWIPPath -depth -type d -empty -print -exec rmdir {} +)" ]; do :; done
     fi

    # rsync data between rsyncSourcePath and rsyncDestinationPath
    rsyncSourcePath=$dataWIPPath
    rsync --dry-run --size-only --itemize-changes --delete-before  --stats -uhvrD  --progress ${rsyncSourcePath}/NETCDF/  ${dataDestinationPath}/ ;


} 9>"$lockfile"
