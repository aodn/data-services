function [ivar] = get_var1D(filename,varname)
%THIS FUNCTION SIMPLY EXTRACT A VARIABLE FROM A NETCDF FILE and returns a 1D vector
%INPUT : - filename : NetCDF file name
%		 - varname : Variable Name 
% OUTPUT: var 
nc   = netcdf.open(filename,'NC_NOWRITE');
varid = netcdf.inqVarID(nc,varname);
ivar = netcdf.getVar(nc,varid);
ivar = ivar(:);
  
netcdf.close(nc);