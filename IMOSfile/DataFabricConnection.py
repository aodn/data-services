#!/usr/bin/env python
# -*- coding: utf-8 -*-
import os, sys
from subprocess import Popen, PIPE, STDOUT


class DatafabricConnection:


    def __init__(self):
        """        
            This file used to manage connection to the Datafabric.
            Now connections are  auto-mounted  
                    
        """

        self.datafabricDir = "/df"
        


    def connectDatafabric(self):
        return self.isDfMounted()


    def unconnectDatafabric(self):
        """
            Leave it up to automounter to disconnect
        """
        
        return True

    def isDfMounted(self):
        """
            # stat on the directory to trigger automount
            # Then check the output of mount
        """
        
        os.system('ls  ' + self.datafabricDir)
        p = Popen("mount | grep " + self.datafabricDir , shell=True, bufsize=0,  stdin=PIPE, stdout=PIPE, stderr=STDOUT, close_fds=True)
        (stdout,stderr) = p.communicate()                 
        if stdout.find(self.datafabricDir) != -1:
            return True
        else: 
            return False
                

        
        
            

if __name__ == "__main__":
    
    d = DatafabricConnection()

    if (d.connectDatafabric()) :
        print "It seems the Automount is fine"
    else:
        print "It seems Automount isnt working"

