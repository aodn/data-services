#! /usr/bin/env python
#
# Read metadata and convert to csv

import re

metafile = 'meta_all.txt'
F = open(metafile)

ln = 0
fields = ''
values = ''
for line in F:
    if re.match('\s*$', line):    # empty line -> end of record
        if ln==0: print fields
        print values
        fields = ''
        values = ''
        ln += 1
        continue
    if re.match('elpased days', line): continue # don't need this field
    if re.match('Set details', line):
        m = re.findall('(\D+)\s*([-\d]+)\s*(.*)\s+(\d+)\s*k', line[40:].strip())
        if m:
            fields += 'site,year,loggerID,freq (kHz),'
            site, yr, logid, freq = m[0]
            values += site+','+yr+','+logid+','+freq+','
            continue
    if re.match('Latitude', line) or re.match('Longitude', line):
        m = re.findall("(\S+)\s*deg\s*(\S+)'", line)
        if m:
            fields += line[:40].strip()+','
            val = float(m[0][0]) + float(m[0][1])/60
            values += str(val)+','
            continue
    fields += '"'+line[:40].strip()+'",'
    values += '"'+line[40:].strip()+'",'

