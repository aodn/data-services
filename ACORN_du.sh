#!/bin/bash
echo "disk usage"
cd ~/df_root_irods/opendap/ACORN/
du -hc --max-depth=3 *

# recursive find doesn't work on irods
cd ~/df_root/opendap/ACORN/
echo "number of files in gridded_1h-avg-current-map_non-QC"
cd gridded_1h-avg-current-map_non-QC
cd BONC
pwd
find . -type f | wc -l
cd ../CBG
pwd
find . -type f | wc -l
cd ../COF
pwd
find . -type f | wc -l
cd ../PCY
pwd
find . -type f | wc -l
cd ../ROT
pwd
find . -type f | wc -l
cd ../SAG
pwd
find . -type f | wc -l
cd ../TURQ
pwd
find . -type f | wc -l

echo "number of files in gridded_1h-avg-current-map_QC"
cd ../../gridded_1h-avg-current-map_QC
cd CBG
pwd
find . -type f | wc -l
cd ../COF
pwd
find . -type f | wc -l
cd ../ROT
pwd
find . -type f | wc -l
cd ../SAG
pwd
find . -type f | wc -l

echo "number of files in monthly_gridded_1h-avg-current-map_non-QC"
cd ../../monthly_gridded_1h-avg-current-map_non-QC
cd CBG
pwd
find . -type f | wc -l
cd ../COF
pwd
find . -type f | wc -l
cd ../ROT
pwd
find . -type f | wc -l
cd ../SAG
pwd
find . -type f | wc -l

echo "number of files in radial"
cd ../../radial
cd BFCV
pwd
find . -type f | wc -l
cd ../CRVT
pwd
find . -type f | wc -l
cd ../CSP
pwd
find . -type f | wc -l
cd ../CWI
pwd
find . -type f | wc -l
cd ../FRE
pwd
find . -type f | wc -l
cd ../GUI
pwd
find . -type f | wc -l
cd ../LEI
pwd
find . -type f | wc -l
cd ../LTN
pwd
find . -type f | wc -l
cd ../NNB
pwd
find . -type f | wc -l
cd ../NOCR
pwd
find . -type f | wc -l
cd ../RRK
pwd
find . -type f | wc -l
cd ../SBRD
pwd
find . -type f | wc -l
cd ../TAN
pwd
find . -type f | wc -l

echo "number of files in radial_quality_controlled"
cd ../../radial_quality_controlled
cd CRVT
pwd
find . -type f | wc -l
cd ../CSP
pwd
find . -type f | wc -l
cd ../CWI
pwd
find . -type f | wc -l
cd ../FRE
pwd
find . -type f | wc -l
cd ../GUI
pwd
find . -type f | wc -l
cd ../LEI
pwd
find . -type f | wc -l
cd ../NNB
pwd
find . -type f | wc -l
cd ../RRK
pwd
find . -type f | wc -l
cd ../TAN
pwd
find . -type f | wc -l

echo "number of files in sea-state"
cd ../../sea-state
cd BONC
pwd
find . -type f | wc -l
cd ../TURQ
pwd
find . -type f | wc -l