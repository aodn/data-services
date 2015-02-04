#!/bin/env python
# -*- coding: utf-8 -*-
from ftplib import FTP
import time,os,sys, threading, glob
from datetime import datetime
from os.path import join, exists, getmtime
import StorageConnection
from subprocess import Popen, PIPE, STDOUT
import errno

# require ncftpget sudo apt-get install ncftp
from configobj import ConfigObj  # install http://pypi.python.org/pypi/configobj/

import tempfile
import shutil


class FTPGetter:
    
        def mkdir_p(self,path):
                try:
                    os.makedirs(path)
                except OSError as exc: # Python >2.5
                    if exc.errno == errno.EEXIST and os.path.isdir(path):
                        pass
                    else: raise


        def __init__(self):
                
                self.year = datetime.today().year                
                self.ncftp = "" # its in the path now
                #self.thisFileLocation = os.getcwd()+ '/' 
                self.ftp_username = None
                self.ftp_password = None
                self.hostPath = None
                self.ftp = None
                
                #self.destinationDir    = tempfile.mkdtemp()             
                # create tmp directory where file will be downloaded
                pathname             = os.path.dirname(sys.argv[0])
                pythonScriptPath = os.path.abspath(pathname)
                configFilePath       = pythonScriptPath
                config               = ConfigObj(configFilePath+ os.path.sep + "config.txt")
                self.logFileHome     = config.get('logFile.name') 
                self.datasetGroup    = config.get('datasetGroup.name') 
                self.fileTypeDefault = config.get('bom_ftp.nc') # no 'dot'
                #self.dataWip         = config.get('dataWIP.path')
                
                
                
        def connectToFTPServer(self):
                ftp = None
                try:
                    ftp = FTP(self.hostPath)
                    ftp.set_debuglevel(0) # 0 is default

                except:
                    self.errorFiles.append("failed to find the host "+self.hostPath)
                if ftp:
                    try:
                        ftp.login(self.ftp_username,self.ftp_password)
                    except:
                        ftp.login()
                    
                    try:
                        ftp.cwd(self.serverDir)
                        return ftp
                    except:
                        self.errorFiles.append("failed to find "+ self.hostPath + self.serverDir)            
                        sys.exit(0)   
                
                             

        def processDataset(self, url, localDir, filetype , username, password, getsubdirs, useStorage, useFiles2ProcessFile):
                """
                     processDataset
                    
                     url - FTP URL
                     localDir - if the absolute path is not requested by starting the local destination directory
                                with a slash then the destination/ will be prepended 
                     filetype - the type of file to retrieve
                     username -FTP username
                     password - FTP password
                     getsubdirs- search FTP site recursively
                     useStorage - if True the connection and disconnection to the destination will be handled. Historically the destination was the storage which had 'issues'
                                      will exit if connection cannot be made
                     useFiles2ProcessFile - will write a file (self.files2ProcessFile) to localDir of the files 
                                            retrieved on this run. File contains full path to file
                """
                
                # cleanup reporting lists for new datasets
                self.newFiles = []
                self.errorFiles = []
                self.datasetList = []
                self.updatedFiles = []
                self.fileCount = []
                self.localFiles = []
                self.status = []
                self.localDir = localDir   
                self.ftp_username = username
                self.ftp_password = password
                self.files2ProcessFile = "files2Process.txt"
                self.files2Process = []


                self.serverDir = self.setup(url, localDir, filetype , username, password, getsubdirs, useStorage)


                #                for x in localDir.split(os.path.sep):
                #                    if(not os.path.exists(x.strip())):
                #                        os.mkdir(x.strip())
                #                    os.chdir(x.strip())
                self.mkdir_p(localDir)
                     
                print "Processing folder..." + self.hostPath + self.serverDir
                print "Mirroring into " +  localDir
                
                # APPEND list of retrieved files to process latter        
                if useFiles2ProcessFile:
                    try:
                        files2Process_handle  =   open(localDir + os.path.sep + self.files2ProcessFile,'a+')
                    except Exception, e:
                        self.errorFiles.append("Couldnt open the file list file: " + localDir + os.path.sep + self.files2ProcessFile + " " + str(e))  
                        print "Couldnt open the file list file: " + localDir + os.path.sep + self.files2ProcessFile + " " + str(e)
                        # If requested this file is essential so quit
                        sys.exit()   
                        
                 
            
                self.ftp  = self.connectToFTPServer()
                self.ftp.retrlines("LIST", self.datasetList.append)

                for dirLine in self.datasetList:
                        self.doDirectory(dirLine,getsubdirs,'')
                        
                
                self.status.append("Summary for " + url )
                self.status.append(str(len(self.updatedFiles)) + " Files were updated: ")
                for f in self.updatedFiles:
                    self.status.append(f)
                self.status.append(str(len(self.newFiles)) + " New files: ")
                for f in self.newFiles:
                    self.status.append(f)
                self.status.append(str(len(self.errorFiles)) + " Problems: ")
                for f in self.errorFiles:
                    self.status.append(f)
                self.status.append(str(len(self.fileCount)) + " '"+self.fileType+ "' files checked: ")
                self.status.append("==============================")

                ftpReportLogPath = localDir + os.path.sep + "FTP_Report"
                self.writetoLog(self.status, ftpReportLogPath)
                
                
                if useFiles2ProcessFile:
                    self.writeFileList(files2Process_handle)
                
                for f in self.status:
                    print "-> "  + str(f)
                    
                if len(self.newFiles) or len(self.updatedFiles):
                    return True
                    
        def   setup(self, url,localDir , filetype , username, password, getsubdirs, useStorage):
                
                #                if useStorage:
                #                    df = StorageConnection.StorageConnection()                
                #                    if  df.connectStorage():   
                #                        print "Automounted the storage "
                #                        self.status.append("Connected to the storage")
                #                    else:
                #                        print "Failed to automount the storage so exiting."
                #                        self.errorFiles.append("Failed to connect to storage")
                #                        sys.exit()
                #
                #                
                self.status.append( "Start-time : %s" % time.ctime())
                
                if len(filetype) > 1:
                    #strip leading dot and assign
                    self.fileType = filetype.lstrip(".").lower()
                else:
                    self.fileType = self.fileTypeDefault
                #
                #                # if the absolute path is requested move to root
                #                if (localDir.startswith(os.path.sep)):
                #                    os.chdir(os.path.sep)
                #                    # strip the trailing forward slash
                #                    #localDir = localDir[1:] # what the heck ?
                #                else:
                #                    #if  df.connectStorage():
                #                    self.status.append("Changing to " + self.destinationDir) 
                #                    os.chdir(self.destinationDir) # post datafabric world
                #                    #else:
                #                    #    print "Failed to connect to the storage so exiting. (2)"
                #                    #    self.errorFiles.append("Failed to connect to storage (2)")
                #                    #    sys.exit()

                # create this datasets base directory if one doesn't exist already
                #if (localDir.rfind(os.path.sep) == (len(localDir)-1)):
                #    localDir = localDir[:-1]
                #    
                #self.localDir = localDir

                # get ready to connect to FTP server
                #strip off ftp://
                if (url.find("ftp://",0,6) == 0):
                    url = url[6:]
                # strip a trailing forward slash
                if (url.rfind("/") == len(url)):
                    url = url[:-1]

                if (url.find('/') != -1):
                    divide =  url.find("/")
                    self.hostPath = url[:divide]
                    serverDir = url[divide:]
                # then its the root folder
                else:
                    self.hostPath = url
                    serverDir = "/"
                    
                #                return (localDir,serverDir)

                return (serverDir)
                
                
        def checkLocalDataset(self, url, localDir, filetype , username, password, getsubdirs, useStorage):
                """
                        The options are basically the same as processDataset
                        This function looks (read only) at the local file directory to see which files are 
                        'orphaned', no longer on the source FTP site.
                        
                        
                        #!/bin/bash
                        
                        cd /tmp
                        cat filestoremove.txt |
                        while read a; 
                        do
                        ls -la /$a

                        done
                
                """
                
                self.newFiles = []
                self.listofFTPFiles = []
                self.datasetList = []
                self.localFiles = dict() # keys are file name, value is fullpath + filename

                orphanedFiles = []
                self.fileCount = []
                self.status = []
                self.ftp_username = username
                self.ftp_password = password
                

                # making serverDir a self so we can get rid of ftp.cwd which is bad                                
                self.serverDir = self.setup(url, localDir, filetype , username, password, getsubdirs, useStorage)
                #os.chdir(localDir)

                print "Checking folder..." + localDir + "\n"
                
                # list all local files
                for  top, dirs, files in os.walk(localDir):
                        for f in files:                          
                                if  f.endswith('.'+ self.fileType):     
                                        # keep the full path
                                        x = os.path.join("/" + top, f)                                      
                                        self.localFiles[f] = x
                                        
                
                string =  str(len(self.localFiles)) + " local file count"
                # items will be removed from self.localFiles later
                localFiles = self.localFiles
                self.status.append(string)
                print string
                

                print "Comparing to      " +  self.hostPath + serverDir + "\n"
                
                # APPEND list of retrieved files to process latter                    
                self.ftp  = self.connectToFTPServer()
                print "Debug ftp connection out" + "\n"

                self.ftp.retrlines("LIST", self.datasetList.append)
                for dirLine in self.datasetList:
                       self.doFTPDirectory(dirLine,getsubdirs)
                       
                string =  str(len(self.fileCount)) + " '"+self.fileType+ "' files checked on FTP Server: "
                self.status.append(string)
                print string + "\n"
                
                # show which files are left after 'doFTPFile'
                orphanedFiles = self.localFiles

                try:
                        files2Process_handle  =   open(self.logFileHome + "/checkLocalDataset.log" ,'w+')
                except Exception, e:
                        self.errorFiles.append("Couldnt open the log file: " + self.logFileHome + "/checkLocalDataset.log" + " " + str(e))  
                        
                        
                self.status.append("Summary for " + url )
                self.status.append(str(len(orphanedFiles)) + " Files were orphaned: ")
                for f in orphanedFiles:
                    self.status.append(orphanedFiles[f])
                #self.status.append(str(len(self.newFiles)) + " New Files")
                #for f in self.newFiles:
                #    self.status.append(f)
                
                self.status.append("==============================")

                self.writetoLog(self.status, "FTP_Report")


                
                for f in self.status:
                    print  str(f)
                
                shutil.rmtree(self.destinationDir)

        # parses FTP for files
        def doFTPDirectory(self, dirLine,getsubdirs):
                print "DEBUG: The remote dir: "+self.ftp.pwd() +"\n  and the local dir: "+ self.localDir + "\n and getting: "+dirLine +"\n"
                # handle the files       
                thisFileList = []

                if(dirLine[0] == '-'):
                    self.doFTPFile(dirLine, self.ftp.pwd())
                # then handle the directories
                else:
                    
                    if(dirLine[0] == 'd' and getsubdirs):
                        dirName = dirLine.split()[8:]
                        dirName = ''.join(dirName)
                        # ignore hidden files here
                        if(dirName[0] != '.'):
                            #print self.ftp.pwd() + " current dir going to " +dirName
                            
                            try:
                               self.ftp.cwd(self.serverDir + os.path.sep + dirName)

                               #                                self.ftp.cwd(dirName)
                               self.ftp.retrlines("LIST", thisFileList.append)

                            except Exception, e:
                                msg = "Failed to complete the '" + dirName + "' directory" 
                                self.errorFiles.append(msg + " " + str(e))
                                print msg + "\n"
                             
                            if len(thisFileList) > 0:
                                for f in thisFileList:
                                    self.doFTPDirectory(f,getsubdirs) 

                            #self.ftp.cwd("../")
                            
                            
                            
        def doFTPFile(self, fileLine, pwd):
                
                #print "'"+fileLine[54:]+"'"
                filename = fileLine.split()[8:]
                filename = ''.join(filename)
                filename = filename.split(" -> ")[0]
                filex =  filename.rsplit(".",1)
                if(len(filex) == 2 and str(fileLine[0]) == '-' and str(filex[1]) == self.fileType):
                        print "Handle File: The remote dir: "+self.ftp.pwd() +"\n  and the local dir: "+ self.localDir + "\n and getting: "+filename  +"\n"          
                        self.fileCount.append(filename)
                        
                        # if a file is on the localDir and not on the FTP server , we want to know
                        if self.localFiles.has_key(filename):
                            # so remove it from global so we can see whats left later
                            del self.localFiles[filename]
                        
                        # if a file is on the FTP server and not on the LocalDir then we want to know
                        else:
                                self.newFiles.append(filename) 
                        
                        
                        


        def doDirectory(self, dirLine,getsubdirs,dirNameLocal):
                print "DEBUG: The remote dir: "+self.ftp.pwd() +"\n  and the local dir: "+ self.localDir + "\n and getting: "+dirLine +"\n"
                # handle the files       
                thisFileList = []

                if(dirLine[0] == '-'):
                    #self.handleFile(dirLine, self.ftp.pwd()) # second argument not used in function ...!
                    self.handleFile(dirLine,dirNameLocal)
                    # then handle the directories
                else:
                    
                    if(dirLine[0] == 'd' and getsubdirs):
                        dirName = dirLine.split()[8:]
                        dirName = ''.join(dirName)
                        # ignore hidden files here
                        if(dirName[0] != '.'):
                            dirNameLocal = self.localDir + os.path.sep + dirName # replace dirName to avoid the ugly chdi
                            print self.ftp.pwd() + " current dir going to " + dirNameLocal + "\n"
                            #create the LOCAL dataset directory 
                            self.mkdir_p(dirNameLocal)
                            #if(not os.path.exists(dirName)):
                            #    os.mkdir(dirName)
                            #os.chdir(dirName)
                            try:
                                
                                self.ftp.cwd(self.serverDir + os.path.sep + dirName)
                                self.ftp.retrlines("LIST", thisFileList.append)

                            except Exception, e:
                                msg = "Failed to complete the '" + dirNameLocal + "' directory"
                                self.errorFiles.append(msg + " " + str(e))
                                print msg + "\n"
                             
                            if len(thisFileList) > 0:
                                for f in thisFileList:
                                    self.doDirectory(f,getsubdirs,dirNameLocal) 

                           # os.chdir("../")
                           # self.ftp.cwd("../")



        def handleFile(self,  fileLine,dirNameLocal):
                
                #print "'"+fileLine[54:]+"'"
                filename = fileLine.split()[8:]
                filename = ''.join(filename)
                filename = filename.split(" -> ")[0]
                filex =  filename.rsplit(".",1)
                if(len(filex) == 2 and str(fileLine[0]) == '-' and str(filex[1]) == self.fileType):
                    self.fileCount.append(filename)          
                    self.doFile(filename,dirNameLocal)

        def doFile(self,  filename,dirNameLocal):
                result = self.ftp.sendcmd("MDTM " + filename)
                remoteLastModDate = datetime(*(time.strptime(result[4:], "%Y%m%d%H%M%S")[0:6]))

                if os.path.exists(dirNameLocal +os.path.sep +filename):
                    fileModTime = time.gmtime(getmtime(filename))

                    if(time.mktime(fileModTime) < time.mktime(remoteLastModDate.timetuple())):
                
                        if(self.downloadFile(filename,dirNameLocal, True)):
                           self.updatedFiles.append(os.path.abspath(filename))
                    else:
                        pass 
                        # print "Ignoring update as: " + str(time.mktime(fileModTime))+" is not less than " +str(time.mktime(remoteLastModDate.timetuple()))
                        #print "Ignoring update of " + filename + " as: " # + str((getmtime(fileModTime, "%Y%m%d%H%M%S")[0:6])) +" is not less than " +str(remoteLastModDate)
                else:
            
                    if self.downloadFile(filename,dirNameLocal, False):
                        self.newFiles.append(os.path.abspath(filename))



        def downloadFile(self, filename,dirNameLocal, isUpdate):

                remoteSize = None
                remoteSize = self.ftp.size(filename) 
               
                print "Trying to download file... " + os.path.abspath(filename)   
                
                #self.ftp.retrbinary("RETR " + filename, newFile.write)
                """
                        ncftpget is needed to handle drop outs
                        -t timeout
                        -f location of connection parameters                    
                """  
                filenamePath =  dirNameLocal+ os.path.sep + filename 
                if(isUpdate):
                    # rip out the local file. historically this method used as datafabric wouldnt let updates happen 
                    os.remove(filename)
                    #print "Removed for update " + str(filename);
            
            
                try:
                    cmd =  "ncftpget -t 120  -d ~/ncftpget.log  -u '" +  self.ftp_username + "'  -p '" +  self.ftp_password + "'"  + " -C " + self.hostPath + "  " + self.ftp.pwd() + "/" + filename + " " +filenamePath
                    print cmd
                    msg = os.system(cmd)
                except Exception, e:
                    self.errorFiles.append(filename + " " + str(e))
                    

                newFile = None
                try:
                    newFile = open(filenamePath, "r")
                except Exception, e:
                    msg = filename + " NOT Found (transfer not retried)" + str(e)
                    print msg
                    self.errorFiles.append(msg)
                    
                
                if newFile != None:
                    newFile.seek(0, 2) #get to the file end
                    lSize = newFile.tell()        
                    if remoteSize == lSize:
                        print "Transfer complete " + filename
                        self.files2Process.append(filenamePath)
                    else:
                        print "BAD Incomplete Transfer " + str(remoteSize) + "  - " + str(lSize)
                        self.errorFiles.append((filename + "BAD Transfer " + str(remoteSize) + ", " + str(Size)))
                        os.remove(filenamePath)
                    newFile.close()
                    
                    if(not isUpdate):
                        os.popen("chmod g+w " + filenamePath).readline()
                        os.popen("chgrp "+self.datasetGroup +" " + filenamePath).readline()
                
                 
                # sort out the return?
                return True

        def writetoLog(self, report, filename):
                #os.chdir(self.logFileHome)

                if    os.path.isfile(filename+ ".txt"):
                    size =    os.path.getsize(filename+ ".txt")
                    if size > 1000000:
                        os.rename(filename + ".txt", filename +"_"+ time.strftime('%x').replace('/','-') + ".txt")
                        None

                log_file    =    open(filename+ ".txt",'a+')
                log_file.write("\r\nDownload time: " +  time.ctime() + "\r\n")
                for line in report:
                    log_file.write(str(line) + "\r\n")
                log_file.close()


        def writeFileList(self, filename):                
                
                for line in self.files2Process:
                    filename.write(str(line) + "\r\n")
                filename.close()


        def close(self):
                try:
                    self.ftp.quit()
                except:
                    pass

