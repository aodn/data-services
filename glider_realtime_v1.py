#!/bin/env python
# -*- coding: utf-8 -*-
import os,sys,threading,glob,fnmatch
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

       f = folderCopier.folderCopier()

       f.processFiles("/home/matlab_3/datafabric_root/staging/ANFOG/REALTIME/seaglider","/home/matlab_3/datafabric_root/opendap/ANFOG/REALTIME/seaglider",'nc')
     
       f.close()

       os.chdir("/var/lib/matlab_3/ANFOG/realtime/seaglider/output/processing/")
       for file in os.listdir("."):
           if fnmatch.fnmatch(file,'*SQL*'):
              try:
                 os.system("psql -h db.emii.org.au -p 5432 seb maplayers <" + file)
                 os.remove(file)
              except Exception, e:
                  print ("ERROR: " + str(e))

       os.chdir("/var/lib/matlab_3/ANFOG/realtime/slocum/output/processing/")
       for fileslocum in os.listdir("."):
           if fnmatch.fnmatch(fileslocum,'*SQL*'):
              try:
                 os.system("psql -h db.emii.org.au -p 5432 seb maplayers <" + fileslocum)
                 os.remove(fileslocum)
              except Exception, e:
                  print ("ERROR: " + str(e))
   
    # disconnect using a thread
    def doit():            
        if df.isDfMounted():
            df.unconnectDatafabric()
            
    print "Disconnecting the datafabric.."    
    t = threading.Timer(60.0, doit)
    t.start()
    

   

