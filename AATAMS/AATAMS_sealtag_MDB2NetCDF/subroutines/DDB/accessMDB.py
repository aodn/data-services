#!/bin/env python
# -*- coding: utf-8 -*-
# sudo apt-get install unixodbc
# Example to run the script:
# python accessMDB.py '/home/lbesnard//Desktop/ct36.mdb' 'SELECT * FROM ctd' '/home/lbesnard/output.csv'
import subprocess, os,sys
import pyodbc
import csv

#MDB = sys.argv[1]
MDB=  '/home/lbesnard/Desktop/ct36.mdb'
DRV='IMDBTools'
#DRV = '{Microsoft Access Driver (*.mdb)}'
PWD = ''
#conn = pyodbc.connect('DRIVER=%s;DBQ=%s;PWD=%s' % (DRV,MDB,PWD))
conn = pyodbc.connect('DRIVER=%s;DBQ=%s' % (DRV,MDB))
curs = conn.cursor()

#SQL = sys.argv[1]; # insert your query here
#SQL='SELECT ref FROM ctd;'
#curs.execute(SQL)
#print curs.execute(SQL)
curs.execute('SELECT * FROM cruise')
rows = curs.fetchall()

curs.close()
conn.close()

# you could change the 'w' to 'a' for subsequent queries
#csv_writer = csv.writer(open('/home/lbesnard/output.csv', 'wb'), lineterminator='\n')

for row in rows:
    csv_writer.writerow(row)