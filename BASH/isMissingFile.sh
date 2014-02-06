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
	echo "$sourceFile,MISSING"
fi

if [ -f "$sourceFile" ]; then
	echo "$sourceFile,OK"
fi
