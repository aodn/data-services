function [attlist,attval,globatt] = get_VarInfo(filename,varname)
%THIS FUNCTION SIMPLY EXTRACT A VARIABLE FROM A NETCDF FILE and returns a 1D vector
%INPUT : - filename : NetCDF file name
%		 - varname : Variable Name 
% OUTPUT: var 
nc_id   = netcdf.open(filename,'NC_NOWRITE');
varid = netcdf.inqVarID(nc_id,varname);
% extract the variable attributes
[varname,xtype,dimids,natts] = netcdf.inqVar(nc_id,varid);

for i = 1:natts
  attname = netcdf.inqAttName(nc_id,varid,i-1);
  att_val = netcdf.getAtt(nc_id,varid,attname);
  attlist{i} = attname;
  attval{i} = att_val;
end

[globatt] =	get_globalAttributes('NC_id',nc_id,'all')	; 

netcdf.close(nc_id); 