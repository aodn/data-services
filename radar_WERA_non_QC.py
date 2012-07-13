#!/bin/env python
# -*- coding: utf-8 -*-
import os,sys,threading
import DatafabricConnection,folderCopier

if __name__ == "__main__":


   
    df = DatafabricConnection.DatafabricConnection()
     
    print "Checking the datafabric.."
    if df.connectDatafabric():
       print "Datafabric now connected"
       try:
           os.system("/usr/local/bin/matlab -nodisplay -r  \"cd '/usr/local/harvesters/matlab_3/svn/acorn/trunk'; addpath(fullfile('.','Util')); acorn_summary('WERA', false)\"")
       except Exception, e:
           print ("ERROR: " + str(e))
           sys.exit()

       f = folderCopier.folderCopier()

       f.processFiles("/var/lib/matlab_3/ACORN/WERA/radial_nonQC/output/datafabric/gridded_1havg_currentmap_nonQC/CBG/2012","/home/matlab_3/df_root/opendap/ACORN/gridded_1h-avg-current-map_non-QC/CBG/2012",'nc')
       f.processFiles("/var/lib/matlab_3/ACORN/WERA/radial_nonQC/output/datafabric/gridded_1havg_currentmap_nonQC/SAG/2012","/home/matlab_3/df_root/opendap/ACORN/gridded_1h-avg-current-map_non-QC/SAG/2012",'nc')
       f.processFiles("/var/lib/matlab_3/ACORN/WERA/radial_nonQC/output/datafabric/gridded_1havg_currentmap_nonQC/ROT/2012","/home/matlab_3/df_root/opendap/ACORN/gridded_1h-avg-current-map_non-QC/ROT/2012",'nc')
       f.processFiles("/var/lib/matlab_3/ACORN/WERA/radial_nonQC/output/datafabric/gridded_1havg_currentmap_nonQC/COF/2012","/home/matlab_3/df_root/opendap/ACORN/gridded_1h-avg-current-map_non-QC/COF/2012",'nc')

       f.close()
          
    # disconnect using a thread
    #def doit():            
    #    if df.isDfMounted():
    #        df.unconnectDatafabric()
    #        
    #print "Disconnecting the datafabric.."    
    #t = threading.Timer(60.0, doit)
    #t.start()
    

   

