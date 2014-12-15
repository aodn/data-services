function [allVarInfo]=getVarInfo(nc)
%% list all the Variables
ii            = 1;
Bool          = 1;
% preallocation
[~,nvars,~,~] = netcdf.inq(nc);% nvar is actually the number of Var + dim.
allVarnames   = cell(1,nvars);
allVaratts    = cell(1,nvars);

while  Bool == 1
    try
        [varname, ~, ~, varatts] = netcdf.inqVar(nc,ii-1);
        allVarnames{ii}          = varname;
        allVaratts{ii}           = varatts;
        ii                       = ii+1;
        Bool                     = 1;
        
    catch
        Bool = 0;
    end
end


%% get all variable attributes and put information into a structure
nVar       = length(varname);
allVarInfo = struct;
for jjVar = 1:nVar
    allVarInfo(jjVar).standard_name = allVarnames{jjVar};

    for ii=0:allVaratts{jjVar}-1
        varid   = netcdf.inqVarID(nc,allVarnames{jjVar});
        attname = netcdf.inqAttName(nc,varid,ii);
    
        if ~isempty(strfind(attname,'_FillValue'))
            allVarInfo(jjVar).('FillValue') = netcdf.getAtt(nc,varid,attname);
        else
            allVarInfo(jjVar).(attname)     = netcdf.getAtt(nc,varid,attname);
        end
    
    end

end
