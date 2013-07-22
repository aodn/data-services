#!/bin/bash

./radar_QC.sh | awk 'sub("$", "\r")' | mailx -s '<ggalibert@imos-5> $ACORN_EXP/BASH/radar_QC.sh' -c sebastien.mancini@utas.edu.au guillaume.galibert@utas.edu.au
