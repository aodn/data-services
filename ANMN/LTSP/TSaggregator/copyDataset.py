from __future__ import print_function
from datetime import datetime, timedelta
from netCDF4 import num2date, date2num
from netCDF4 import stringtochar
import numpy.ma as ma
import sys
import netCDF4 as nc
from netCDF4 import Dataset
import numpy
import argparse
import glob
from dateutil.parser import parse
import pandas as pd




# netcdf file aggregator for the IMOS mooring specific data case


# For ONE variable only and only a file list in a file

# similar more general tool project https://ncagg.readthedocs.io/en/latest/ (does not work on python3 2019-10-01)
# has configurable way of dealing with attributes


web_root = 'http://thredds.aodn.org.au/thredds/dodsC/'

# dictionary of variables names
var_names_dict = {'TEMP':               'has_water_temperature',
                'PSAL':                 'has_salinity',
                 'VCUR':                'has_sea_water_velocity',
                 'UCUR':                'has_sea_water_velocity',
                 'WCUR':                'has_sea_water_velocity',
                 'PRES':                'has_water_pressure',
                 'PRES_REL':            'has_water_pressure',
                 'OXYGEN_UMOL_PER_L':   'has_oxygen',
                 'CHLU':                'has_chlorophyll',
                 'CHLF':                'has_chlorophyll',
                 'CPHL':                'has_chlorophyll'}


parser = argparse.ArgumentParser(description="Concatenate ONE variable from ALL instruments from ALL deployments from ONE site")
parser.add_argument('-var', dest='var', help='name of the variable to concatenate. Accepted var names: TEMP, PSAL', required=False)
parser.add_argument('-site', dest='site', help='site code, like NRMMAI',  required=False)
parser.add_argument('-ts', dest='timeStart', help='start time like 2015-12-01. Default 1944-10-15', default='1944-10-15')
parser.add_argument('-te', dest='timeEnd', help='End time like 2018-06-30. Default today\'s date', default=str(datetime.now())[:10])
parser.add_argument('-out', dest='outFileList', help='name of the file to store the selected files info. Default: fileList.csv', default="fileList.csv", required=False)
parser.add_argument('--demo', help='DEMO mode: TEMP at 27m, 43m, three deployments at NRSROT', action='store_true')
args = parser.parse_args()



if args.demo or len(sys.argv) ==0:
    print ("Running in DEMO mode: TEMP at 27m, 43m, three deployments at NRSROT")
    var_to_agg = ['TEMP']
    files = ['http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20171124T080000Z_NRSROT_FV01_NRSROT-1712-SBE39-27_END-20180409T062000Z_C-20180503T020213Z.nc',
             'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20171124T080000Z_NRSROT_FV01_NRSROT-1712-SBE39-43_END-20180409T060000Z_C-20180503T020214Z.nc',
             'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20180406T080000Z_NRSROT_FV01_NRSROT-1804-SBE39-27_END-20180817T023000Z_C-20180820T010304Z.nc',
             'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20180406T080000Z_NRSROT_FV01_NRSROT-1804-SBE39-43_END-20180817T025000Z_C-20180820T010304Z.nc',
             'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20180816T080000Z_NRSROT_FV01_NRSROT-1808-SBE39-27_END-20181214T034000Z_C-20190402T065832Z.nc',
             'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20180816T080000Z_NRSROT_FV01_NRSROT-1808-SBE39-43_END-20181214T030000Z_C-20190402T065833Z.nc']
