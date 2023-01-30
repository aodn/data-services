# -*- coding: utf-8 -*-
"""
Created on Thu Mar  9 14:29:59 2017

@author: ggalibert
ex.: python deakin-uni_geotiff2netcdf.py PPB_Bathy_10m_Clipped.tif
"""
import sys
import os
import numpy as np
import osr
import gdal
import netCDF4
from pyproj import Proj, transform
import datetime as dt

#bathyFile = sys.argv[1]
#bathyFile = 'PPB_Bathy_10m_Clipped.tif'
bathyFile = 'Victorian-coast_Bathy_10m.tif'
 
if not os.path.isfile(bathyFile):
    sys.exit(bathyFile + ' does not exist.')

bathyRadical, bathyExt = os.path.splitext(bathyFile)

# read input tif dataset
ds = gdal.Open(bathyFile)

bbox    = ds.GetGeoTransform()
srs_wkt = ds.GetProjection()
band    = ds.GetRasterBand(1)
nX      = ds.RasterXSize
nY      = ds.RasterYSize

nodata_value       = band.GetNoDataValue()
[nXBlock, nYBlock] = band.GetBlockSize()
nXBlock = nXBlock * 10
nYBlock = nYBlock * 10

# set an srs from the input file wkt projection string
srs_transform = osr.SpatialReference()
srs_transform.ImportFromWkt(srs_wkt)

# define input and output projections
inProj  = Proj(srs_transform.ExportToProj4())
outProj = Proj(init='epsg:4326') # WGS84

# write output NetCDF file
nc = netCDF4.Dataset(bathyRadical + '.nc', 'w')

# create dimensions, variables and attributes:
nc.createDimension('Y', nY)
nc.createDimension('X', nX)

nc_y = nc.createVariable('Y', 'f8', 'Y')
nc_y.long_name       = 'y coordinate of projection'
nc_y.standard_name   = 'projection_y_coordinate'
nc_y.units           = 'm'
nc_y.axis            = 'Y'
nc_y.valid_min       = np.float64(-40000000.0)
nc_y.valid_max       = np.float64(40000000.0)
nc_y.reference_datum = 'VICGRID94 projection (EPSG:3111)'

nc_x = nc.createVariable('X', 'f8', 'X')
nc_x.long_name       = 'x coordinate of projection'
nc_x.standard_name   = 'projection_x_coordinate'
nc_x.units           = 'm'
nc_x.axis            = 'X'
nc_x.valid_min       = np.float64(-40100000.0)
nc_x.valid_max       = np.float64(40100000.0)
nc_x.reference_datum = 'VICGRID94 projection (EPSG:3111)'

nc_lat = nc.createVariable('LATITUDE', 'f8', ('Y', 'X'))
nc_lat.long_name       = 'latitude'
nc_lat.standard_name   = 'latitude'
nc_lat.units           = 'degrees_north'
nc_lat.valid_min       = np.float64(-90.0)
nc_lat.valid_max       = np.float64(90.0)
nc_lat.reference_datum = 'WGS84 coordinate reference system (EPSG:4326)'

nc_lon = nc.createVariable('LONGITUDE', 'f8', ('Y', 'X'))
nc_lon.long_name       = 'longitude'
nc_lon.standard_name   = 'longitude'
nc_lon.units           = 'degrees_east'
nc_lon.valid_min       = np.float64(-180.0)
nc_lon.valid_max       = np.float64(180.0)
nc_lon.reference_datum = 'WGS84 coordinate reference system (EPSG:4326)'

# create container variable for CRS: lon/lat WGS84 datum
nc_crs = nc.createVariable('CRS', 'i4')
nc_crs.long_name                   = 'WGS84 lat/lon coordinate reference system'
nc_crs.grid_mapping_name           = 'latitude_longitude'
nc_crs.epsg_code                   = 'EPSG:4326'
nc_crs.longitude_of_prime_meridian = 0.0
nc_crs.semi_major_axis             = 6378137.0
nc_crs.inverse_flattening          = 298.257223563

