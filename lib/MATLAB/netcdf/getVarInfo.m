function [allVarInfo] = getVarInfo(ncid)
% getVarInfo reads a NetCDF file identifier and returns a structure back of
% variable and all their respective attributes
% Inputs:
%    ncid       : netcdf identifier resulted from netcdf.open
% Outputs       :
%    allVarInfo : structure containing all variables information
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Oct 2012; Last revision: 30-Oct-2012
%% Copyright 2012 IMOS
% The script is distributed under the terms of the GNU General Public License



if ~isnumeric(ncid),          error('ncid must be a numerical value');        end

%% list all the Variables
ii            = 1;
Bool          = 1;
% preallocation
[~,nvars,~,~] = netcdf.inq(ncid);% nvar is actually the number of Var + dim.
allVarnames   = cell(1,nvars);
allVaratts    = cell(1,nvars);

while  Bool == 1
    try
        [varname, ~, ~, varatts] = netcdf.inqVar(ncid,ii-1);
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
        varid   = netcdf.inqVarID(ncid,allVarnames{jjVar});
        attname = netcdf.inqAttName(ncid,varid,ii);

        if ~isempty(strfind(attname,'_FillValue'))
            allVarInfo(jjVar).('FillValue') = netcdf.getAtt(ncid,varid,attname);
        else
            allVarInfo(jjVar).(attname)     = netcdf.getAtt(ncid,varid,attname);
        end

    end

end
