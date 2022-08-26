# Deakin University Bathymetry
# process to create netcdf files from the TIF sent by Deakin university

# work done ages ago by Guillaume Galibert (AODN)

################################
# CONVERT FROM TIF TO NETCDF
################################
# in python
# note at the time the decision was made to use double precision
# making the netcdf file big for both, original resolution of 10m and 
# 500m used by the AODN portal
    - deakin-uni_BIG_geotiff2netcdf.py
    - deakin-uni_BIG_geotiff2netcdf@500m.py

# if the size of the netcdf file ever becomes a problem, could make everything
# single precision


#####################################
# CONVERT FROM TIF TO PACKED NETCDF
#####################################
# attempt to decrease the size
# not used in portal but can be useful
    - deakin-uni_BIG_geotiff2netcdf@500m_packed.py
    - deakin-uni_BIG_geotiff2netcdf_packed.py

#########################################
# CREATE REGRIDDED NETCDF
#########################################
# This step is necessary for the AODN Portal to easily read the 
# netcdf file. This is only to straighten the grid
    - scripts/Deakin_regridding/regridFile.m

######################################
# Extra notes
######################################
# in scripts/Matlab/ are Matlab scripts for similar
# convertion but only the Python scripts were used 
# in creating the netcdf

