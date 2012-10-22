#! /usr/bin/env python
#
# Read metadata and convert to csv

import re

metafile = 'meta_all.txt'
F = open(metafile)

# read in all records into a list of dictionaries
rowDict = {}
allRows = []
for line in F:

    if re.match('\s*$', line):    # empty line -> end of record
        allRows.append(rowDict)
        rowDict = {}
        continue

    field = line[:40].strip()
    value = line[40:].strip()

    if re.match('Set details', field):
        m = re.findall('(\D+)\s*([-\d]+)\s*(.*)\s+(\d+)\s*k', value)
        if m:
            rowDict['site'] = m[0][0]
            rowDict['year'] = m[0][1]
            rowDict['loggerID'] = m[0][2]
            rowDict['freq'] = m[0][3]
            continue

    if re.match('Latitude', field) or re.match('Longitude', field):
        m = re.findall("(\S+)\s*deg\s*(\S+)'", value)
        if m:
            value = float(m[0][0]) + float(m[0][1])/60

    try: value = float(value)
    except: pass

    rowDict[field] = value

F.close()



# now print out what we want
printFields = ['Curtin ID',
               'site', 
               'year', 
               'loggerID', 
               'freq',
               'Set success',
               'GBytes',
               'Latitude (WGS84)',
               'Longitude (WGS84)',
               'water depth (m)',
               'receiver depth (m)',
               'start first sample (UTC)',
               'start last sample (UTC)',
               'start first sample in water (UTC)',
               'start last sample in water (UTC)',
               'first/last sample in water (# samp)',
               'mean sample length/increment (s/min)',
               'system gain file',
               'hydrophone serial number',
               'hydrophone sensitivity (dB re V^2/Pa^2)',
               'notes']

print ','.join(printFields)
for rowDict in allRows:
    values = []
    for field in printFields:
        if not rowDict.has_key(field):
            values.append('')
            continue
        value = rowDict[field]
        if type(value) == str:
            values.append('"' + value + '"')
        else:
            values.append(str(value))

    print ','.join(values)


