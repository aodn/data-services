#!/usr/bin/env python
"""
Some XBT files contain _Fillevalues at the end of the DEPTH dimension. This function returns
the value of the dimension where this happens. If not, the original lenght of the DEPTH dim is
returned
"""

import sys

from netCDF4 import Dataset

if __name__ == '__main__':
    # read filename from command line
    if len(sys.argv) < 2:
        print >>sys.stderr, 'No filename specified!'
        exit(1)

    netcdf_file_path = sys.argv[1]

    if not netcdf_file_path:
        exit(1)

    netcdf_file_obj = Dataset(netcdf_file_path, 'r', format='NETCDF4')
    depth           = netcdf_file_obj.variables['DEPTH']

    # handle case when no fillvalues
    try:
        indexes_to_keep = depth[:].mask == False
    except:
        print depth.size
        netcdf_file_obj.close()
        exit(0)

    netcdf_file_obj.close()
    # if fillValue at beginning of var, or in the middle of good values. This is not the correct fix
    # in this case we return the original size of the DEPTH dimension not to change anything
    if (indexes_to_keep[:] == False).sum() == 0 : # means no Fillvalue at all in DEPTH, so we return the original dim length
        print len(indexes_to_keep[:])
    else :
        # look for the first occurence of Fillvalue in DEPTH dimension
        last_good_index = (i for i,v in enumerate(indexes_to_keep) if v == False).next() # enumerates retrieves position index and corresponding value

        if (indexes_to_keep[last_good_index:-1] == True).sum() == 0:
            # if we find only FillValue afterwards, we return the last_good_index value, which will force the netcdf file to be modified
            print last_good_index

        else:
            # in case there is a mix a fillValue and good values in the Dimension. There is still an issue, but we
            # return the original length of the DEPTH dimension not to change anything. The file won't pass the cf checker
            print depth.size
