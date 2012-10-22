#! /usr/bin/env python
#
# Read metadata and convert to csv

import re


fields = ['Curtin ID',
          'Set details',
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
          'elpased days',
          'first/last sample in water (# samp)',
          'mean sample length/increment (s/min)',
          'system clock set 1',
          'system clock set 2',
          'clock drift (s) (s/day)',
          'system gain file',
          'hydrophone serial number',
          'hydrophone sensitivity (dB re V^2/Pa^2)',
          'notes'
]
nfields = len(fields)


# metafile = 'IMOS_NSW_2010_2011_PA_MetaData.txt'
metafile = 'IMOS_PassiveAcoustics_20110401.txt'
F = open(metafile)


f = 0
row = ''
for line in F:
    if re.match('\s*$', line): continue   # empty line
    value = re.findall(fields[f]+'\s+(.*\S)\s*', line)
    if value: row += value[0]
    row += ','
    f = (f+1) % nfields
    if f==0: 
        print row
        row = ''

