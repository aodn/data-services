#!/bin/env python
# -*- coding: utf-8 -*-
import os,sys
import DatafabricConnection,folderCopier

if __name__ == "__main__":

    df = DatafabricConnection.DatafabricConnection()

    if df.isDfMounted():
       print "Connected to the datafabric"
       try:
           os.system("/usr/local/bin/matlab -nodisplay -r  \"cd '/usr/local/bin/ACORN/exp/trunk'; addpath(fullfile('.', 'Util')); acorn_summary('WERA', false); acorn_summary('CODAR', false); exit\"")
       except Exception, e:
           print ("ERROR: " + str(e))
           sys.exit()
       
       f = folderCopier.folderCopier()

       f.processFiles("/var/lib/matlab_3/ACORN/WERA/radial_nonQC/output/datafabric/gridded_1havg_currentmap_nonQC/CBG/2012", "/home/matlab_3/df_root/opendap/ACORN/gridded_1h-avg-current-map_non-QC/CBG/2012", 'nc')
       f.processFiles("/var/lib/matlab_3/ACORN/WERA/radial_nonQC/output/datafabric/gridded_1havg_currentmap_nonQC/SAG/2012", "/home/matlab_3/df_root/opendap/ACORN/gridded_1h-avg-current-map_non-QC/SAG/2012", 'nc')
       f.processFiles("/var/lib/matlab_3/ACORN/WERA/radial_nonQC/output/datafabric/gridded_1havg_currentmap_nonQC/ROT/2012", "/home/matlab_3/df_root/opendap/ACORN/gridded_1h-avg-current-map_non-QC/ROT/2012", 'nc')
       f.processFiles("/var/lib/matlab_3/ACORN/WERA/radial_nonQC/output/datafabric/gridded_1havg_currentmap_nonQC/COF/2012", "/home/matlab_3/df_root/opendap/ACORN/gridded_1h-avg-current-map_non-QC/COF/2012", 'nc')
       f.processFiles("/var/lib/matlab_3/ACORN/CODAR/nonQC_gridded/output/datafabric/gridded_1havg_currentmap_nonQC/TURQ/2012", "/home/matlab_3/df_root/opendap/ACORN/gridded_1h-avg-current-map_non-QC/TURQ/2012", 'nc')
       f.processFiles("/var/lib/matlab_3/ACORN/CODAR/nonQC_gridded/output/datafabric/gridded_1havg_currentmap_nonQC/BONC/2012", "/home/matlab_3/df_root/opendap/ACORN/gridded_1h-avg-current-map_non-QC/BONC/2012", 'nc')

       f.close()
    else:
       print "Failed to connect to the datafabric so exiting."
       sys.exit()