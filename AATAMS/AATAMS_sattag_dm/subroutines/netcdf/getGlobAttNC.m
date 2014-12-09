function [gattname,gattval]=getGlobAttNC(nc)
% preallocation
[ ~, ~, natts ,~] = netcdf.inq(nc);
gattname          = cell(1,natts);
gattval           = cell(1,natts);
for aa = 0:natts-1
	gattname{aa+1} = netcdf.inqAttName(nc,netcdf.getConstant('NC_GLOBAL'),aa);
	gattval{aa+1}  = netcdf.getAtt(nc,netcdf.getConstant('NC_GLOBAL'),gattname{aa+1});
end

end
