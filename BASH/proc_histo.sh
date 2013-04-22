#!/bin/bash
echo CBG
cp -p configCBG.txt config.txt
python radar_non_QC.py >> CBG_backlog.txt
echo SAG 
cp -p configSAG.txt config.txt
python radar_non_QC.py >> SAG_backlog.txt
echo ROT
cp -p configROT.txt config.txt
python radar_non_QC.py >> ROT_backlog.txt
echo COF
cp -p configCOF.txt config.txt
python radar_non_QC.py >> COF_backlog.txt
#echo TURQ
#cp -p configTURQ.txt config.txt
#python radar_non_QC.py >> TURQ_backlog.txt
#echo BONC
#cp -p configBONC.txt config.txt
#python radar_non_QC.py >> BONC_backlog.txt
