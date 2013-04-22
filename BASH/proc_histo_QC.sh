#!/bin/bash
cp -p configCBG.txt config.txt
python radar_QC.py > CBG_QC_backlog.txt
#cp -p configSAG.txt config.txt
#python radar_QC.py >> SAG_QC_backlog.txt
#cp -p configROT.txt config.txt
#python radar_QC.py > ROT_QC_backlog.txt
#cp -p configCOF.txt config.txt
#python radar_QC.py > COF_QC_backlog.txt
