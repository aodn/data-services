#!/bin/env python
# -*- coding: utf-8 -*-
import os,sys,threading
import DatafabricConnection,folderCopier,cleaningNC

if __name__ == "__main__":


   
    df = DatafabricConnection.DatafabricConnection()
     
    print "Checking the datafabric.."
    if df.connectDatafabric():
       print "Datafabric now connected"

       f = folderCopier.folderCopier()

       f.processFiles("/home/matlab_3/datafabric_root/staging/ANFOG/PROCESSED/slocum_glider/CrowdyHead20091002","/home/matlab_3/datafabric_root/opendap/ANFOG/slocum_glider/CrowdyHead20091002",'nc')
     
       f.close()

  
    # disconnect using a thread
    def doit():            
        if df.isDfMounted():
            df.unconnectDatafabric()
            
    print "Disconnecting the datafabric.."    
    t = threading.Timer(60.0, doit)
    t.start()
    

   

