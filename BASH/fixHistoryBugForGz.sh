#!/bin/bash

# test the number of input arguments
if [ $# -ne 1 ]
then
  echo "Usage: $0 fileWithHistoryBug.nc.gz"
  exit
fi

tic=$(date +%s.%N)

gzPath=$1

# deletes the shortest match of '.gz' from back of gzName
ncPath=${gzPath%.gz}

# force decompress the .gz to .nc
gzip -fd $gzPath > $ncPath

# get the file name without path
ncName=${ncPath##*/}

# check for a global attribute with relevant string
metaNcVer=`ncdump -h $ncPath | grep -E -i '. Modification of the NetCDF format by eMII to visualise the data using ncWMS'`
if [ ! -z "$metaNcVer" ]; then # metaNcVer is not empty
	historyString=`echo $metaNcVer | cut -f 2 -d '"'`
	
	historyString=${historyString:0:${#historyString}-20}
	historyString="$historyString."

	# update history global attribute
	# I don't want the history global attribute to be updated
	ncatted -a history,global,m,c,"$historyString" -h $ncPath
	result="fixed"
else
	result="no need to be fixed"	
fi

# force compress the .nc to .gz
gzip -f $ncPath > $gzPath

toc=$(date +%s.%N)

printf "%6.1Fs\t$ncPath history $result\n"  $(echo "$toc - $tic"|bc )
