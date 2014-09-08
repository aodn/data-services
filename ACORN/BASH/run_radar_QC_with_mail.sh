#!/bin/bash

# test the number of input arguments
if [ $# -ne 3 ]
then
	echo "Usage: $0 \"{'WERA_SITE_CODE', ...}\" \"'yyymmddTHH3000'\" \"'yyymmddTHH3000'\""
	exit
fi

./radar_QC.sh "$1" "$2" "$3" &> ./radar_QC-$$.log
cat ./radar_QC-$$.log | mailx -s '<ggalibert@imos-5> $ACORN_EXP/BASH/radar_QC.sh' -c sebastien.mancini@utas.edu.au guillaume.galibert@utas.edu.au
rm -f ./radar_QC-$$.log
