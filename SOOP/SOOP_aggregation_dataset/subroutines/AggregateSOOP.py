#!/bin/env python
# -*- coding: utf-8 -*-
import os,sys
from configobj import ConfigObj

if __name__ == "__main__":
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
        #print matlabPath
        
        #print (matlabPath+ " -nodisplay -r  \"run ('"+ scriptPath+ "/Aggregate_SOOP.m')\"")
      
        os.system(matlabPath+ " -nodisplay -r  \"run ('"+ scriptPath+ "/Aggregate_SOOP.m');exit;\"")
    except Exception, e:
        print ("ERROR: " + str(e))