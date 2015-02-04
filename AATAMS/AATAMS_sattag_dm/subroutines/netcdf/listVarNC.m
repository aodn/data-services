function [allVarnames,allVaratts]=listVarNC(nc)
%% list all the Variables
ii            = 1;
Bool          = 1;
% preallocation
[~,nvars,~,~] = netcdf.inq(nc);% nvar is actually the number of Var + dim. 
allVarnames   = cell(1,nvars);
allVaratts    = cell(1,nvars);

while  Bool==1
    try
		[varname, ~, ~, varatts] = netcdf.inqVar(nc,ii-1);
		allVarnames{ii}          = varname;
		allVaratts{ii}           = varatts;
		ii                       = ii+1;
		Bool                     = 1;
    catch
        Bool                     = 0;
    end
end
end