else:

    # print(type(args.site))
    # sys.exit()

    if args.var not in var_names_dict.keys() or isinstance(args.var, type(None)):
        sys.exit('ERROR: invalid variable name.')

    if isinstance(args.site, type(None)):
        sys.exit('ERROR: missing site.')

    print('Concatenating %s from %s since %s thru %s' % (args.var, args.site, args.timeStart, args.timeEnd))
    var_to_agg = [args.var]

    # get the file names and attr from the geoserver
    # Only FV01 files
    print('Getting the file names...')
    url = "http://geoserver-123.aodn.org.au/geoserver/ows?typeName=moorings_all_map&SERVICE=WFS&REQUEST=GetFeature&VERSION=1.0.0&outputFormat=csv&CQL_FILTER=(file_version='1'%20AND%20realtime=FALSE%20AND%20strToLowerCase(feature_type)='timeseries')"

    geoserver_files = pd.read_csv(url)

    # set the filtering criteria
    criteria_noADCP = geoserver_files['data_category'] != "Velocity"

    criteria_site = geoserver_files['site_code'] == args.site
    if criteria_site.sum() == 0:
        sys.exit('ERROR: invalid site.')

    criteria_variable = geoserver_files[var_names_dict[args.var]]
    if criteria_variable.sum() == 0:
        sys.exit('ERROR: invalid variable.')

    try:
        date_start = datetime.strptime(args.timeStart, '%Y-%m-%d')
        date_end = datetime.strptime(args.timeEnd, '%Y-%m-%d')
    except ValueError:
        sys.exit('ERROR: invalid start or end date.')
    criteria_startdate = pd.to_datetime(geoserver_files.time_coverage_start) <= date_end
    criteria_enddate = pd.to_datetime(geoserver_files.time_coverage_end) >= date_start

    criteria_all = criteria_noADCP & criteria_site & criteria_variable & criteria_startdate & criteria_enddate


    files = list(web_root + geoserver_files.url[criteria_all])


    if len(files)>1:
        print('%i files found.' % len(files))
        # write file names used in a text file
        geoserver_files[criteria_all].to_csv(args.outFileList, index=False)

    else:
        sys.exit('ERROR: NONE or only ONE file found')



print("Concatenating %s from %s files..." % (var_to_agg[0], len(files)) )



nc = Dataset(files[0])
var_list = nc.variables

# default to all variables in first file should no variable be specified
if var_to_agg is None:
    ## EK. Convert the keys to a list so python2.7 could handle it
    var_to_agg = list(var_list.keys())
    var_to_agg.remove("TIME")

## get and modify global attributes
global_attribute_blacklist =    ['abstract',
                                 'author',
                                 'author_email',
                                 'compliance_checks_passed',
                                 'compliance_checker_version',
                                 'compliance_checker_imos_version',
                                 'date_created',
                                 'deployment_code',
                                 'geospatial_lat_max',
                                 'geospatial_lat_min',
                                 'geospatial_lon_max',
                                 'geospatial_lon_min',
                                 'geospatial_vertical_max',
                                 'geospatial_vertical_min',
                                 'history',
                                 'instrument',
                                 'instrument_nominal_depth',
                                 'instrument_sample_interval',
                                 'instrument_serial_number',
                                 'quality_control_log',
                                 'site_nominal_depth',
                                 'time_coverage_end',
                                 'time_coverage_start',
                                 'time_deployment_end',
                                 'time_deployment_end_origin',
                                 'time_deployment_start',
                                 'time_deployment_start_origin',
                                 'toolbox_input_file',
                                 'toolbox_version']
gattr = nc.__dict__
gattr_tmp = {}
for i in gattr:
    if not (i in global_attribute_blacklist):
        gattr_tmp.update({i: gattr[i]})

gattr_tmp.update({'abstract': 'LTSP one variable from all deployments at a single site'})
gattr_tmp.update({'author': 'Klein, Eduardo'})
gattr_tmp.update({'author_email': 'eduardo.kleinsalas@utas.edu.au'})
gattr_tmp.update({'cdm_data_type': 'Station'})
gattr_tmp.update({'feature_type': 'timeSeries'})
gattr_tmp.update({'title': 'LTSP one variable one site all deployments'})


nc.close()

# split this into   createCatalog - copy needed information into structure
#                   createTimeArray (1D, OBS) - from list of structures
#                   createNewFile
#                   copyAttributes
#                   updateAttributes
#                   copyData

