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
# Base code by Pete Jansen 2019-10-02
# Modified by Eduardo Klein 2019-05-01

# For ONE variable only and only a file list in a file

# similar more general tool project https://ncagg.readthedocs.io/en/latest/ (does not work on python3 2019-10-01)
# has configurable way of dealing with attributes


webRoot = 'http://thredds.aodn.org.au/thredds/dodsC/'

# dictionary of variables names
varNamesDict = {'TEMP':                 'has_water_temperature',
                'PSAL':                 'has_salinity',
                 'VCUR':                'has_water_velocity',
                 'UCUR':                'has_water_velocity',
                 'WCUR':                'has_water_velocity',
                 'PRES':                'has_water_pressure',
                 'PRES_REL':            'has_water_pressure',
                 'Press_ATM':           'has_water_pressure',
                 'OXYGEN_UMOL_PER_L':   'has_oxygen',
                 'CHLU':                'has_chlorophyll',
                 'CHLF':                'has_chlorophyll',
                 'CPHL':                'has_chlorophyll'}


parser = argparse.ArgumentParser(description="Concatenate ONE variable from ALL instruments from ALL deployments from ONE site")
parser.add_argument('-var', dest='var', help='name of the variable to concatenate. Accepted var names: TEMP, PSAL', default='TEMP', required=False)
parser.add_argument('-site', dest='site', help='site code, like NRMMAI', default='NRSROT', required=False)
parser.add_argument('-ts', dest='timeStart', help='Start time like 2015-12-01', default='1944-10-15')
parser.add_argument('-te', dest='timeEnd', help='End time like 2018-06-30', default=str(datetime.now())[:10])
parser.add_argument('--demo', help='DEMO mode: TEMP at 27m, 43m, three deployments at NRSROT', action='store_true')
args = parser.parse_args()

varToAgg = [args.var]

if args.demo or len(sys.argv) ==0:
    print ("Running in DEMO mode: TEMP at 27m, 43m, three deployments at NRSROT")
    varToAgg = ['TEMP']
    files = ['http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20171124T080000Z_NRSROT_FV01_NRSROT-1712-SBE39-27_END-20180409T062000Z_C-20180503T020213Z.nc',
             'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20171124T080000Z_NRSROT_FV01_NRSROT-1712-SBE39-43_END-20180409T060000Z_C-20180503T020214Z.nc',
             'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20180406T080000Z_NRSROT_FV01_NRSROT-1804-SBE39-27_END-20180817T023000Z_C-20180820T010304Z.nc',
             'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20180406T080000Z_NRSROT_FV01_NRSROT-1804-SBE39-43_END-20180817T025000Z_C-20180820T010304Z.nc',
             'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20180816T080000Z_NRSROT_FV01_NRSROT-1808-SBE39-27_END-20181214T034000Z_C-20190402T065832Z.nc',
             'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20180816T080000Z_NRSROT_FV01_NRSROT-1808-SBE39-43_END-20181214T030000Z_C-20190402T065833Z.nc']
else:
    print('Concatenating %s from %s since %s thru %s' % (args.var, args.site, args.timeStart, args.timeEnd))

    # get the file names and attr from the geoserver
    # Only FV01 files
    print('Getting the file names...')
    url = "http://geoserver-123.aodn.org.au/geoserver/ows?typeName=moorings_all_map&SERVICE=WFS&REQUEST=GetFeature&VERSION=1.0.0&outputFormat=csv&CQL_FILTER=(file_version='1'%20AND%20realtime=FALSE%20AND%20(feature_type='timeSeries'%20OR%20feature_type='timeSeries'))"
    geoFiles = pd.read_csv(url)

    # set the filtering criteria
    criteriaSite = geoFiles['site_code'] == args.site
    criteriaVariable = geoFiles[varNamesDict[args.var]]
    criteriaDateStart = pd.to_datetime(geoFiles.time_coverage_start) >= datetime.strptime(args.timeStart, '%Y-%m-%d')
    criteriaDateEnd = pd.to_datetime(geoFiles.time_coverage_end) <= datetime.strptime(args.timeEnd, '%Y-%m-%d')

    criteria_all = criteriaSite & criteriaVariable & criteriaDateStart & criteriaDateEnd

    files = list(webRoot + geoFiles.url[criteria_all])
    print('%i files found.' % len(files))



