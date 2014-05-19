function [data,VarName]=NetCDF_LoadVar(nc,variable_name)
%% Input
%% *variable_name is the variable we're looking for in the NetCDF file, it
%% isn't case sensitive.
%% *nc is the NetCDF identifier, resulting from netcdf.open
%%
%% output
%% *data is the data vector
%% *VarName is the real variable name as written in the NetCDF
%%


%% list all the Variables
ii=1;
Bool=1;
while  Bool==1
    try
        [varname, ~, ~, varatts] = netcdf.inqVar(nc,ii-1);
        VARNAME{ii}=varname;
        VARATTS{ii}=varatts;
        ii=ii+1;
        Bool=1;
    catch
        Bool=0;
    end
end


idxVAR= strcmpi(VARNAME,variable_name)==1; %idx to remove from ttt
if sum(idxVAR)~=0
    VarName=VARNAME{idxVAR};
    data=netcdf.getVar(nc,netcdf.inqVarID(nc,VarName));
else
    disp('the variable does not exist or is badly written')
    data=[];
    VarName=[];
    return
end

end