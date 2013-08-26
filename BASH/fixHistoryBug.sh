#!/bin/bash

# test the number of input arguments
if [ $# -ne 1 ]
then
  echo "Usage: $0 fileWithHistoryBug.nc"
  exit
fi

tic=$(date +%s.%N)

ncPath=$1

# get the file name without path
ncName=${ncPath##*/}

# check for a global attribute with relevant string
metaNcVer=`ncdump -h $ncPath | grep -E -i '. Modification of the NetCDF format by eMII to visualise the data using ncWMS'`
if [ ! -z "$metaNcVer" ]; then # metaNcVer is not empty
	historyString=`echo "$metaNcVer" | cut -f 2 -d '"'`
	
	historyString=${historyString:0:${#historyString}-20}
	historyString="$historyString."

	# update history global attribute
	# I don't want the history global attribute to be updated
	ncatted -a history,global,m,c,"$historyString" -h $ncPath
	result="fixed"
else
	result="no need to be fixed"	
fi

toc=$(date +%s.%N)

printf "%6.1Fs\t$ncPath history $result\n"  $(echo "$toc - $tic"|bc )
