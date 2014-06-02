#!/bin/bash
#touchfile to be sure the program is not runned twice at the same time
touchfile=/tmp/running_AUV.log

#get the path of the directory in which a bash script is located FROM that bash script
#does not work with symbolic link
#DIR_SCRIPT="$( cd "$( dirname "$0" )" && pwd )"

#should work all the time
DIR_SCRIPT=$(dirname $(readlink -f "$0"))


if [ -e $touchfile ]; then 
	echo PROGRAM ALREADY RUNNING. Otherwise, please delete $touchfile 
	exit
else
   	echo START PROGRAM
   	touch $touchfile

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

	done

	# launch python script
	${pythonPath} ${scriptpath}"/subroutines/AUV.py" 2>&1 | tee  /tmp/log_AUV.log

	#send email of log
	mail -s "AUV current job"  ${email1} -v < /tmp/log_AUV.log;
	mail -s "AUV current job"  ${email2} -v < /tmp/log_AUV.log;
	rm $touchfile
fi