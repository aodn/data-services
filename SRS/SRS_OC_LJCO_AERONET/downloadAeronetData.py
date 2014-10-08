#!/usr/bin/python
# -*- coding: utf-8 -*-
"""
Created on Tue Oct  7 11:45:44 2014
This script downloads a lev20 file (CSV) and unzip it in the IMOS public folder
/SRS/SRS-OC-LJCO/AERONET

@author: lbesnard
laurent.besnard@utas.edu.au
"""

from configobj import ConfigObj # to read a config file
import sys,os
import logging


def downloadAeronetData(nasaLev2Webpage,aeronetDataFolder):
    from BeautifulSoup import BeautifulSoup
    import urllib2,urllib
    import re
    import zipfile
    import tempfile
    from urllib import urlopen
    from StringIO import StringIO

    logging.basicConfig(level=logging.INFO)
    logger      = logging.getLogger(__name__)
    logger.setLevel(logging.INFO)

    # create a file handler    
    handler     = logging.FileHandler(logfile)
    handler.setLevel(logging.INFO)

    # create a logging format    
    formatter   = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    handler.setFormatter(formatter)
    
    # add the handlers to the logger    
    logger.addHandler(handler)
    

    purge (aeronetDataFolder,'.*lev20$')
    logger.info('Removed previous AERONET *.lev20  data files from ' + aeronetDataFolder)

    logger.info('Open NASA webpage')
    htmlPage       = urllib2.urlopen(nasaLev2Webpage)
    htmlPageSoup   = BeautifulSoup(htmlPage)
    

    # scrap webpage to find zip file address
    webpageBase, value = nasaLev2Webpage.split("/cgi-bin",1)
    for link in htmlPageSoup.findAll('a', attrs={'href': re.compile("^.zip")}):
        dataWebLink = webpageBase + link.get('href')

    logger.info('Download AERONET data')
    urlDataObject   = urlopen(dataWebLink)

    zipData = zipfile.ZipFile(StringIO(urlDataObject.read()))
    zipData.extractall(aeronetDataFolder)  
        
    logger.info('AERONET data extracted to ' + aeronetDataFolder)

    return True
    

# function to get rid of files following a certain pattern in a specific dir
def purge(dir, pattern):
    import os, re

    for f in os.listdir(dir):
        if re.search(pattern, f):
            os.remove(os.path.join(dir, f))

    return True


if __name__ == "__main__":
    
    try:
        pathname            = os.path.dirname(sys.argv[0])
        #print pathname

        # information from config.txt
        ConfigFilePath      = os.path.abspath(pathname )
        config              = ConfigObj(ConfigFilePath +'/' + 'config.txt')          
        aeronetDataFolder   = config.get('aeronetData.path')        
        nasaLev2Webpage     = config.get('nasaLev2.webpage')

        global logfile
        logfile             = config.get('logfile.path')

        if not os.path.exists(aeronetDataFolder):
            os.makedirs(aeronetDataFolder)
            
        downloadAeronetData(nasaLev2Webpage,aeronetDataFolder)

    except Exception, e:
        print e
