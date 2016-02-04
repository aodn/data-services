#!/usr/bin/env python

"""
Fix metadata issues in GHRSST SST files.

+ + + WARNING + + +
This script modifies the file IN PLACE
so the input file is modified.
+ + + + + + + + + + + + +

Note that there has been a bug in the netCDF libraries that in some versions means
it won't update an existing attribute. To work around that, we always delete an
attribute and then rewrite it.
"""

import sys
import netCDF4
import shutil
import re

if len(sys.argv) != 2:
    sys.exit('Usage: bom_ghrsst_to_cf.py  %s' % sys.argv[0])

netcdf_filepath = sys.argv[1]
nc = netCDF4.Dataset(netcdf_filepath, "a")

# Bodgy conventions
if 'Conventions' in nc.ncattrs():
    if nc.getncattr('Conventions') == 'CF-1.7':
        del nc.Conventions
        nc.Conventions = 'CF-1.6'

    elif nc.getncattr('Conventions') == 'pseudo CF-1.4?':
        del nc.Conventions
        nc.Conventions = 'CF-1.6'

# Irritating error in the definition of CSIRO
if 'acknowledgment' in nc.ncattrs():
    if 'Commonwealth Scientific and Research' in nc.acknowledgment:
        a = nc.acknowledgment
        del nc.acknowledgment
        nc.acknowledgment = a.replace('Scientific and Research', 'Scientific and Industrial Research')

# Missing calendar attribute for time dimension/variable
if 'time' in nc.variables:
    time = nc.variables['time']
    if 'calendar' not in time.ncattrs():
        time.calendar = 'gregorian'

# Superfluous scaling parameters for a natively-int variable
if 'quality_level' in nc.variables:
    quality_level = nc.variables['quality_level']
    if 'add_offset' in quality_level.ncattrs():
        del quality_level.add_offset
    if 'scale_factor' in quality_level.ncattrs():
        del quality_level.scale_factor

# elements of the flag_meanings string should be space-separated, not comma-separated
if 'l2p_flags' in nc.variables:
    l2p_flags = nc.variables['l2p_flags']
    if 'flag_meanings' in l2p_flags.ncattrs():
        a = ' '.join([x.replace(',','') for x in l2p_flags.flag_meanings.split()])
        del l2p_flags.flag_meanings
        l2p_flags.flag_meanings = a

# Invalid standard_name on sst variables
if 'sea_surface_temperature' in nc.variables:
    sst = nc.variables['sea_surface_temperature']
    if 'standard_name' in sst.ncattrs():
        if sst.standard_name == 'experimental_sea_surface_skin_temperature':
            del sst.standard_name
            sst.standard_name = 'sea_surface_skin_temperature'
if 'sea_surface_temperature_day_night' in nc.variables:
    sst = nc.variables['sea_surface_temperature_day_night']
    if 'standard_name' in sst.ncattrs():
        if sst.standard_name == 'experimental_sea_surface_skin_temperature':
            del sst.standard_name
            sst.standard_name = 'sea_surface_skin_temperature'

nc.close()

netcdf_new_filepath = re.sub('-v0.*-fv0.*.nc.*', '.nc', netcdf_filepath)
shutil.move(netcdf_filepath, netcdf_new_filepath)

print netcdf_new_filepath
