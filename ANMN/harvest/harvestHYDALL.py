#! /usr/bin/env python
#
# Read data from an NRS Nutrients file (Excel) and store
# store it in the report database.

from psycopg2 import connect
import argparse
from IMOSfile.IMOSbgc import harvestBGC,fStr,fFloat,fInt


# List of columns in spreadsheet and how they should be transferred
# into database
#           name in Excel              name in db          format
column = [['Time',                     'sample_time',       '%s'  ],
          ['Station Code',             'site_code',         fStr  ],
          ['Latitude',                 'sample_lat',        fFloat],
          ['Longitude',                'sample_lon',        fFloat],
          ['Depth',                    'sample_depth',      fFloat],
          ['Salinity',                 'salinity',          fFloat],
          ['Salinity QC Flag',         'salinity_qc',       fInt  ],
          ['Oxygen',                   'oxygen',            fFloat],
          ['Oxygen QC Flag',           'oxygen_qc',         fInt  ],
          ['Silicate',                 'silicate',          fFloat],
          ['Silicate QC Flag',         'silicate_qc',       fInt  ],
          ['Nitrate/Nitrite',          'nitrate_nitrite',   fFloat],
          ['Nitrate/Nitrite QC Flag',  'nitrate_nitrite_qc',fInt  ], 
          ['Phosphate',                'phosphate',         fFloat],             
          ['Phosphate QC Flag',        'phosphate_qc',      fInt  ],
          ['Ammonium',                 'ammonium',          fFloat],            
          ['Ammonium QC Flag',         'ammonium_qc',       fInt  ],
          ['Sample QC comment',        'sample_comment',    fStr  ]]  


# get filename from command line
parser = argparse.ArgumentParser() 
parser.add_argument('file', help='IMOS HYDALL.xls file')
args = parser.parse_args()

# connect to database
host = 'dbdev.emii.org.au'
db = 'report_db'
user = 'report'
table = 'anmn.nrs_hydall'
conn = connect(host=host, user=user, database=db)
if not conn:
    print 'Failed to connect to database!'
    exit()
print 'Connected to %s database on %s' % (db, host)

# do the harvest
harvestBGC(args.file, column, conn, table)

# close db connection
conn.close()
