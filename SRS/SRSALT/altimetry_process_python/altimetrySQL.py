#!/bin/env python
# -*- coding: utf-8 -*-
# SRS - Altimetry Data
# this script list all the files found in the folder altimetryData.path (from config.txt) and then 
# populates a table. This table is then used by geoserver. 
# if a file does not exist in the table, it is automatically added up. Otherwise, it's not.
#
# before launching this code , please be sure to modify the netcdf filename so they have a depth information.
#
# Author: Laurent Besnard
# Institute: IMOS / eMII
# email address: laurent.besnard@utas.edu.au
# Website: http://imos.aodn.org.au/imos/
# May 2013; Last revision: 5-May-2013
#
# Copyright 2013 IMOS
# The script is distributed under the terms of the GNU General Public License


    
import re
from imosNetCDF import *
from netCDF4 import Dataset
import psycopg2
import sys,os
from configobj import ConfigObj # to read a config file

if __name__ == "__main__":
    try:          
        pathname = os.path.dirname(sys.argv[0])
        print pathname
        #print 'path =', pathname
        configFilePath=os.path.abspath(pathname )
        print   configFilePath  
        # we read here the database connection inputs
        config = ConfigObj(configFilePath +'/' + 'config.txt')            
        db_server = config.get('server.address')
        db_dbname = config.get('server.database')     
        db_user = config.get('server.user')     
        db_password = config.get('server.password')     
        db_port = config.get('server.port')
        altimetryDataFolder = config.get('altimetryData.path')
        
        
        #create dictionnary with stationName and station location since this should never change. This information could eventually been written in the config file.
        stations = {'SRSBAS': [-43.3 ,147.661,'78d588ed-79dd-47e2-b806-d39025194e7e'], 'SRSSTO': [-40.65 ,145.594,'78d588ed-79dd-47e2-b806-d39025194e7e']}
        #print stations.keys()
        #print stations.values()
        
        # recursive listing of all srs altimetry files found in altimetryDataFolder
        fileList = []
        rootdir = altimetryDataFolder 
        for root, subFolders, files in os.walk(rootdir):
            for file in files :
                fileList.append(os.path.join(root,file))
                
        
        ## populate database
        
        # Regexp 
        pattern='(SRS[A-Z]{3})/([a-zA-Z0-9_\-]*)/(IMOS[a-zA-Z0-9_\-]*\.nc)' # pattern to find station name, instrument name and netcdf file
        for ncFile in fileList:
            ncFile_DATA = Dataset(ncFile)
            metadata = getAttNC(ncFile_DATA)
            time_coverage_start = metadata['time_coverage_start']
            time_coverage_end = metadata['time_coverage_end']
            title = metadata['title']
            depth = ncFile_DATA.variables['DEPTH'][0]
            
            matchStr =  re.findall (pattern, ncFile)
            stationName = matchStr[0][0]
            instrumentName = matchStr[0][1]
            fileName = matchStr[0][2]
            
            #database connection
            con = None    
            try:
                
                con = psycopg2.connect(database = db_dbname, user= db_user , password=db_password , host = db_server , port = db_port) # connect to the database
                cur = con.cursor()
                
                # look through all the files, and insert in table ONLY if filename does not already exist. The database has been created previously with a sequence
                insertString = "INSERT INTO srs_altimetry.data ( site_code,abstract,metadata_uuid,sensor_name,filename,time_coverage_start,time_coverage_end,lat,lon,sensor_depth) " \
                             + "SELECT '%s','%s','%s','%s','%s','%s','%s',%f,%f,%f  WHERE NOT EXISTS (SELECT pkid FROM srs_altimetry.data WHERE filename = '%s') ;" \
                             % (stationName,title,stations[stationName][2],instrumentName,fileName,time_coverage_start,time_coverage_end,stations[stationName][0],stations[stationName][1],depth,fileName)     
                cur.execute(insertString)
                
                # update geom
                cur.execute('UPDATE srs_altimetry.data SET geom = PointFromText(\'POINT(\' || lon || \' \' || lat || \')\',4326);')
                print insertString
                
                a = con.commit()
                
            except psycopg2.DatabaseError, e:
                print 'Error %s' % e    
                sys.exit(1)        
            finally:        
                if con:
                    con.close()
            
    except Exception, e:
        print ("ERROR: " + str(e))
