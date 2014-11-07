#!/bin/bash
APP_NAME=SOOP_TRV_AIMS
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

		if [[ "${name[jj]}" =~ "email1.log" ]] ; then
			 email1=${value[jj]} ;    
		fi

		if [[ "${name[jj]}" =~ "email2.log" ]] ; then
			 email2=${value[jj]} ;    
		fi

		if [[ "${name[jj]}" =~ "python.path" ]] ; then
			 pythonPath=${value[jj]} ;    
		fi

		if [[ "${name[jj]}" =~ "logFile.name" ]] ; then
			 logfileName=${value[jj]} ;    
		fi
	done

	# launch python script
	${pythonPath} ${scriptpath}"/subroutines/SOOP_TRV.py" 2>&1 | tee  ${DIR}/${logfileName}

	#send email of log
	#mail -s "SOOP TRV current job"  ${email1} -v < /tmp/log_SOOP_TRV.log;
	#mail -s "SOOP TRV current job"  ${email2} -v < /tmp/log_SOOP_TRV.log;
	
fi
} 9>"$lockfile"
