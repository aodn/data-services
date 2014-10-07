# -*- coding: utf-8 -*-
"""
Created on Tue Oct  7 11:45:44 2014
This script downloads a lev20 file (CSV) and unzip it in a tmp
folder aeronetUnZipFolder preferably such as /tmp/aeronet
@author: lbesnard

"""

def download_aeronetData (aeronetUnZipFolder):
    from BeautifulSoup import BeautifulSoup
    import urllib2,urllib
    import re
    import zipfile
    
    # we remove all *.lev20 files previously downloaded in aeronetUnZipFolder
    purge (aeronetUnZipFolder,'.*lev20$')
    
    # open NASA page where data url can be found 
    html_page = urllib2.urlopen("http://aeronet.gsfc.nasa.gov/cgi-bin/print_warning_opera_v2_new?site=Lucinda&year=110&month=6&day=1&year2=110&month2=6&day2=30&LEV20=1&AVG=10")
    soup = BeautifulSoup(html_page)
       
    # scrap webpage to find zip file address
    for link in  soup.findAll('a', attrs={'href': re.compile("^.zip")}):
        web_adress = 'http://aeronet.gsfc.nasa.gov' + link.get('href')
    
    
    aeronetZip = "/tmp/aeronet.zip"   
    downloadedFile = urllib.URLopener()
    print 'Download data file to '+ aeronetZip
    downloadedFile.retrieve(web_adress, aeronetZip)
         
    zip = zipfile.ZipFile(aeronetZip)  
    print 'Extract file to ' + aeronetUnZipFolder
    zip.extractall(aeronetUnZipFolder)  
    return 1
    

# function to get rid of files following a certain pattern in a specific dir
def purge(dir, pattern):
    import os, re

    for f in os.listdir(dir):
    	if re.search(pattern, f):
    		os.remove(os.path.join(dir, f))
    return 1 

from configobj import ConfigObj # to read a config file
import sys,os

if __name__ == "__main__":
    try:
        pathname = os.path.dirname(sys.argv[0])
        print pathname
        #print 'path =', pathname
        configFilePath = os.path.abspath(pathname)
        
        # we read here the database connection inputs
        config = ConfigObj(configFilePath +'/' + 'config.txt')          
        aeronetUnZipFolder = config.get('aeronetUnZip.path')
             
        if not os.path.exists(aeronetUnZipFolder):
            os.makedirs(aeronetUnZipFolder)
        
        download_aeronetData (aeronetUnZipFolder)
    except Exception, e:
        print 
