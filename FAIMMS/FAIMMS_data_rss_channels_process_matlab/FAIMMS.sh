#!/bin/bash
APP_NAME=FAIMMS_DOWNLOAD
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

	done

	# launch python script
	${pythonPath} ${scriptpath}"/subroutines/FAIMMS.py" 2>&1 | tee  ${DIR}/{APP_NAME}.log ;

	#rsync between rsyncSourcePath and rsyncDestinationPath
	rsync --size-only --itemize-changes --delete-before  --stats -uhvrD  --progress ${rsyncSourcePath}/opendap/  ${rsyncDestinationPath}/ ;

	#send email of log
	#mail -s "FAIMMS current job"  ${email1} -v < /tmp/log_FAIMMS.log;
	#mail -s "FAIMMS current job"  ${email2} -v < /tmp/log_FAIMMS.log;
	

} 9>"$lockfile"
