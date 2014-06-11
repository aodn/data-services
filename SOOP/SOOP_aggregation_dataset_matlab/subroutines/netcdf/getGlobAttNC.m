function [gattname,gattval]=getGlobAttNC(nc)
[ ~, ~, natts ,~] = netcdf.inq(nc);
for aa=0:natts-1
    gattname{aa+1} = netcdf.inqAttName(nc,netcdf.getConstant('NC_GLOBAL'),aa);
    gattval{aa+1} = netcdf.getAtt(nc,netcdf.getConstant('NC_GLOBAL'),gattname{aa+1});
end

end