print("Concatenating %s from %s files..." % (varToAgg[0], len(files)) )



nc = Dataset(files[0])
varList = nc.variables

# default to all variables in first file should no variable be specified
if varToAgg is None:
    ## EK. Convert the keys to a list so python2.7 could handle it
    varToAgg = list(varList.keys())
    varToAgg.remove("TIME")

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
for path_file in files:

    print("reading file %s" % path_file)

    nc = Dataset(path_file, mode="r")

    ## check if variable in file. If not, skip & remove the file from files list
    if varToAgg[0] in nc.variables:

        ncTime = nc.get_variables_by_attributes(standard_name='time')

        time_deployment_start = nc.time_deployment_start
        time_deployment_end = nc.time_deployment_end

        tStart = parse(time_deployment_start)
        tEnd = parse(time_deployment_end)

        tStartnum = date2num(tStart.replace(tzinfo=None), units=ncTime[0].units)
        tEndnum = date2num(tEnd.replace(tzinfo=None), units=ncTime[0].units)

        maTime = ma.array(ncTime[0][:])
        msk = (maTime < tStartnum) | (maTime > tEndnum)
        maTime.mask = msk

        timeLen = 1
        if len(ncTime[0].shape) > 0:
            timeLen = ncTime[0].shape[0]

        if filen == 0:
            maTimeAll = maTime
            instrumentIndex = ma.ones(timeLen) * filen
        else:
            maTimeAll = ma.append(maTimeAll, maTime)
            instrumentIndex = ma.append(instrumentIndex, ma.ones(timeLen) * filen)

    else:
        files.remove(path_file)
        print('%s not found in %s' % (varToAgg[0], path_file))


    nc.close()
    filen += 1

instrumentIndex.mask = maTimeAll.mask  # same mask for instrument index

idx = maTimeAll.argsort(0)  # sort by time dimension

#
# createTimeArray (1D, OBS) - from list of structures
#

dsTime = Dataset(files[0], mode="r")

ncTime = dsTime.get_variables_by_attributes(standard_name='time')

dates = num2date(maTimeAll[idx].compressed(), units=ncTime[0].units, calendar=ncTime[0].calendar)

#
# createNewFile
#

# create a new filename
# IMOS_<Facility-Code>_<Data-Code>_<Start-date>_<Platform-Code>_FV<File-Version>_ <Product-Type>_END-<End-date>_C-<Creation_date>_<PARTX>.nc

# TODO: what to do with <Data-Code> with a reduced number of variables

splitPath = files[0].split("/")
splitParts = splitPath[-1].split("_") # get the last path item (the file nanme), split by _

tStartMaksed = num2date(maTimeAll[idx].compressed()[0], units=ncTime[0].units, calendar=ncTime[0].calendar)
tEndMaksed = num2date(maTimeAll[idx].compressed()[-1], units=ncTime[0].units, calendar=ncTime[0].calendar)

fileProductTypeSplit = splitParts[6].split("-")
fileProductType = fileProductTypeSplit[0]

# could use the global attribute site_code for the product type

fileTimeFormat = "%Y%m%d"
ncTimeFormat = "%Y-%m-%dT%H:%M:%SZ"

outputName = splitParts[0] + "_" + splitParts[1] + "_" + splitParts[2] \
             + "_" + tStartMaksed.strftime(fileTimeFormat) \
             + "_" + splitParts[4] \
             + "_" + "FV02" \
             + "_" + fileProductType + "-Aggregate-" + varToAgg[0] \
             + "_END-" + tEndMaksed.strftime(fileTimeFormat) \
             + "_C-" + datetime.utcnow().strftime(fileTimeFormat) \
             + ".nc"

print("output file : %s" % outputName)

ncOut = Dataset(outputName, 'w', format='NETCDF4')

#
# create additional dimensions needed
#

# for d in nc.dimensions:
#     print("Dimension %s " % d)
#     ncOut.createDimension(nc.dimensions[d].name, size=nc.dimensions[d].size)
#

