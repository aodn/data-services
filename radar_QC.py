#!/bin/env python
# -*- coding: utf-8 -*-
import os,sys

if __name__ == "__main__":

    os.system("$ACORN_EXP/BASH/setEnvACORN.sh")

    try:
        os.system("matlab -nodisplay -r  \"cd(getenv('ACORN_EXP')); addpath(fullfile('.', 'Util')); acorn_summary('WERA', true); exit\"")
    except Exception, e:
        print ("ERROR: " + str(e))
        sys.exit()
       
    os.system("rsync -vaR --remove-source-files $DATA/ACORN/WERA/radial_QC/output/datafabric/gridded_1havg_currentmap_QC/./ $OPENDAP/ACORN/gridded_1h-avg-current-map_QC/")
