#!/bin/bash

# test the number of input arguments
if [ $# -ne 6 ]
then
	echo "Usage: $0 \"{'WERA_SITE_CODE', ...}\" \"'yyymmddTHH3000'\" \"'yyymmddTHH3000'\" \"{'CODAR_SITE_CODE', ...}\" \"'yyymmddTHH0000'\" \"'yyymmddTHH0000'\""
	exit
fi

./radar_non_QC.sh "$1" "$2" "$3" "$4" "$5" "$6" &> ./radar_non_QC-$$.log
cat ./radar_non_QC-$$.log | mailx -s '<ggalibert@imos-5> $ACORN_EXP/BASH/radar_non_QC.sh' -c sebastien.mancini@utas.edu.au guillaume.galibert@utas.edu.au
rm -f ./radar_non_QC-$$.log
