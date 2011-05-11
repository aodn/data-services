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
           os.system("/usr/local/bin/matlab -nodisplay -r  \"run ('/usr/local/harvesters/matlab_3/svn/ANFOG/trunk/seaglider_realtime_main_UNIX_v3.m')\"")
       except Exception, e:
           print ("ERROR: " + str(e))     
       try:
           os.system("/usr/local/bin/matlab -nodisplay -r  \"run ('/usr/local/harvesters/matlab_3/svn/ANFOG/trunk/slocum_realtime_main_UNIX_v3.m')\"")
       except Exception, e:
           print ("ERROR: " + str(e))  

    #   f = folderCopier.folderCopier()

    #   f.processFiles("/home/matlab_3/datafabric_root/staging/ANFOG/REALTIME/seaglider","/home/matlab_3/datafabric_root/opendap/ANFOG/REALTIME/seaglider",'nc')
     
    #   f.close()
   
    # disconnect using a thread
    def doit():            
        if df.isDfMounted():
            df.unconnectDatafabric()
            
    print "Disconnecting the datafabric.."    
    t = threading.Timer(60.0, doit)
    t.start()
    

   

