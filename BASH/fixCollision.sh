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
	echo "Error in $0 $1: file $sourceFile does not exist"
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
	echo "file "$sourceFile" is corrupted"
	rm -v $sourceFile
else
	QC="OK"
	# we check if any current file exists
	currentFile=`echo $path"/"$ncCollidedName`
	if [ ! -f "$currentFile" ]; then
		# we can rename collided file
		mv -v $sourceFile $currentFile
	else
		# let's read current file created_date attribute
		currentMetaDate=`ncdump $currentFile | grep -E -i ":date_created = " | cut -f 2 -d '"'`
		
		# we can now compare the 2 dates
		nSecCollided=`date -d $metaDate +%s`
		nSecCurrent=`date -d $currentMetaDate +%s`
		if [ $nSecCollided -gt $nSecCurrent ]; then
			# Collided file is more recent than current file
			echo "file "$sourceFile" is the most recent: "$nSecCollided" > "$nSecCurrent
			mv -v $sourceFile $currentFile
		else
			rm -v $sourceFile
		fi
	fi
fi
