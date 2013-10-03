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

# test the file with full dump
ncdump $sourceFile &> /tmp/null
if [ $? -ne 0 ]; then # file is corrupted
	QC="corrupted"
	echo $sourceFile" is corrupted and will be deleted"
	rm $sourceFile
else
	QC="OK"

  # get the date_created global attribute out of the full dump
  metaDate=`ncdump $sourceFile | grep -E -i ":date_created = " | cut -f 2 -d '"'`
	
	# we check if any current file exists
	currentFile=`echo $path"/"$ncCollidedName`
	if [ ! -f "$currentFile" ]; then
		# we can rename collided file
		echo $sourceFile" is copied"
		mv $sourceFile $currentFile
	else
		# let's read current file created_date attribute
		currentMetaDate=`ncdump $currentFile | grep -E -i ":date_created = " | cut -f 2 -d '"'`
		
		sourceNoDate=0
		if [ "$metaDate" == "+%s" ]; then
		  echo "Warning: "$sourceFile" doesn't have any date_created global attribute"
		  sourceNoDate=1
		fi
		
		currentNoDate=0
		if [ "$currentMetaDate" == "+%s" ]; then
		  echo "Warning: "$currentFile" doesn't have any date_created global attribute"
		  currentNoDate=1
		fi
		
		if [[ $sourceNoDate -eq 1 || $currentNoDate -eq 1 ]]; then
		  ncDiff.sh $sourceFile $currentFile
		  exit
		fi
		
		if [ "${metaDate:19:1}" != "Z" ]; then
	    metaDate=$metaDate"Z"
    fi
  
		if [ "${currentMetaDate:19:1}" != "Z" ]; then
		  currentMetaDate=$currentMetaDate"Z"
		fi
		
		# we can now compare the 2 dates
		nSecCollided=`date -d $metaDate +%s`
		nSecCurrent=`date -d $currentMetaDate +%s`
		if [ $nSecCollided -gt $nSecCurrent ]; then
			# Collided file is more recent than current file
			echo $sourceFile" is the most recent"
			mv $sourceFile $currentFile
	  elif [ $nSecCollided -eq $nSecCurrent ]; then
			# Collided files are equally recent
	    ncDiff.sh $sourceFile $currentFile &> /tmp/diff.txt
	    diffVar=`cat /tmp/diff.txt | grep "double TIME(TIME) ;"`
	    
	    if [ -z "$diffVar" ]; then # diffVar is empty
	      echo "Warning: "$sourceFile" and "$currentFile" are equally recent"
	      cat /tmp/diff.txt
	    else
	      if [ "${diffVar:0:1}" == "<" ]; then
          echo $sourceFile" is the best to keep"
    			mv $sourceFile $currentFile
	      elif [ "${diffVar:0:1}" == ">" ]; then
          echo $sourceFile" is not the best to keep"
    			rm $sourceFile
	      else
	        echo "Warning: "$sourceFile" and "$currentFile" are equally recent"
	        cat /tmp/diff.txt
        fi
	    fi
		else
		  echo $sourceFile" is the less recent"
			rm $sourceFile
		fi
	fi
fi
