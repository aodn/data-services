#!/bin/bash

# test the number of input arguments
if [ $# -ne 1 ]
then
	echo "Usage: $0 nc_file"
	exit
fi

sourceFile=$1

# we check that the source file exists
if [ ! -f "$sourceFile" ]; then
	echo "Error in $0 $1: file $sourceFile does not exist"
	exit
fi

# check for a corrupted file that would make ncdump fail
output=`ncdump $sourceFile &> /dev/null`
if [ $? -ne 0 ]; then # file is corrupted
	echo "Corrupted file $sourceFile deleted"
fi