tDim = ncOut.createDimension("OBS", len(maTimeAll.compressed()))
iDim = ncOut.createDimension("instrument", len(files))
strDim = ncOut.createDimension("strlen", 256) # netcdf4 allow variable length strings, should we use them, probably not

#
# copyAttributes
#

# some of these need re-creating from the combined source data
globalAttributeBlackList = ['time_coverage_end', 'time_coverage_start',
                            'time_deployment_end', 'time_deployment_start',
                            'compliance_checks_passed', 'compliance_checker_version', 'compliance_checker_imos_version',
                            'date_created',
                            'deployment_code',
                            'geospatial_lat_max',
                            'geospatial_lat_min',
                            'geospatial_lon_max',
                            'geospatial_lon_min',
                            'geospatial_vertical_max',
                            'geospatial_vertical_min',
                            'instrument',
                            'instrument_nominal_depth',
                            'instrument_sample_interval',
                            'instrument_serial_number',
                            'quality_control_log',
                            'history', 'netcdf_version']


# global attributes
# TODO: get list of variables, global attributes and dimensions from first pass above
dsIn = Dataset(files[0], mode='r')
for a in dsIn.ncattrs():
    if not (a in globalAttributeBlackList):
        print("Attribute %s value %s" % (a, dsIn.getncattr(a)))
        ncOut.setncattr(a, dsIn.getncattr(a))

for d in dsIn.dimensions:
    if not(d in 'TIME'):
        ncOut.createDimension(d, dsIn.dimensions[d].size)

dsIn.close()

ncOut.setncattr("data_mode", "A")  # something to indicate its an aggregate

# TIME variable
# TODO: get TIME attributes from first pass above
ncTimesOut = ncOut.createVariable("TIME", ncTime[0].dtype, ("OBS",))

#  copy TIME variable attributes
for a in ncTime[0].ncattrs():
    if a not in ('comment',):
        print("TIME Attribute %s value %s" % (a, ncTime[0].getncattr(a)))
        ncTimesOut.setncattr(a, ncTime[0].getncattr(a))

ncTimesOut[:] = maTimeAll[idx].compressed()

