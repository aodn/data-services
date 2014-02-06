#!/bin/bash

# test the number of input arguments
if [ $# -ne 2 ]
then
	echo "Usage: $0 file1.nc file2.nc"
	exit
fi

firstFile=$1
secondFile=$2

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
ncdump $firstFile > /tmp/$firstFileName.txt
ncdump $secondFile > /tmp/$secondFileName.txt
diff /tmp/$firstFileName.txt /tmp/$secondFileName.txt
