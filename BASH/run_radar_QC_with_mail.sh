#!/bin/bash

./radar_QC.sh 2>&1 ./radar_QC.log
mailx -s '<ggalibert@imos-5> $ACORN_EXP/BASH/radar_QC.sh' -c sebastien.mancini@utas.edu.au guillaume.galibert@utas.edu.au -q radar_QC.log
rm -f ./radar_QC.log
