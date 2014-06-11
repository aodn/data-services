function DATA=getVarNC(varName,allVarnames,nc)
idxVar = strcmpi(allVarnames,varName)==1;
strVarName = allVarnames{idxVar};
fillValue = netcdf.getAtt(nc,netcdf.inqVarID(nc,strVarName),'_FillValue');
DATA = netcdf.getVar(nc,netcdf.inqVarID(nc,strVarName));
DATA(DATA == fillValue) = NaN;
end
