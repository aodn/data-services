#!/bin/bash

# fixes IMOS_ACORN_RV_20130224T0000Z_BFCV_FV00_radial.nc to IMOS_ACORN_RV_20130224T000000Z_BFCV_FV00_radial.nc
# can be called with `find . -type f -name 'IMOS_ACORN_RV_*T????Z_*.nc' -print0 | xargs -0 -I {} fixSeasondeDateFilename.sh {}`

# test the number of input arguments
if [ $# -ne 1 ]
then
  echo "Usage: $0 file"
  exit
fi

ncPath=$1

# separate the file name and path
ncName=${ncPath##*/}
path=${ncPath%/*}

ncNameLastPart=${ncName##*Z}
ncNameFirstPart=${ncName%Z*}

newNcName=$ncNameFirstPart"00Z"$ncNameLastPart
newNcPath=$path"/"$newNcName

if [ ! -f "$newNcPath" ]; then
	mv -v $ncPath $newNcPath
else
	rm -vf $ncPath
fi