#
# createCatalog - copy needed information into structure
#

# look over all files, create a time array from all files
# TODO: maybe delete files here without variables we're not interested in
# TODO: Create set of variables in all files

filen = 0
print('Reading files: ', end="")

for path_file in files:

    #print("reading file %s" % path_file)
    print('%d ' % (filen+1), end="")

    nc = Dataset(path_file, mode="r")

    ## check if variable in file. If not, skip & remove the file from files list
    if var_to_agg[0] in nc.variables:

        nc_time = nc.get_variables_by_attributes(standard_name='time')

        time_deployment_start = nc.time_deployment_start
        time_deployment_end = nc.time_deployment_end

        t_start = parse(time_deployment_start)
        t_end = parse(time_deployment_end)

        t_startnum = date2num(t_start.replace(tzinfo=None), units=nc_time[0].units)
        t_endnum = date2num(t_end.replace(tzinfo=None), units=nc_time[0].units)

        ma_time = ma.array(nc_time[0][:])
        msk = (ma_time < t_startnum) | (ma_time > t_endnum)
        ma_time.mask = msk

        time_len = 1
        if len(nc_time[0].shape) > 0:
            time_len = nc_time[0].shape[0]

        if filen == 0:
            ma_time_all = ma_time
            instrumentIndex = ma.ones(time_len) * filen
        else:
            ma_time_all = ma.append(ma_time_all, ma_time)
            instrumentIndex = ma.append(instrumentIndex, ma.ones(time_len) * filen)

    else:
        files.remove(path_file)
        print('%s not found in %s' % (var_to_agg[0], path_file))


    nc.close()
    filen += 1

print()

instrumentIndex.mask = ma_time_all.mask  # same mask for instrument index

idx = ma_time_all.argsort(0)  # sort by time dimension

#
# createTimeArray (1D, OBS) - from list of structures
#
print('Creating the variables in the output file...')

ds_time = Dataset(files[0], mode="r")

nc_time = ds_time.get_variables_by_attributes(standard_name='time')

dates = num2date(ma_time_all[idx].compressed(), units=nc_time[0].units, calendar=nc_time[0].calendar)


#
# createNewFile
#

# create a new filename
# IMOS_<Facility-Code>_<Data-Code>_<Start-date>_<Platform-Code>_FV<File-Version>_ <Product-Type>_END-<End-date>_C-<Creation_date>_<PARTX>.nc

# TODO: what to do with <Data-Code> with a reduced number of variables

split_path = files[0].split("/")
split_parts = split_path[-1].split("_") # get the last path item (the file nanme), split by _

t_start_masked = num2date(ma_time_all[idx].compressed()[0], units=nc_time[0].units, calendar=nc_time[0].calendar)
t_end_masked = num2date(ma_time_all[idx].compressed()[-1], units=nc_time[0].units, calendar=nc_time[0].calendar)

file_product_type_split = split_parts[6].split("-")
file_product_type = file_product_type_split[0]

# could use the global attribute site_code for the product type

file_timeformat = "%Y%m%d"
nc_timeformat = "%Y-%m-%dT%H:%M:%SZ"

output_name = split_parts[0] + "_" + split_parts[1] + "_" + split_parts[2] \
             + "_" + t_start_masked.strftime(file_timeformat) \
             + "_" + split_parts[4] \
             + "_" + "FV02" \
             + "_" + file_product_type + "-Aggregate-" + var_to_agg[0] \
             + "_END-" + t_end_masked.strftime(file_timeformat) \
             + "_C-" + datetime.utcnow().strftime(file_timeformat) \
             + ".nc"

#print("OUTPUT file : %s" % output_name)

nc_out = Dataset(output_name, 'w', format='NETCDF4')

#
# create additional dimensions needed
#

