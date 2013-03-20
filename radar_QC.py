#!/bin/env python
# -*- coding: utf-8 -*-
import os,sys

if __name__ == "__main__":

    try:
        os.system("/usr/local/bin/matlab -nodisplay -r  \"cd '/usr/local/bin/ACORN/exp/trunk'; addpath(fullfile('.', 'Util')); acorn_summary('WERA', true); exit\"")
    except Exception, e:
        print ("ERROR: " + str(e))
        sys.exit()
       
    os.system("/usr/bin/rsync -vaR --remove-source-files /home/ggalibert/DATA/ACORN/WERA/radial_QC/output/datafabric/gridded_1havg_currentmap_QC/./ /mnt/imos-t3/IMOS/opendap/ACORN/gridded_1h-avg-current-map_QC/")