#!/bin/env python
# -*- coding: utf-8 -*-
import os, shutil, stat, time, grp, struct, binascii,sys
from subprocess import Popen, PIPE, STDOUT
from configobj import ConfigObj  # install http://pypi.python.org/pypi/configobj/
from os import listdir
from os.path import isfile, join

class soop_xbt_realtime_processSBD:


    def __init__(self):
        self.sbddataFolder = None
        self.ships = {  'VLST'    :'Spirit-of-Tasmania-1',
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
                        '9VEY2'   :'Southern-Lily',
                        'P3JM9'   :'Conti-Harmony',
                        'PBKZ'    :'Schelde-Trader',
                        'V2CN5'   :'Sofrana Surville',
                        'DDPH'    :'Merkur-Sky',
                        'YJZC5'   :'Pacific-Gas',
                        'A8JM5'   :'ANL-Benalla',
                        '3FLZ'    :'Tropical-Islander',
                        'VRCF6'   :'Santos-Express',
                        'VRUB2'   :'Chenan',
                        '9V9713'  :'Shengking',
                        '5WDC'    :'Capitaine-Fearn'

        }


        self.logfilePath       = os.environ.get('logfile_xbt_path')         # place for log files. Same as FTPGetter.py
        self.csvOutputPath     = os.environ.get('temporary_data_folder_sorted_xbt_path')

        self.script_time       =  time.strftime("%a, %d %b %Y %H:%M:%S",time.localtime())

        # Use this to convert target modified time into local time
        self.timezone_offset   = time.altzone

        self.newCount          = 0
        self.handledFiles      = 0
        #self.fileOutput       = [] #holds the dictionary of data for each file. Call writeSql once
        self.status            = []
        self.errorFiles        = []
        self.badDataFiles      = [] # files that have an internal flag marked as bad data

        self.files2ProcessFile = "files2Process.txt"


    def processAllFiles(self,origDir):
        self.sbddataFolder = origDir

        print "Processing all files in " + origDir

        for dirname, dirnames, filenames in os.walk('.'):
            for filename in filenames:
                if filename.rsplit(".",1)[1].strip() == "sbd":
                    self.handleFiles(filename)
                    pass
        print "Processing all files in " + origDir

        self.writetoLog()


    def absoluteFilePaths(self,directory):
        for dirpath,_,filenames in os.walk(directory):
            for f in filenames:
               yield os.path.abspath(os.path.join(dirpath, f))

    def processFiles(self,origDir):
        self.sbddataFolder = origDir
        sbdfiles = self.absoluteFilePaths(self.sbddataFolder)
        for f in sbdfiles:
            self.handleFiles(f)

        self.writetoLog()

    def handleFiles(self,fname):

        data              = {}
        err               = ""
        errInvalid        = ""
        self.handledFiles += 1

        f                 =  open(fname, "rb")
        # There should be 5 bytes of headers in file to chuck
        resId             = f.read(2)

        if resId == "C2" or resId == "C3":

            err = "The file  " + fname + " appears to have the correct header " + resId + " in the wrong place at byte 0."
            print err
            self.errorFiles.append(err)
            data['incorrectHeaders'] = resId

        else:

            junk  = f.read(3)
            resId = f.read(2)

        if resId == "C2" or resId == "C3":

            data['fname']        = fname


            # this id is meaningless??
            res                  = self.str2intStr(resId)
            data['id']           = res

            res                  = f.read(1)
            data['drop_id']      = self.str2intStr(res) #   Drop number (of the day?)

            res                  = f.read(1)
            res                  = self.str2bin(res)
            data['year']         = "20" + self.bin2intStr(res[:4])   # year is in the 21th century
            data['month']        = str(int(self.bin2intStr(res[4:]))+1).zfill(2)   # month  is stored from 0 -11


            res                  = f.read(2)
            res                  = self.str2bin(res)

            data['day']          = self.bin2intStr(res[:5]).zfill(2) # day
            data['hour']         = self.bin2intStr(res[5:10]).zfill(2) # hour
            data['minute']       = self.bin2intStr(res[10:]).zfill(2)  # min

            res                  = f.read(5)
            res                  = self.str2bin(res)

            data['lon']          = str(float(self.bin2intStr(res[:20]))/2900)
            data['lat']          = str(float(self.bin2intStr(res[20:]))/2900-90)

            res                  = f.read(3) # byte 11-13
            res                  = self.str2bin(res)
            # self.bin2intStr(res[2:7]) #   Number of Points MSB

            data['quality_flag'] =  self.bin2intStr(res[:1])  # quality flag
            if data['quality_flag'] == '0':
                # It has bad data
                errInvalid = "Bad data in: " + resId + " " + fname + " no CSV file written"
                #print errInvalid
                self.errorFiles.append(errInvalid)
                self.badDataFiles.append(errInvalid)

            data['interface_code'] = self.bin2intStr(res[7:14]) #   Interface Code
            data['probe_code']     = self.bin2intStr(res[14:]) #  Probe type Code

            res                    = f.read(1) # byte 14
            res                    = self.str2bin(res)
            data['points']         = self.bin2intStr(res)

            # byte 15-23
            res                    = f.read(9)  # may contain giberish
            data['callsign']       = self.onlyascii(res)
            if data['callsign'].lower() == "test":
                errInvalid = "Callsign is marked as TEST - Ignoring " + fname
                print errInvalid
                self.errorFiles.append(errInvalid)

            # meat and potatoes
            temps  = []
            depths = []
            res    = f.read(3)
            while res != "":
                res = self.str2bin(res)

                temperature = str(round(float(int(res[:13],2))/200-3,4)) # make into a decimal int then into a float then divide by 300 minus 3
                depth       = str(float(int(res[13:],2))/2) # make into a decimal int then into a float then divide by 2
                temps.append(temperature)
                depths.append(depth)

                res = f.read(3)


            data['temps']  = temps
            data['depths'] = depths


        else:
            # It has invalid data
            errInvalid = "Invalid file. Unrecognised resId: " + resId + " " + fname
            self.errorFiles.append(errInvalid)


        f.close()

        if len(data) > 10 and len(errInvalid) == 0:

            # store for latter SQL creation
            #self.fileOutput.append(data)
            #create a CSV file for this BSD file
            self.writeCSV(data,self.csvOutputPath)



    def writeCSV(self,data,currDir):

        """
        creates a  CSV file for each SBD file
        suggested use is to run SQL then delete it
        """
        data.update(self.getExtras())

        # sort into folders based around shipname
        if (data['callsign'] in self.ships):

            csvDir = self.csvOutputPath + os.path.sep + data['callsign'] + "_" + self.ships[data['callsign']] + os.path.sep + data['year']

            #if self.databaseFileWrite:

            if(not os.path.exists(csvDir)):

                try:
                  os.makedirs(csvDir)
                except:
                  err = "ERROR: problem  writing to the CSV Directory " + csvDir + " exiting..  "
                  print err
                  self.errorFiles.append(err)
                  self.writetoLog()
                  sys.exit()


            for thing in data.items():
              #print thing
              pass

            print data['fname']

            filename      = data['fname'].replace(".sbd","")
            stringArr     = filename.split("_")
            filename      =  stringArr[len(stringArr)-1]


            imos_filedate = data['year'] + data['month'] + data['day'] + "T" +  data['hour'] + data['minute'] + "00Z"
            filename      =  "IMOS_SOOP-XBT_T_" + imos_filedate + "_" + data['callsign'] + "_" + filename  + "_FV00.csv"
            print "creating: " +  csvDir + os.path.sep +  filename

            # overwrite existing files. Note: remove sbd files once processed
            try:
                f = open(csvDir + os.path.sep + filename,'w+')

                f.write("Project:,"+ data['project']+"\r\n")
                f.write("Source:,"+ data['source']+"\r\n")
                f.write("Latitude:,"+ data['lat']+"\r\n")
                f.write("Longitude: ,"+ data['lon']+"\r\n")
                f.write("Date/Time:," + data['day'] + os.path.sep + data['month']+ os.path.sep + data['year'] + " " + data['hour'] + ":" + data['minute'] +"\r\n")
                f.write("This file Created:,"+ data['date_created']+"\r\n")
                f.write("Platform Code:,"+ data['callsign']+"\r\n")
                f.write("XBT Recorder Type:,"+ data['interface_code']+"," + data['recorder_probe_notes']+"\r\n")
                f.write("XBT Probe Type Fallrate Equation:,"+ data['probe_code']+"," + data['recorder_probe_notes']+"\r\n")
                f.write("Comment,"+ data['comment']+"\r\n")
                f.write("Metadata:,"+ data['metadata']+"\r\n\r\n")
                f.write("Depth Units:,Metre\r\n\r\n")
                f.write("Temperature Units:,Degrees Celsius\r\n\r\n")
                f.write("Depth,Temperature\r\n")

                for index in range(len(data['depths'])):
                    f.write(data['depths'][index]+","+ data['temps'][index]+"\r\n")

                f.close()

            except Exception, e:
              err= "ERROR: problem opening " + filename + " to write the CSV. exiting..  " + str(e)
              self.errorFiles.append(err)
              self.writetoLog()
              sys.exit()
        else:
            err = "Ignoring '" + data['fname'] + "' with the callsign '" + data['callsign'] + "'"
            print err
            self.errorFiles.append(err)


    def onlyascii(self,string):
        """
        converts string of chars to ascii
        """
        thelist = list(string)
        collector =[]
        for char in thelist:
            if ord(char) < 48 or ord(char) > 127: pass
            else: collector.append(char)
        return "".join(collector)


    def str2bin(self,string):
        """
        converts string of ascii to a binary representation
        """
        thelist = list(string)
        collector =[]
        for char in thelist:
            collector.append(self.ascii_to_bin(char))
        return "".join(collector)

    def ascii_to_bin(self,char):
        """
        converts ascii char (byte) to a binary representation
        """
        ascii = ord(char)
        bin = []

        while (ascii > 0):
            if (ascii & 1) == 1:
                bin.append("1")
            else:
                bin.append("0")
            ascii = ascii >> 1

        bin.reverse()
        binary = "".join(bin)
        zerofix = (8 - len(binary)) * '0'

        return zerofix + binary

    def bin2intStr(self,bin):
        """
        returns binary representation back to decimal string
        """
        if bin == "":
            return ""
        else:
            return str(int(bin,2))

    def str2intStr(self,string):
        """
            wrapper function:
            takes a string of ascii bytes
            converts each byte to a binary representation and concatonating each
            convert result back to decimal
        """
        res = self.str2bin(string)
        return self.bin2intStr(res)

    def getExtras(self):

        data                         = {}
        data['date_created']         = self.script_time
        data['source']               = "XBT Data"
        data['recorder_probe_notes'] = "See WMO code table 4770 for the information corresponding to the value "
        data['comment']              = "For more information on how to acknowlege distribute and cite this dataset " \
        "please refer to the IMOS website http://imos.org.au or access the eMII Metadata catalogue" \
        " http://imosmest.aodn.org.au and search for 'IMOS metadata record'"
        data['metadata']             = "http://imosmest.emii.org.au/geonetwork/srv/en/metadata.show?uuid=35234913-aa3c-48ec-b9a4-77f822f66ef8"
        data['project']              = "Integrated Marine Observing System (IMOS)"
        return data



    def writetoLog(self):

        self.status.append("\nSummary for processing BSD Files - " + self.script_time)
        self.status.append(str(self.handledFiles) + " Files Handled: ")
        self.status.append(str(self.newCount) + " New Processed files: ")
        # self.status.append(str(len(self.errorFiles)) + " Total Problems: ")

        self.status.append(str(len(self.badDataFiles)) + " Marked as having bad data")
        self.status.append("==============================")
        self.status.append("Problems:")
        for f in self.errorFiles:
            self.status.append(f)
        self.status.append("==============================")

        # print to console
        for f in self.status:
            #print f
            pass

        filename = self.logfilePath #+ os.path.sep +"processSBD_Report"

        if  os.path.isfile(filename):
            size =  os.path.getsize(filename)
            if size > 1000000:
                os.rename(filename , filename [0:-3] +"_"+ time.strftime('%x').replace('/','-') + ".log")
                None
        print "Writing to Log file: " +  filename
        log_file    =    open(filename,'a+')
        for line in self.status:
            log_file.write(line + "\r\n")
        log_file.close()