# for d in nc.dimensions:
#     print("Dimension %s " % d)
#     nc_out.createDimension(nc.dimensions[d].name, size=nc.dimensions[d].size)
#

t_dim = nc_out.createDimension("OBS", len(ma_time_all.compressed()))
i_dim = nc_out.createDimension("instrument", len(files))
str_dim = nc_out.createDimension("strlen", 256) # netcdf4 allow variable length strings, should we use them, probably not

with Dataset(path_file, mode="r") as ds_in:
    for d in ds_in.dimensions:
        if not(d in 'TIME'):
            nc_out.createDimension(d, ds_in.dimensions[d].size)


# TIME variable
# TODO: get TIME attributes from first pass above
nc_times_out = nc_out.createVariable("TIME", nc_time[0].dtype, ("OBS",))

#  copy TIME variable attributes
for a in nc_time[0].ncattrs():
    if a not in ('comment',):
        #print("TIME Attribute %s value %s" % (a, nc_time[0].getncattr(a)))
        nc_times_out.setncattr(a, nc_time[0].getncattr(a))

nc_times_out[:] = ma_time_all[idx].compressed()

gattr_tmp.update({"time_coverage_start": dates[0].strftime(nc_timeformat)})
gattr_tmp.update({"time_coverage_end": dates[-1].strftime(nc_timeformat)})
gattr_tmp.update({"date_created": datetime.utcnow().strftime(nc_timeformat)})
gattr_tmp.update({"history": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC : Create Aggregate")})


# instrument index
index_var_type = "i1"
if len(files) > 128:
    index_var_type = "i2"
    if len(files) > 32767: # your really keen then
        index_var_type = "i4"


#
# create new variables needed
#

nc_instrument_index_var = nc_out.createVariable("instrument_index", index_var_type, ("OBS",))
nc_instrument_index_var.setncattr("long_name", "which instrument this obs is for")
nc_instrument_index_var.setncattr("instance_dimension", "instrument")
nc_instrument_index_var[:] = instrumentIndex[idx].compressed()

# create a variable with the source file name
nc_file_name_var = nc_out.createVariable("source_file", "S1", ("instrument", "strlen"))
nc_file_name_var.setncattr("long_name", "source file for this instrument")

nc_instrument_type_var = nc_out.createVariable("instrument_type", "S1", ("instrument", "strlen"))
nc_instrument_type_var.setncattr("long_name", "source instrument make, model, serial_number")

filen = 0
data = numpy.empty(len(files), dtype="S256")
instrument = numpy.empty(len(files), dtype="S256")
for path_file in files:
    data[filen] = path_file
    with Dataset(path_file, mode="r") as nc_type:
        instrument[filen] = nc_type.instrument + '-' + nc_type.instrument_serial_number

    filen += 1

nc_file_name_var[:] = stringtochar(data)
nc_instrument_type_var[:] = stringtochar(instrument)

#
# create a list of variables needed
#

filen = 0

# include the DEPTH variable
var_names_all = var_to_agg + ['DEPTH']

# add the ancillary variables for the ones requested
for v in var_names_all:
    if hasattr(var_list[v], 'ancillary_variables'):
        var_names_all += [var_list[v].ancillary_variables]

# variables we want regardless
var_names_all += ['LATITUDE', 'LONGITUDE', 'NOMINAL_DEPTH']

var_names_out = sorted(set(var_names_all))

#
# copyData
#

# copy variable data from all files into output file

# should we add uncertainty to variables here if they don't have one from a default set
variable_attribute_blacklist = ['comment',
                                '_ChunkSizes']

for v in var_names_out:
    var_order = -1
    filen = 0

    if (v != 'TIME') & (v in var_list):
        print('Processing %s in file ' %v, end="")

        for path_file in files:
            #print("%d : %s file %s" % (filen, v, path_file))
            print("%s " % (filen+1), end="")
            with Dataset(path_file, mode="r") as nc1:

                n_records = len(nc1.dimensions['TIME'])

                ## EK. check if the variable is present
                ## EK. if not, create an empty masked array of dimension TIME with the corresponding dtype
                if v in list(nc1.variables.keys()):
                    ma_variable = nc1.variables[v][:]
                    ma_variable = ma.squeeze(ma_variable)
                else:
                    ma_variable = ma.array(numpy.repeat(999999, n_records),
                                 mask = numpy.repeat(True, n_records),
                                 dtype = var_list[v].dtype)

                varDims = var_list[v].dimensions
                var_order = len(varDims)

                if len(varDims) > 0:
                    # need to replace the TIME dimension with the now extended OBS dimension
                    # should we extend this to the CTD case where the variables have a DEPTH dimension and no TIME
                    if var_list[v].dimensions[0] == 'TIME':
                        if filen == 0:
                            ma_variable_all = ma_variable

                            dim = ('OBS',) + varDims[1:len(varDims)]
                            nc_variable_out = nc_out.createVariable(v, var_list[v].dtype, dim)
                        else:
                            ma_variable_all = ma.append(ma_variable_all, ma_variable, axis=0) # add new data to end along OBS axis
                    else:
                        if filen == 0:
                            ma_variable_all = ma_variable
                            ma_variable_all.shape = (1,) + ma_variable.shape

                            dim = ('instrument',) + varDims[0:len(varDims)]
                            var_order += 1
                            nc_variable_out = nc_out.createVariable(v, var_list[v].dtype, dim)
                        else:
                            vdata = ma_variable
                            vdata.shape = (1,) + ma_variable.shape
                            ma_variable_all = ma.append(ma_variable_all, vdata, axis=0)

                else:
                    if filen == 0:
                        ma_variable_all = ma_variable

                        dim = ('instrument',) + varDims[0:len(varDims)]
                        nc_variable_out = nc_out.createVariable(v, var_list[v].dtype, dim)
                    else:
                        ma_variable_all = ma.append(ma_variable_all, ma_variable)

                # copy the variable attributes
                # this is ends up as the super set of all files
                for a in var_list[v].ncattrs():
                    if a not in variable_attribute_blacklist:
                        #print("%s Attribute %s value %s" % (v, a, var_list[v].getncattr(a)))
                        nc_variable_out.setncattr(a, var_list[v].getncattr(a))

            filen += 1

        print()



        # write the aggregated data to the output file
        if var_order == 2:
            ma_variable_all.mask = ma_time_all.mask  # apply the time mask
            nc_variable_out[:] = ma_variable_all[idx][:].compressed()
        elif var_order == 1:
            ma_variable_all.mask = ma_time_all.mask  # apply the time mask
            nc_variable_out[:] = ma_variable_all[idx].compressed()
        elif var_order == 0:
            nc_variable_out[:] = ma_variable_all

            # update the output global attributes
            if hasattr(nc_variable_out, 'standard_name'):
                if nc_variable_out.standard_name == 'latitude':
                    la_max = ma_variable_all.max()
                    la_min = ma_variable_all.min()
                    gattr_tmp.update({"geospatial_lat_max": la_max, "geospatial_lat_min": la_min})
                if nc_variable_out.standard_name == 'longitude':
                    lo_max = ma_variable_all.max()
                    lo_min = ma_variable_all.min()
                    gattr_tmp.update({"geospatial_lon_max": lo_max, "geospatial_lon_min": lo_min})
                if nc_variable_out.standard_name == 'depth':
                    d_max = ma_variable_all.max()
                    d_min = ma_variable_all.min()
                    gattr_tmp.update({"geospatial_vertical_max": d_max, "geospatial_vertical_min": d_min})

# sort new global attr dictionary
gattr_new={}
for key, value in sorted(gattr_tmp.items()):
    gattr_new.update({key: value})

nc_out.setncatts(gattr_new)


nc.close()
nc_out.close()


print ("Output file :  %s" % output_name);