nc_height = nc.createVariable('HEIGHT', 'f4', ('Y', 'X'), zlib=True, 
                            fill_value=np.float32(99999))
nc_height.long_name       = 'height'
nc_height.standard_name   = 'height'
nc_height.units           = 'm'
nc_height.positive        = 'up'
nc_height.grid_mapping    = 'CRS'
nc_height.coordinates     = 'LATITUDE LONGITUDE'
nc_height.valid_min       = np.float32(-12000)
nc_height.valid_max       = np.float32(9000)
nc_height.reference_datum = 'AHD71 vertical datum (EPSG:5711)'

vertical_min = np.float32('NaN')
vertical_max = np.float32('NaN')
                                           
lat_min = np.float32('NaN')
lat_max = np.float32('NaN')
lon_min = np.float32('NaN')
lon_max = np.float32('NaN')

nc_y[:] = np.arange(nY) * bbox[5] + bbox[3]
nc_x[:] = np.arange(nX) * bbox[1] + bbox[0]

for i in xrange(0, nY, nYBlock):
    if i + nYBlock < nY:
        rows = nYBlock
    else:
        rows = nY - i
        
    for j in xrange(0, nX, nXBlock):
        if j + nXBlock < nX:
            cols = nXBlock
        else:
            cols = nX - j
            
        data = ds.ReadAsArray(j, i, cols, rows)
        
        data[data == nodata_value] = np.float32('NaN') # set no data values to NaN

        vertical_min = np.nanmin([np.nanmin(np.nanmin(data)), vertical_min])
        vertical_max = np.nanmax([np.nanmax(np.nanmax(data)), vertical_max])

        X = np.arange(j, j+cols, 1) * bbox[1] + bbox[0]
        Y = np.arange(i, i+rows, 1) * bbox[5] + bbox[3]
        
        # apply transformation
        x, y = np.meshgrid(X, Y)
        lon, lat = transform(inProj, outProj, x, y)
        
        lat_min = np.nanmin([np.nanmin(np.nanmin(lat)), lat_min])
        lat_max = np.nanmax([np.nanmax(np.nanmax(lat)), lat_max])
        lon_min = np.nanmin([np.nanmin(np.nanmin(lon)), lon_min])
        lon_max = np.nanmax([np.nanmax(np.nanmax(lon)), lon_max])
        
        # write lon,lat,depth
        nc_lon[i:i+rows,j:j+cols] = lon
        nc_lat[i:i+rows,j:j+cols] = lat
        
        # replace NaNs by _FillValue
        data[np.isnan(data)] = np.float32(99999)
        
        nc_height[i:i+rows,j:j+cols] = data

        del data

# create global attributes
nc.project = 'Cooperative Research Centre for Spatial Information (CRCSI)'
nc.Conventions = 'CF-1.6,IMOS-1.4'
nc.standard_name_vocabulary = ('NetCDF Climate and Forecast (CF) Metadata '
                                'Convention Standard Name Table Version 29')
nc.title = 'Victorian Coastal Digital Elevation Model (VCDEM 2017) 10m resolution.'
nc.institution = 'Cooperative Research Centre for Spatial Information (CRCSI)'
nc.institution_references = 'http://www.crcsi.com.au/'
datetime_now = dt.datetime.utcnow()
nc.date_created = datetime_now.strftime('%Y-%m-%dT%H:%M:%SZ')
nc.abstract = ('A gap free Digital Elevation Model (DEM) for the Victorian '
               'Coastal region created from the Updated High Resolution 2.5m '
               'VCDEM as well as parts of the Shuttle Radar Topography Mission '
               '(SRTM) 1 Second DEM, the Australian Bathymetry and Topography '
               'grid and a 10m DEM of Port Phillip Bay (PPB) that were provided '
               'for this project. This product uses a combination of low '
               'resolution data and interpolation techniques to provide a DEM '
               'that appears representative of the bathymetry in the Victorian '
               'Coastal Region.')
