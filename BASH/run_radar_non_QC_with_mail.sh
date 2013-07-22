#!/bin/bash

./radar_non_QC.sh &> ./radar_non_QC.log
cat ./radar_non_QC.log | tr -d '\033[?1[hl]\003[=>]' | mailx -s '<ggalibert@imos-5> $ACORN_EXP/BASH/radar_non_QC.sh' -c sebastien.mancini@utas.edu.au guillaume.galibert@utas.edu.au
rm -f ./radar_non_QC.log
