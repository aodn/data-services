#!/usr/ bin/env python
# -*- coding: utf-8 -*-
import os, sys, time, threading
from subprocess import Popen, PIPE, STDOUT


class DatafabricConnection:


    def __init__(self):

        self.datafabricDir = "/home/matlab_3/datafabric_root"
        self.resetURL = " --no-check-certificate https://EMII_UPLOADER3:uNrg81D@df.arcs.org.au/ARCS/projects/IMOS?reset"
        self.home = os.getenv('HOME')  


    def connectDatafabric(self):

        status = False
        # Check the datafabric was successfully unmounted   
        connect_status = self.unconnectDatafabric() 
        # highly recommended reset!
        os.chdir('/tmp')
        os.system('wget -O /dev/null ' + self.resetURL)
        os.chdir(self.home)

        # 'connect_status' true is the datafabric is unmounted
        if connect_status:
            sts = os.system("mount " + self.datafabricDir)
            if sts == 0: # successfully run mount command
                if self.isDfMounted():
                    status = True
        # the datafabric is still mounted so lets use it if we can
        else:            
            status = True
            
        return status


    def unconnectDatafabric(self):

        status = True
      
        #unmount if the datafabric is mounted 
        if self.isDfMounted():

            # change working directory in case it is within the datafabric
            os.chdir(self.home) 

            p = Popen("umount  " + self.datafabricDir , shell=True, bufsize=0,  stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)  
            (stdout,stderr) = p.communicate() 
            if stdout.find("device is busy") != -1:
                print stdout
                print "ERROR: Could not disconnect from the datafabric. Try doing a reset (https://df.arcs.org.au/ARCS/home?reset) Try again or Disconnect manually by killing the datafabric process"
                os.chdir('/tmp')
                os.system('wget ' + self.resetURL)
                os.chdir(self.home)
                status = False
            else:
                print "Datafabric disconnect successful"

        else:
            print "Datafabric was not connected"
            

        return status

    def isDfMounted(self):
            p = Popen("mount | grep " + self.datafabricDir , shell=True, bufsize=0,  stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
            (stdout,stderr) = p.communicate()                 
            if stdout.find(self.datafabricDir) != -1:
                return True
            else: 
                return False
            

if __name__ == "__main__":
    pass