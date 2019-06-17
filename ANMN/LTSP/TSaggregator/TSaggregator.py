from __future__ import print_function
import sys
import json
from datetime import datetime, timedelta
from dateutil.parser import parse

from netCDF4 import Dataset, num2date, date2num, stringtochar
import numpy as np
import numpy.ma as ma
import pandas as pd
from geoserverCatalog import get_moorings_urls




def set_globalattr(agg_attr, templatefile):
    """
    global attributes from a reference nc file, dict of aggregator specific attrs,
    and dict of global attr template.
    """
    with open(templatefile) as json_file:
        global_metadata = json.load(json_file)
    global_metadata.update(agg_attr)

    return(dict(sorted(global_metadata.items())))



def agg_timeseries(files_to_agg, var_to_agg):
    """
    Main function
    """
    var_to_agg = [var_to_agg]

    ## first read: get the variable names
    with Dataset(files_to_agg[0], mode="r") as nc:
        var_list = nc.variables

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

    for path_file in files_to_agg:

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
            files_to_agg.remove(path_file)
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

    ds_time = Dataset(files_to_agg[0], mode="r")

    nc_time = ds_time.get_variables_by_attributes(standard_name='time')

    dates = num2date(ma_time_all[idx].compressed(), units=nc_time[0].units, calendar=nc_time[0].calendar)


    #
    # createNewFile
    #

    # create a new filename
    # IMOS_<Facility-Code>_<Data-Code>_<Start-date>_<Platform-Code>_FV<File-Version>_ <Product-Type>_END-<End-date>_C-<Creation_date>_<PARTX>.nc

    # TODO: what to do with <Data-Code> with a reduced number of variables

    split_path = files_to_agg[0].split("/")
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
                 + "_" + "FV01" \
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
    i_dim = nc_out.createDimension("instrument", len(files_to_agg))
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

    # instrument index
    index_var_type = "i1"
    if len(files_to_agg) > 128:
        index_var_type = "i2"
        if len(files_to_agg) > 32767: # your really keen then
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
    data = np.empty(len(files_to_agg), dtype="S256")
    instrument = np.empty(len(files_to_agg), dtype="S256")
    gattr_tmp = {"deployment_code": "",
                 "instrument": "",
                 "instrument_nominal_depth": "",
                 "instrument_sample_interval": "",
                 "instrument_serial_number": "",
                 "site_nominal_depth":"",
                 "toolbox_input_file": "",
                 "toolbox_version": ""}

    for path_file in files_to_agg:
        data[filen] = path_file
        with Dataset(path_file, mode="r") as nc_type:
            instrument[filen] = nc_type.instrument + '-' + nc_type.instrument_serial_number

            ## collect global_metadata
            for global_attribute in gattr_tmp.keys():
                try:
                    gattr_tmp[global_attribute] += (str(nc_type.getncattr(global_attribute)) + ",")
                except:
                    gattr_tmp[golbal_attribute] += "N/A,"

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
    variable_attribute_blacklist = ['comment', '_ChunkSizes']

    for v in var_names_out:
        var_order = -1
        filen = 0

        if (v != 'TIME') & (v in var_list):
            print('Processing %s in file ' %v, end="")

            for path_file in files_to_agg:
                #print("%d : %s file %s" % (filen, v, path_file))
                print("%s " % (filen+1), end="")
                with Dataset(path_file, mode="r") as nc1:
                    ## Check if the variable is present
                    try:
                        ma_variable = nc1.variables[v][:]
                    except:
                        raise ValueError('Missing variable %s in the input file %s' % (v, path_file))

                ma_variable = ma.squeeze(ma_variable)

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

    # set global attr
    gattr_tmp.update({"site_code": nc.getncattr('site_code')})
    gattr_tmp.update({"platform_code": nc.getncattr('platform_code')})
    gattr_tmp.update({"time_coverage_start": datetime.strftime(num2date(np.min(nc['TIME']), nc['TIME'].units), nc_timeformat)})
    gattr_tmp.update({"time_coverage_end": datetime.strftime(num2date(np.max(nc['TIME']), nc['TIME'].units), nc_timeformat)})
    gattr_tmp.update({"local_time_zone": nc.getncattr('local_time_zone')})
    gattr_tmp.update({"date_created": datetime.utcnow().strftime(nc_timeformat)})
    gattr_tmp.update({"history": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC : Create Aggregate")})
    gattr_tmp.update({'keywords': ', '.join(nc_out.variables.keys())})
    globalattr_file = 'TSagg_globalmetadata.json'
    nc_out.setncatts(set_globalattr(gattr_tmp, globalattr_file))

    nc.close()
    nc_out.close()

    print ("Output file :  %s" % output_name);

    return()


if __name__ == "__main__":
    varname = 'TEMP'
    site = 'NRSROT'
    realtime = 'no'
    fileversion = 1
    featuretype = 'timeseries'
    datacategory = 'Temperature'
    datestart = '2017-01-01'
    filterout = 'ADCP'

    files_to_aggregate = get_moorings_urls(varname=varname, site=site, featuretype=featuretype, fileversion=fileversion, realtime=realtime, datacategory=datacategory, filterout=filterout)

    ## to test
    # files_to_aggregate = ['http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20140808T080000Z_NRSROT_FV01_NRSROT-1408-SBE39-33_END-20141217T054500Z_C-20180508T013222Z.nc',
    #                       'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20141215T160000Z_NRSROT_FV01_NRSROT-1412-SBE39-33_END-20150331T063000Z_C-20180508T001839Z.nc',
    #                       'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20141216T080000Z_NRSROT_FV01_NRSROT-1412-SBE39-27_END-20150331T061500Z_C-20180508T001839Z.nc',
    #                       'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20141216T080000Z_NRSROT_FV01_NRSROT-1412-SBE39-43_END-20150331T063000Z_C-20180508T001839Z.nc',
    #                       'http://thredds.aodn.org.au/thredds/dodsC/IMOS/ANMN/NRS/NRSROT/Temperature/IMOS_ANMN-NRS_TZ_20141216T080000Z_NRSROT_FV01_NRSROT-1412-TDR-2050-57_END-20150331T065000Z_C-20180508T001840Z.nc']


    agg_timeseries(files_to_agg=files_to_aggregate, var_to_agg=varname)
