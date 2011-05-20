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
           os.system("/usr/local/bin/matlab -nodisplay -r  \"run ('/usr/local/harvesters/matlab_3/svn/acorn/trunk/acorn_summary_non_QC_CODAR.m')\"")
       except Exception, e:
           print ("ERROR: " + str(e))     
          
    # disconnect using a thread
    def doit():            
        if df.isDfMounted():
            df.unconnectDatafabric()
            
    print "Disconnecting the datafabric.."    
    t = threading.Timer(60.0, doit)
    t.start()
    

   

