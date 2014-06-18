#!/bin/bash

# test the number of input arguments
if [ $# -lt 2 ]
then
	echo "Usage: $0 [option] file1.nc file2.nc"
	exit
fi

if [ $# -gt 3 ]
then
        echo "Usage: $0 [option] file1.nc file2.nc"
        exit
fi

if [ $# -eq 2 ]
then
	option=""
	firstFile=$1
	secondFile=$2
else
        option=$1
        firstFile=$2
        secondFile=$3
fi

# we check that the source file exists
if [ ! -f "$firstFile" ]; then
	echo "Error: $firstFile does not exist"
	exit
fi
if [ ! -f "$secondFile" ]; then
	echo "Error: $secondFile does not exist"
	exit
fi

# separate the file name and path
firstFileName=${firstFile##*/}
firstFilePath=${firstFile%/*}
secondFileName=${secondFile##*/}
secondFilePath=${secondFile%/*}


# dump the files
#ncdump $option $firstFile > /tmp/$firstFileName.txt
#ncdump $option $secondFile > /tmp/$secondFileName.txt
#diff /tmp/$firstFileName.txt /tmp/$secondFileName.txt

# let's do it in memory rather than writing to disk
diff <(ncdump $option $firstFile) <(ncdump $option $secondFile)
