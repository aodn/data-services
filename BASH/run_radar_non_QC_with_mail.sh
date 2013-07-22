#!/bin/bash

./radar_non_QC.sh &> ./radar_non_QC.log
mailx -s '<ggalibert@imos-5> $ACORN_EXP/BASH/radar_non_QC.sh' -c sebastien.mancini@utas.edu.au guillaume.galibert@utas.edu.au -q radar_non_QC.log
rm -f ./radar_non_QC.log
