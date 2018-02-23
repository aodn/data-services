# anmn_temp_gridded_product.py

This piece of Python 2.7 code creates a gridded temperature products based on FV01 NetCDF files (quality controlled, single-instrument files) for a particular deployment_code:
1. It retrieves a list of FV01 NetCDF files for a particular deployment_code from the WFS service of view anmn_ts_timeseries_map.
2. Checks that each file has the required variables, otherwise take them out of the list.
3. Considers only data with flag 0, 1 or 2.
4. Bins the temperature data temporally for each dataset with a bin size of 60min. The centre of the bin falls on the hour xx:00.
5. Binned data is then linearly interpolated over the vertical axis for every time stamp at 1m resolution. Vertical interpolation occurs between two nearest available averaged data and when they are not available a fillvalue is given.

Takes in argument:
- a deployment_code, or the path to a local FV01 file from which the deployment_code global attribute is read.
- optionally, an output directory for the created FV02 temperature gridded product.

Returns:
- full path to newly created FV02 temperature gridded product.
- relative path on S3 to existing FV02 ANMN temperature gridded product.

# generate_nc_file_att

Text file that specifies the content of some NetCDF attributes for the created gridded product.

# plot_abs_comparison_old_new_product.py

This piece of Python 2.7 code creates a plot for comparison between existing FV02 temperature gridded product and a newly created one.

Takes in argument:
- the full path to newly created FV02 ANMN temperature gridded product.
- relative path on s3 to existing FV02 ANMN temperature gridded product.
