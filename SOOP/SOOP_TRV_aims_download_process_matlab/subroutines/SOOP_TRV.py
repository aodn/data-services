#!/bin/env python
# -*- coding: utf-8 -*-
import os,sys,threading, subprocess,fnmatch,shutil
from configobj import ConfigObj  # install http://pypi.python.org/pypi/configobj/

if __name__ == "__main__":

    print "Start of the SOOP TRV script"
    try:
                ## get full path of Python Script Location
        #print 'sys.argv[0] =', sys.argv[0]             
        pathname = os.path.dirname(sys.argv[0])        
        #print 'path =', pathname
        pythonScriptPath=os.path.abspath(pathname)
        #print 'full path =', os.path.abspath(pathname)
        
        ## since the python script is in the folder /subroutines, and config.txt is in ../ we remove 'subroutines' from the string
        configFilePath=pythonScriptPath[0:len(pythonScriptPath)-len("subroutines")]
        
        # we read here the scriptPath as well as the matlab path
        config = ConfigObj(configFilePath+"config.txt")
        scriptPath=config.get('script.path') 
        #print scriptPath
        
        
        matlabPath=config.get('matlab.path') 
              
        #print (matlabPath+ " -nodisplay -r  \"run ('"+ scriptPath+ "/Aggregate_ACORN.m')\"")
      
        os.system(matlabPath+ " -nodisplay -r  \"run ('"+ scriptPath+ "/SOOP_Launcher.m');exit;\"")
        

    except Exception, e:
        print ("ERROR: " + str(e))         

