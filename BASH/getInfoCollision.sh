#!/bin/bash

# test the number of input arguments
if [ $# -ne 1 ]
then
	echo "Usage: $0 file"
	exit
fi

sourceFile=$1

# we check that the source file exists
if [ ! -f "$sourceFile" ]; then
	echo "Error in $0 : file $sourceFile does not exist"
	exit
fi

# separate the file name and path
ncName=${sourceFile##*/}
path=${sourceFile%/*}

# separate the collided file name and MD5 checksum
ncMD5=${ncName##*.}
ncCollidedName=${ncName%.*}

# get the date_created global attribute out of the full dump
metaDate=`ncdump $sourceFile | grep -E -i ":date_created = " | cut -f 2 -d '"'`
if [ $? -ne 0 ]; then # file is corrupted
	QC="corrupted"
else
	QC="OK"
fi

printf "$ncCollidedName\t$ncMD5\t$metaDate\t$QC\n"