ncOut.setncattr("time_coverage_start", dates[0].strftime(ncTimeFormat))
ncOut.setncattr("time_coverage_end", dates[-1].strftime(ncTimeFormat))
ncOut.setncattr("date_created", datetime.utcnow().strftime(ncTimeFormat))
ncOut.setncattr("history", datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC : Create Aggregate"))

# instrument index
indexVarType = "i1"
if len(files) > 128:
    indexVarType = "i2"
    if len(files) > 32767: # your really keen then
        indexVarType = "i4"

#
# create new variables needed
#

ncInstrumentIndexVar = ncOut.createVariable("instrument_index", indexVarType, ("OBS",))
ncInstrumentIndexVar.setncattr("long_name", "which instrument this obs is for")
ncInstrumentIndexVar.setncattr("instance_dimension", "instrument")
ncInstrumentIndexVar[:] = instrumentIndex[idx].compressed()

# create a variable with the source file name
ncFileNameVar = ncOut.createVariable("source_file", "S1", ("instrument", "strlen"))
ncFileNameVar.setncattr("long_name", "source file for this instrument")

ncInstrumentTypeVar = ncOut.createVariable("instrument_type", "S1", ("instrument", "strlen"))
ncInstrumentTypeVar.setncattr("long_name", "source instrument make, model, serial_number")

filen = 0
data = numpy.empty(len(files), dtype="S256")
instrument = numpy.empty(len(files), dtype="S256")
for path_file in files:
    data[filen] = path_file
    ncType = Dataset(path_file, mode='r')
    instrument[filen] = ncType.instrument + '-' + ncType.instrument_serial_number
    filen += 1

ncFileNameVar[:] = stringtochar(data)
ncInstrumentTypeVar[:] = stringtochar(instrument)

#
# create a list of variables needed
#

filen = 0

# include the DEPTH variable
varNames = varToAgg + ['DEPTH']

# add the ancillary variables for the ones requested
for v in varNames:
    if hasattr(varList[v], 'ancillary_variables'):
        varNames += [varList[v].ancillary_variables]

# variables we want regardless
varNames += ['LATITUDE', 'LONGITUDE', 'NOMINAL_DEPTH']

varNamesOut = set(varNames)

#
# copyData
#

# copy variable data from all files into output file

# should we add uncertainty to variables here if they don't have one from a default set

for v in varNamesOut:
    varOrder = -1
    filen = 0

    if (v != 'TIME') & (v in varList):

        for path_file in files:
            print("%d : %s file %s" % (filen, v, path_file))

            nc1 = Dataset(path_file, mode="r")


            nRecords = len(nc1.dimensions['TIME'])

            ## EK. check if the variable is present
            ## EK. if not, create an empty masked array of dimension TIME with the corresponding dtype
            if v in list(nc1.variables.keys()):
                maVariable = nc1.variables[v][:]
                maVariable = ma.squeeze(maVariable)
            else:
                maVariable = ma.array(numpy.repeat(999999, nRecords),
                             mask = numpy.repeat(True, nRecords),
                             dtype = varList[v].dtype)


            print(maVariable.shape)

            varDims = varList[v].dimensions
            varOrder = len(varDims)

            if len(varDims) > 0:
                # need to replace the TIME dimension with the now extended OBS dimension
                # should we extend this to the CTD case where the variables have a DEPTH dimension and no TIME
                if varList[v].dimensions[0] == 'TIME':
                    if filen == 0:
                        maVariableAll = maVariable

                        dim = ('OBS',) + varDims[1:len(varDims)]
                        ncVariableOut = ncOut.createVariable(v, varList[v].dtype, dim)
                    else:
                        maVariableAll = ma.append(maVariableAll, maVariable, axis=0) # add new data to end along OBS axis
                else:
                    if filen == 0:
                        maVariableAll = maVariable
                        maVariableAll.shape = (1,) + maVariable.shape

                        dim = ('instrument',) + varDims[0:len(varDims)]
                        varOrder += 1
                        ncVariableOut = ncOut.createVariable(v, varList[v].dtype, dim)
                    else:
                        vdata = maVariable
                        vdata.shape = (1,) + maVariable.shape
                        maVariableAll = ma.append(maVariableAll, vdata, axis=0)

            else:
                if filen == 0:
                    maVariableAll = maVariable

                    dim = ('instrument',) + varDims[0:len(varDims)]
                    ncVariableOut = ncOut.createVariable(v, varList[v].dtype, dim)
                else:
                    maVariableAll = ma.append(maVariableAll, maVariable)

            # copy the variable attributes
            # this is ends up as the super set of all files
            for a in varList[v].ncattrs():
                if a not in ('comment',):
                    print("%s Attribute %s value %s" % (v, a, varList[v].getncattr(a)))
                    ncVariableOut.setncattr(a, varList[v].getncattr(a))

            filen += 1



        # write the aggregated data to the output file
        if varOrder == 2:
            maVariableAll.mask = maTimeAll.mask  # apply the time mask
            ncVariableOut[:] = maVariableAll[idx][:].compressed()
        elif varOrder == 1:
            maVariableAll.mask = maTimeAll.mask  # apply the time mask
            ncVariableOut[:] = maVariableAll[idx].compressed()
        elif varOrder == 0:
            ncVariableOut[:] = maVariableAll

            # create the output global attributes
            if hasattr(ncVariableOut, 'standard_name'):
                if ncVariableOut.standard_name == 'latitude':
                    laMax = maVariableAll.max(0)
                    laMin = maVariableAll.max(0)
                    ncOut.setncattr("geospatial_lat_max", laMax)
                    ncOut.setncattr("geospatial_lat_min", laMin)
                if ncVariableOut.standard_name == 'longitude':
                    loMax = maVariableAll.max(0)
                    loMin = maVariableAll.max(0)
                    ncOut.setncattr("geospatial_lon_max", loMax)
                    ncOut.setncattr("geospatial_lon_min", loMin)
                if ncVariableOut.standard_name == 'depth':
                    dMax = maVariableAll.max(0)
                    dMin = maVariableAll.max(0)
                    ncOut.setncattr("geospatial_vertical_max", dMax)
                    ncOut.setncattr("geospatial_vertical_min", dMin)

nc.close()

ncOut.close()

print ("Output file :  %s" % outputName);
