# Deakin University Bathymetry
# process to create netcdf files from the TIF sent by Deakin university

# related to https://github.com/aodn/content/issues/504#issuecomment-1208912733


####################################
# CREATE CLOUD OPTIMISED GEO TIFF 
####################################
# 1. download original tif from: http://imos-data.s3-website-ap-southeast-2.amazonaws.com/?prefix=Deakin_University/bathymetry/

# 2. using python 3.6.10 in pyenv
pip install rio-cogeo
rio cogeo create Victorian-coast_Bathy_10m.tif Victorian-coast_Bathy_10m_cog.tif

# 3. final check: 
rio cogeo validate https://s3-ap-southeast-2.amazonaws.com/imos-data/Deakin_University/bathymetry/Victorian-coast_Bathy_10m_cog.tif
--> valid cloud optimized GeoTIFF

# 4. push new file to ASYNC_UPLOAD incoming folder

# 5. check metadata is updated accordingly

