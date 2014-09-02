#!/bin/bash

# test the number of input arguments
if [ $# -lt 1 ]
then
	echo "Usage: $0 nc_file [list_file]"
	exit
fi

sourceFile=$1

# we check that the source file exists
if [ ! -f "$sourceFile" ]; then
	echo "Error in $0: file $sourceFile does not exist"
	exit
fi

# extract file name
ncName=${sourceFile##*/}

# check for a corrupted file that would make ncdump fail
output=`ncdump $sourceFile &> /dev/null`
if [ $? -ne 0 ]; then # file is corrupted
	rsync -aq --remove-source-files $sourceFile $ARCHIVE/ACORN/corrupted/
	if [ $? -eq 0 ]; then # rsync successful
		echo "Corrupted file $sourceFile moved to $ARCHIVE/ACORN/corrupted/"
	else
		echo "Corrupted file $sourceFile could not be moved to $ARCHIVE/ACORN/corrupted/"
	fi
	if [ $# -gt 1 ]; then
		listFile=$2
		echo $ncName >> $listFile
	fi
fi
