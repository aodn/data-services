#!/bin/bash

# test the number of input arguments
if [ $# -ne 6 ]
then
	echo "Usage: $0 \"{'WERA_SITE_CODE', ...}\" \"'yyyymmddTHH3000'\" \"'yyyymmddTHH3000'\" \"{'CODAR_SITE_CODE', ...}\" \"'yyyymmddTHH0000'\" \"'yyyymmddTHH0000'\""
	exit
fi

# Need to set the environment variables relevant for data_services jobs
source /home/ggalibert/DEFAULT_PATH.env
source /home/ggalibert/STORAGE.env

# run the job
logFile=$DATA/ACORN/radar_non_QC-$$.log
./radar_non_QC.sh "$1" "$2" "$3" "$4" "$5" "$6" &> $logFile

# check the log file size before sending the mail
maxFileSize=8000000 
actualFileSize=$(wc -c "$logFile" | cut -d ' ' -f 1)
if [ $actualFileSize -ge $maxFileSize ]; then
        gzip $logFile
	echo "See log file attached." | mailx -s '<ggalibert@imos-5> $DATA_SERVICES_DIR/ACORN/BASH/radar_non_QC.sh' -a "$logFile".gz -c sebastien.mancini@utas.edu.au guillaume.galibert@utas.edu.au
else
	cat $logFile | mailx -s '<ggalibert@imos-5> $DATA_SERVICES_DIR/ACORN/BASH/radar_non_QC.sh' -c sebastien.mancini@utas.edu.au guillaume.galibert@utas.edu.au
fi

# if mail is successful we can delete the logfile
if [ $? -eq 0 ]; then
	rm -f $logFile "$logFile".gz
fi
