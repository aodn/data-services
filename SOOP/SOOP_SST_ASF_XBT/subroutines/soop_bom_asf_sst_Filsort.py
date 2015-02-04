#!/bin/env python
# -*- coding: utf-8 -*-
import os, shutil, stat, time, grp, sys, threading
from subprocess import Popen, PIPE, STDOUT
from configobj import ConfigObj  # install http://pypi.python.org/pypi/configobj/

class soop_bom_asf_sst_Filsort:

    def __init__(self):
        self.ships = {
                        'VLST'    :'Spirit-of-Tasmania-1',
                        'VNSZ'    :'Spirit-of-Tasmania-2',
                        'VHW5167' :'Sea-Flyte',
                        'VNVR'    :'Iron-Yandi',
                        'VJQ7467' :'Fantasea',
                        'VNAH'    :'Portland',
                        'V2BJ5'   :'ANL-Yarrunga',
                        'VROB'    :'Highland-Chief',
                        '9HA2479' :'Pacific-Sun',
                        'VNAA'    :'Aurora-Australis',
                        'VLHJ'    :'Southern-Surveyor',
                        'FHZI'    :'Astrolabe',
                        'C6FS9'   :'Stadacona',
                        'V2BF1'   :'Florence',
                        'V2BP4'   :'Vega-Gotland',
                        'A8SW3'   :'Buxlink',
                        'ZMFR'    :'Tangaroa',
                        'VRZN9'   :'Pacific-Celebes',
                        'VHW6005' :'RV-Linnaeus',
                        'HSB3402' :'MV-Xutra-Bhum',
                        'HSB3403' :'MV-Wana-Bhum',
                        'VRUB2'   :'Chenan',
                        'VNCF'    :'Cape Ferguson',
                        'VRDU8'   :'OOCL Panama'

                     }

        self.blackList = [
                            'IMOS_SOOP-SST_MT_20111103T000000Z_9HA2479_FV01_C-20120528T072251Z.nc',
                            'IMOS_SOOP-SST_T_20130215T005900Z_HSB3403_FV01_C-20130216T001306Z.nc',
                            'IMOS_SOOP-SST_MT_20140409T010000Z_VROB_FV01_C-20140413T233225Z.nc'
                         ]

        self.data_codes = {'FMT':'flux_product','MT':'meteorological_sst_observations' }

        # read config.txt
        pathname             = os.path.dirname(sys.argv[0])
        pythonScriptPath     = os.path.abspath(pathname)
        configFilePath       = pythonScriptPath
        config               = ConfigObj(configFilePath+ os.path.sep + "config.txt")

        self.logfilePath    = config.get('logFileASF_SST.path')

        # Use this to convert target modified time into local time
        self.timezone_offset = time.altzone

        self.newCount     = 0;
        self.updatedCount = 0;
        self.checkedCount = 0;
        self.ignoredCount = 0;

        self.status = []
        self.errorFiles = []

    def processFiles(self,origDir,userDestDir,fileExtension):
        self.destDir = userDestDir

        #print "Checking " + os.getcwd()
        for root, dirs, fname in os.walk(origDir ):
            fname.sort()
            for fname in fname:
                if fname.rsplit(".",1)[1] == fileExtension:
                    modified = os.stat(root+os.path.sep+fname)[stat.ST_MTIME]
                    #print str(time.localtime(modified)) + " " + root+os.path.sep+fname
                    self.handleFiles(fname,modified,root)

                else:
                    self.ignoredCount += 1


        # find crap files created on the destination
        crapFiles = os.system("find " +  self.destDir + " -name '*." + fileExtension +"' -size -5b -exec ls -la {\} \;")
        if crapFiles > 0:
            os.system("find " +  self.destDir + " -name '*." + fileExtension +"' -size -5b -exec rm {\} \;")
            self.errorFiles.append(str(crapFiles) + " empty ." +fileExtension +" files removed")

        self.status.append("\nSummary for File Sort: " + origDir + " " + time.strftime("%a, %d %b %Y %H:%M:%S",time.localtime()) )
        self.status.append(str(self.updatedCount) + " Files were updated: ")
        self.status.append(str(self.newCount) + " New files: ")
        self.status.append(str(len(self.errorFiles)) + " Problems: ")
        for f in self.errorFiles:
            self.status.append(f)
        self.status.append(str(self.checkedCount)+" files up to date")
        self.status.append("==============================")

        self.writetoLog(self.status)
        # print to console
        for f in self.status:
            print f

    def handleFiles(self,fname,modified,root):
        """

        # eg file IMOS_SOOP-SST_T_20081230T000900Z_VHW5167_FV01.nc
        # IMOS_<Facility-Code>_<Data-Code>_<Start-date>_<Platform-Code>_FV<File-Version>_<Product-Type>_END-<End-date>_C-<Creation_date>_<PARTX>.nc

        """

        theFile = root+os.path.sep+fname

        file = fname.split("_")

        if file[0] != "IMOS":
            self.ignoredCount += 1
            return

        facility = file[1] # <Facility-Code>

        # the file name must have at least 6 component parts to be valid
        if len(file) > 5:

            year = file[3][:4] # year out of <Start-date>

            # check for the code in the ships
            code = file[4]
            if code in self.ships:

                platform = code+"_"+ self.ships[code]

                if facility == "SOOP-ASF":
                    if file[2] in self.data_codes:
                        product       = self.data_codes[file[2]]
                        targetDir     = self.destDir+os.path.sep+facility+os.path.sep+platform+os.path.sep+product+os.path.sep+year
                        targetDirBase = self.destDir+os.path.sep+facility
                    else:
                        err = "Unknown Data Code "+product+" for "+facilty+". Add it to this script. File ignored"
                        print err
                        self.errorFiles.append(err)
                        # common error that needs  our attention
                        self.ignoredCount += 1
                        return False
                else:
                    targetDir     = self.destDir+os.path.sep+facility+os.path.sep+platform+os.path.sep+year
                    targetDirBase = self.destDir+os.path.sep+facility

                # files that contain '1-min-avg.nc' get their own sub folder
                if "1-min-avg" in fname:
                    targetDir = targetDir+ "/1-min-avg"

                error = None

                if(not os.path.exists(targetDir)):

                    try:
                        os.makedirs(targetDir)
                    except:
                        print "Failed to create directory " + targetDir
                        self.errorFiles.append("Failed to create directory " + targetDir )
                        error = 1

                # blacklist check
                if fname in self.blackList:
                    print "Ignoreing Blacklisted file " + fname
                    self.errorFiles.append("Ignoreing Blacklisted file " + fname )
                    error = 1

                if not error:
                    targetFile = targetDir+os.path.sep+fname

                    # see if file exists
                    if(not os.path.exists(targetFile)):
                            shutil.copy(theFile,targetFile )
                            #print theFile +" created in -> "+ targetDir

                            self.newCount += 1;

                    # copy if more recent or rubbish file
                    elif (modified > os.stat(targetFile)[stat.ST_MTIME] + self.timezone_offset) or (os.path.getsize(targetFile) == 0):
                        try:
                            if os.path.getsize(targetFile) == 0:
                                print   "Zero sized file found: " + targetFile

                            try:
                                    os.remove(targetFile)
                            except os.error:
                                    print "remove wasnt successfull"

                            try:
                                    shutil.copy(theFile,targetFile )
                                    #print theFile +" updated in -> "+ targetDir
                                    self.updatedCount += 1;
                            except:
                                    print "copy of " + theFile + " wasnt successfull"



                        except Exception, e:
                            msg = "Failed to update file (" + theFile + " "  +  time.ctime() + ")  " + str(e)
                            self.errorFiles.append(msg)
                    else:
                        self.checkedCount += 1;


            else:
                if code != "SOFS": # SOFS = bogus files writen by CSIRO. ignore them
                    err = "Unrecognised file "+ root+os.path.sep+ fname + " with code '"  + code + "' found by the filesorter"
                    self.errorFiles.append(err)
                    # common error that needs  our attention
                    #email = sendEmail.sendEmail()
                    #email.sendEmail(self.emailAddress,"SOOP File sorter- Unrecognised ship code",err)
        else:
            err = "Ignoring file "+ root+os.path.sep+ fname + " not in agreed format"
            self.errorFiles.append(err)

    def writetoLog(self, report):
        filename = self.logfilePath

        if    os.path.isfile( filename ):
            size =    os.path.getsize(filename)
            if size > 1000000:
                os.rename(filename , filename[0:-3] +"_"+ time.strftime('%x').replace('/','-') + ".log")
                None

        log_file    =    open(filename,'a+')
        log_file.write("\r\nDownload time: " +  time.ctime() + "\r\n")
        for line in report:
            log_file.write(line + "\r\n")
        log_file.close()

    def close(self):
            try:
                self.ftp.quit()
            except:
                pass
