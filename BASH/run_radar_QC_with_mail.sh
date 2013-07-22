#!/bin/bash

./radar_QC.sh &> ./radar_QC.log
cat ./radar_QC.log | mailx -s '<ggalibert@imos-5> $ACORN_EXP/BASH/radar_QC.sh' -c sebastien.mancini@utas.edu.au guillaume.galibert@utas.edu.au
#rm -f ./radar_QC.log
