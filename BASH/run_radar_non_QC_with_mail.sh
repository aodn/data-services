#!/bin/bash

radar_non_QC.sh 2>&1 | mailx -s '<ggalibert@imos-5> $ACORN_EXP/BASH/radar_non_QC.sh' -c sebastien.mancini@utas.edu.au guillaume.galibert@utas.edu.au
