#!/bin/bash

# test the number of input arguments
if [ $# -ne 1 ]
then
  echo "Usage: $0 pathToFolder"
  exit
fi

tic=$(date +%s.%N)

# we make sure we retrieve a full path
if [ "${1:0:1}" = "/" ]
then
	pathToFolder=$1
else
	pathToFolder=`pwd`"/"$1
fi
if [ "${pathToFolder:${#pathToFolder}-1:${#pathToFolder}}" = "/" ]
then
	pathToFolder=${pathToFolder:0:${#pathToFolder}-1}
fi

# deletes the shortest match of '/' from front of pathToFolder
folder=${pathToFolder##*\/}

# list of files
find $pathToFolder -type f -name '*.nc' -print0 > $pathToFolder"/ncConcatFolder.$$.tee" 

toc=$(date +%s.%N)

printf "%6.1Fs\t$pathToFolder/*.nc files listed\n"  $(echo "$toc - $tic"|bc )

# we make sure target NetCDF files have a TIME record dimension unlimited
#tic=$(date +%s.%N)
#
#cat $pathToFolder"/ncConcatFolder.$$.tee" | xargs -0 -I {} prepareForConcat.sh {}
#
#toc=$(date +%s.%N)
#
#printf "%6.1Fs\t$pathToFolder ready to be concatenated\n"  $(echo "$toc - $tic"|bc )

tic=$(date +%s.%N)

# convert the tee into a list of files (we have to sort the files alphabetically to make sure TIME will be sorted
# because find provides a random list of files)
cat $pathToFolder"/ncConcatFolder.$$.tee" | xargs -0 -I {} echo {} | sort | tr '\n' ' ' > $pathToFolder"/ncConcatFolder.$$.list"

# concatenate the list of files
ncrcat -h -O `cat $pathToFolder"/ncConcatFolder.$$.list"` "$pathToFolder.nc"

# clean temporary files
rm -f $pathToFolder"/ncConcatFolder.$$.tee" $pathToFolder"/ncConcatFolder.$$.list"

toc=$(date +%s.%N)

printf "%6.1Fs\t$pathToFolder concatenated\n"  $(echo "$toc - $tic"|bc )
