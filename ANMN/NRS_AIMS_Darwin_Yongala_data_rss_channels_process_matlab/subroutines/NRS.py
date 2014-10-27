#!/bin/env python
# -*- coding: utf-8 -*-
import os,sys,threading, subprocess,fnmatch,shutil
from configobj import ConfigObj  # install http://pypi.python.org/pypi/configobj/

if __name__ == "__main__":

    print "Start of the NRS script"
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
              
      
        os.system(matlabPath+ " -nodisplay -r  \"run ('"+ scriptPath+ "/NRS_Launcher.m');exit;\"")
        dataPath = config.get('dataWIP.path')
        dir_src = dataPath+"/"
        dir_dst = dir_src+"SQL_done"

        dbName = config.get('database.name')
        dbUser = config.get('database.user')
        dbPassword = config.get('database.password')
        dbPort = config.get('database.port')
        dbHost =   config.get('database.host')

        if not os.path.exists(dir_dst):
            os.makedirs(dir_dst)
            
        listOfFiles = os.listdir(dir_src)
        for file in os.listdir(dir_src):
            ShellCommandDbOption = "\""+ "user=" + dbUser + " dbname=" + dbName + " password=" + dbPassword + " port=" + dbPort + " host="+ dbHost + "\""
            ShellCommand_prefix="rm /tmp/varlog.log; psql " +  ShellCommandDbOption +  " <"+ dir_src
            ShellCommand_sufix=">> /tmp/varlog.log; cat /tmp/varlog.log"

            # SQL script Insert
            if fnmatch.fnmatch(file, 'DB_Insert*'):
               print file
               ShellCommand=ShellCommand_prefix+file +ShellCommand_sufix
               
               print ShellCommand
               #os.system(ShellCommand) #depreciated
            
               src_file = os.path.join(dir_src, file)
               dst_file = os.path.join(dir_dst, file)
               shutil.move(src_file, dst_file)

        for file in os.listdir(dir_src):
            ShellCommandDbOption = "\""+ "user=" + dbUser + " dbname=" + dbName + " password=" + dbPassword + " port=" + dbPort + " host="+ dbHost + "\""
            ShellCommand_prefix="rm /tmp/varlog.log; psql " +  ShellCommandDbOption +  " <"+ dir_src
            ShellCommand_sufix=">> /tmp/varlog.log; cat /tmp/varlog.log"               
               
            # SQL script Update
            if fnmatch.fnmatch(file, 'DB_Update*'):
               print file
               ShellCommand=ShellCommand_prefix+file +ShellCommand_sufix
               
               print ShellCommand
               #os.system(ShellCommand) #depreciated
            
               src_file = os.path.join(dir_src, file)
               dst_file = os.path.join(dir_dst, file)
               shutil.move(src_file, dst_file)



    except Exception, e:
        print ("ERROR: " + str(e))         

