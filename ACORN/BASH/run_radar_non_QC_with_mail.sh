#!/bin/bash

# test the number of input arguments
if [ $# -ne 6 ]
then
	echo "Usage: $0 \"{'WERA_SITE_CODE', ...}\" \"'yyymmddTHH3000'\" \"'yyymmddTHH3000'\" \"{'CODAR_SITE_CODE', ...}\" \"'yyymmddTHH0000'\" \"'yyymmddTHH0000'\""
	exit
fi

# Need to set the environment variables relevant for data_services jobs
source /home/ggalibert/DEFAULT_PATH.env
source /home/ggalibert/STORAGE.env

logFile=$DATA/ACORN/radar_non_QC-$$.log
./radar_non_QC.sh "$1" "$2" "$3" "$4" "$5" "$6" &> $logFile
cat $logFile | mailx -s '<ggalibert@imos-5> $ACORN_EXP/BASH/radar_non_QC.sh' -c sebastien.mancini@utas.edu.au guillaume.galibert@utas.edu.au
rm -f $logFile