nc.lineage = ('The Continuous Seamless 10m DEM is derived from the Updated '
              'High Resolution 2.5m VCDEM as well as parts of the SRTM 1 '
              'second DEM data and the Australian Bathymetry and Topography '
              'grid with all gaps interpolated smoothly to create a '
              'comprehensive gap free DEM for the Victorian Coastal Region.\n'
              'Positional Accuracy: The final product is derived from various '
              'data sources - from DELWP, Port of Melbourne, Deakin University, '
              'CRCSI, Royal Australian Navy, and Geoscience Australia.\n'
              'The 2010 VCDEM product consisted of a 1m Topography DEM and 2.5m '
              'Bathymetry product that covered 90% of the Updated High '
              'Resolution DEM. The 1m Topography DEM is stated to have a '
              'horizontal accuracy of ± 35cm and a vertical accuracy of '
              '± 10cm @ 68% confidence interval. The 2.5m Bathymetry DEM '
              'accuracy meets the International Hydrographic Organization '
              '(IHO) Order 1 specifications of ± 50cm vertical and ± 3.17m '
              'horizontal accuracy @ 2σ.\n'
              'The multibeam data obtained from Deakin University was acquired '
              'using a Kongsberg EM 2040 MBES with a capability of achieving '
              'IHO Order of Special for hydrographic standard. The final '
              'accuracy of the data acquired exceeded that required for Order '
              '1b of the IHO S-44 standard for hydrographic surveys.\n'
              'MBES and LiDAR data obtained from Port of Melbourne was acquired '
              'using systems designed to meet IHO Order 1 for horizontal and '
              'vertical accuracy.\n'
              'Reprojection, aggregation, resampling and slight re-alignment of '
              'datasets will have had a negative impact on the final accuracy.\n'
              'Original Datums were as follows:\n'
              'Vertical Datum: AHD71 (EPSG:5711)\n'
              'Horizontal Datum GDA94 - Projection: VicGrid 94 (EPSG:3111).\n')
nc.naming_authority = 'IMOS'
nc.geospatial_lat_min = lat_min
nc.geospatial_lat_max = lat_max
nc.geospatial_lat_units = 'degrees_north'
nc.geospatial_lon_min = lon_min
nc.geospatial_lon_max = lon_max
nc.geospatial_lon_units = 'degrees_east'
nc.geospatial_vertical_min = vertical_min
nc.geospatial_vertical_max = vertical_max
nc.geospatial_vertical_positive = 'up'
nc.geospatial_vertical_units = 'metres'
nc.data_centre = 'Australian Ocean Data Network (AODN)'
nc.data_centre_email = 'info@aodn.org.au'
nc.author = 'Quadros, Nathan'
nc.author_email = 'nquadros@crcsi.com.au'
nc.point_of_contact = 'Ierodiaconou, Daniel'
nc.point_of_contact_email = 'iero@deakin.edu.au'
nc.citation = ('The citation in a list of references is: "Cooperative Research '
               'Centre for Spatial Information (CRCSI), [year-of-data-download], '
               'Victorian Coastal Digital Elevation Model (VCDEM 2017), '
               '[data-access-url], accessed [date-of-access]."')
nc.acknowledgement = ('Any users of CRCSI data are required to clearly acknowledge '
                      'the source of the material in the format: "Data was sourced '
                      'from the Cooperative Research Centre for Spatial Information '
                      '(CRCSI). The following organisations were involved in the '
                       'collection of the data: Department of Environment, Land, '
                       'Water and Planning (DELWP), Victorian Government; Port of '
                       'Melbourne; Deakin University; Royal Australian Navy (RAN); '
                       'and Commonwealth of Australia (Geoscience Australia)."')
nc.disclaimer = ('This data is not suitable for navigational purposes.')
nc.credit = ('Department of Environment, Land, Water and Planning (DELWP), Victorian Government; '
             'Port of Melbourne; Deakin University; Royal Australian Navy (RAN); '
             'Commonwealth of Australia (Geoscience Australia)')
nc.license = 'https://creativecommons.org/licenses/by-nc/4.0/'
nc.cdm_data_type = 'Grid'

nc.close() # close NetCDF dataset
        
band = None
ds = None # close tif dataset