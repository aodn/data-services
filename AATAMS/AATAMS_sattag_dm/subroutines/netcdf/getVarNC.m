function DATA=getVarNC(varName,allVarnames,nc)
idxVar     = strcmpi(allVarnames,varName)==1;
strVarName = allVarnames{idxVar};
DATA       = netcdf.getVar(nc,netcdf.inqVarID(nc,strVarName));
end
