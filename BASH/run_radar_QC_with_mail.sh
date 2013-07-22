#!/bin/bash

./radar_QC.sh 2>&1 ./radar_non_QC.log
mailx -S encoding=8bit -s '<ggalibert@imos-5> $ACORN_EXP/BASH/radar_QC.sh' -c sebastien.mancini@utas.edu.au guillaume.galibert@utas.edu.au -q radar_non_QC.log
rm -f ./radar_non_QC.log
