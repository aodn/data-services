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
           os.system("/usr/local/bin/matlab -nodisplay -r  \"run ('/usr/local/harvesters/matlab_3/svn/acorn/trunk/acorn_summary_CBG_SAG_ROT.m')\"")
       except Exception, e:
           print ("ERROR: " + str(e))     

       f = folderCopier.folderCopier()

       f.processFiles("/var/lib/matlab_3/ACORN/WERA/radial_nonQC/output/datafabric/gridded_1havg_currentmap_nonQC/CBG","/home/matlab_3/datafabric_root/opendap/ACORN/gridded_1h-avg-current-map_non-QC/CBG",'nc')
       f.processFiles("/var/lib/matlab_3/ACORN/WERA/radial_nonQC/output/datafabric/gridded_1havg_currentmap_nonQC/SAG","/home/matlab_3/datafabric_root/opendap/ACORN/gridded_1h-avg-current-map_non-QC/SAG",'nc')
       f.processFiles("/var/lib/matlab_3/ACORN/WERA/radial_nonQC/output/datafabric/gridded_1havg_currentmap_nonQC/ROT","/home/matlab_3/datafabric_root/opendap/ACORN/gridded_1h-avg-current-map_non-QC/ROT",'nc')
       f.processFiles("/var/lib/matlab_3/ACORN/WERA/radial_nonQC/output/datafabric/gridded_1havg_currentmap_nonQC/COF","/home/matlab_3/datafabric_root/opendap/ACORN/gridded_1h-avg-current-map_non-QC/COF",'nc')

       f.close()
          
    # disconnect using a thread
    def doit():            
        if df.isDfMounted():
            df.unconnectDatafabric()
            
    print "Disconnecting the datafabric.."    
    t = threading.Timer(60.0, doit)
    t.start()
    

   

