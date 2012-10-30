#! /usr/bin/env python
#
# Read metadata and convert to csv

import re, sys


# convert Rob's "Set details" field into site code, deployment name, logger id, frequency and position
def setDetails(value):
    
    code = name = logID = freq = pos = ''

    m = re.findall('(\D+\s*[-\d]+)\s*(.*)', value)
    if m:
        name = m[0][0]
        therest = m[0][1]
        if re.match('.*Canyon', name):
            name = re.sub('.*Canyon', 'Perth Canyon, WA', name)
            code = 'PAPCA'
        elif re.match('Portland', name):
            name = re.sub('Portland( IMOS)?', 'Portland, VIC', name)
            code = 'PAPOR'
        elif re.match('NSW', name):
            name = re.sub('NSW', 'Sydney, NSW', name)
            code = 'PASYD'
        name = re.sub(' (\d{2})-(\d{2}\D?)', ' 20\\1-20\\2', name)
    else: 
        therest = value

    m = re.findall('E\d+', therest)
    if m: 
        logID = m[0]
        therest = therest.replace(logID, '')

    m = re.findall('(\d+)\s*k', therest)
    if m: 
        freq = m[0]
        therest = therest.replace(freq, '')

    m = re.findall('P\d+', therest)
    if m: pos = m[0]

    return code, name, logID, freq, pos




### Main ##################################################################

if len(sys.argv) < 2:
    print 'usage: readMetadata.py metadata_file.txt'
    exit()

metafile = sys.argv[1]
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
        rowDict['site code'], rowDict['deployment name'], rowDict['loggerID'], rowDict['freq'], rowDict['position'] = setDetails(value) 
        continue

    if re.match('Latitude', field) or re.match('Longitude', field):
        m = re.findall("(\S+)\s*deg\s*(\S+)'", value)
        if m:
            value = float(m[0][0]) + float(m[0][1])/60

    if re.match('first/last sample in water', field):
        m = re.findall('(\d+)\s*-\s*(\d+)', value)
        if m:
            rowDict['first_wet_sample'] = int(m[0][0])
            rowDict['last_wet_sample'] = int(m[0][1])
        continue

    if re.match('start.*UTC', field):
        value += ' UTC'


    rowDict[field] = value

F.close()



# now print out what we want
printFields = ['Curtin ID',
               'site code',
               'loggerID', 
               'deployment name', 
               'primary?',
               'start first sample (UTC)',
               'start last sample (UTC)',
               'data path',
               'freq',
               'position',
               'Set success',
               'GBytes',
               'Latitude (WGS84)',
               'Longitude (WGS84)',
               'water depth (m)',
               'receiver depth (m)',
               'start first sample in water (UTC)',
               'start last sample in water (UTC)',
               'first_wet_sample',
               'last_wet_sample',
               'system gain file',
               'hydrophone serial number',
               'hydrophone sensitivity (dB re V^2/Pa^2)',
               'notes']

print ','.join(printFields)
for rowDict in allRows:
    values = []

    for field in printFields:

        if not rowDict.has_key(field):
            values.append('NULL')
            continue

        value = rowDict[field]

        try: 
            float(value)
            values.append(str(value))
        except: 
            if value == ''  or  re.match('not', value):
                values.append('NULL')
            else:
                values.append("'" + value + "'")

    print ','.join(values)


