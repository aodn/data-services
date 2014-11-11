#!/usr/bin/env python
#
# mdb2psql.py
# Script to convert a Microsoft Access Database into a PostGreSQL on a LINUX system. Requires bash, sed
# 
# It depends upon the mdbtools suite:
#   http://sourceforge.net/projects/mdbtools/
# To install this package on Ubuntu/Debian
#	sudo apt-get install mdbtools
#	launche the gui with :gmdb2
#
# This python script fixes some issues during the convertion with mdbtools doing some simple sed replacements.
# The time string is also modified to be handled properly by postgres assuming the time is in the format %d-%m-%Y %H:%M:%S
# check strftime in order to change this
#
# Example to run the script:
# python mdb2psql.py ct78d.mdb >ct78d.sql
# psql -h localhost -U postgres -w -d DATABASE -f ct78d.sql
#
#
# code inspired from http://www.guyrutenberg.com/2012/07/16/sql-dump-for-ms-access-databases-mdb-files-on-linux/#more-1088
# Contact: laurent.besnard@utas.edu.au


import sys, subprocess, os
 
DATABASE = sys.argv[1]
BACKEND  = "postgres" #Specifies target DDL dialect. Supported values are access, sybase, oracle, postgres, and mysql

# Dump the schema for the DB. Removes primary key relation, dropt table
# each field is in double quote for the TABLE creation
##shellCommand="mdb-schema --drop-table --no-relations "+DATABASE+" "+ BACKEND +" |sed 's/Postgres_Unknown 0x10/numeric/g' | sed 's/Postgres_Unknown 0x0c/text/g'| sed 's/CREATE UNIQUE INDEX/CREATE INDEX/g'"    
shellCommand="mdb-schema --no-relations "+DATABASE+" "+ BACKEND +" |sed 's/Postgres_Unknown 0x10/numeric/g' | sed 's/Postgres_Unknown 0x0c/text/g'| sed 's/CREATE UNIQUE INDEX/CREATE INDEX/g'"    

#print shellCommand
os.system(shellCommand)

 
# list table names
table_names = subprocess.Popen(["mdb-tables", "-1", DATABASE],
                               stdout=subprocess.PIPE).communicate()[0]
tables = table_names.splitlines()
 
print "BEGIN;" # start a transaction, speeds things up when importing
sys.stdout.flush()
 
# Dump each table 
for table in tables:
    if table != '':
    	# each field is in single quote for the INSERT as some field names might be in upper case
		shellCommand="mdb-export -q \\' -D \"%d-%m-%Y %H:%M:%S\"  -I "+BACKEND+" "+DATABASE+" "+table  # check time string from strftime
		os.system(shellCommand)

print "COMMIT;" 
sys.stdout.flush()
