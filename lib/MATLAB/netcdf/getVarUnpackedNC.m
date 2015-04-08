function [varData,varAtt]=getVarUnpackedNC(varName,ncid)
%%getVarUnpackedNC gets the varData from a NetCDF for one variable only.
% WARNING : This function modifies the values found in a variable with information
% from valid_min max, scale factor, add offset... called unpacked.
%
% The script lists all the Variables in the NetCDF file. If the
% variable is called TIME (case does not matter), then the variable is
% converted to a matlab time value, by adding the time offset ... following
% the CF conventions
% If the variable to load is not TIME, the data is extracted, and all values
% are modified according to the attributes of the variable following the CF
% convention (such as value_min value_max, scale-factor , _Fillvalue ...)
% http://cf-pcmdi.llnl.gov/documents/cf-conventions/1.1/cf-conventions.html
% Syntax:  [varData,varAtt]=getVarUnpackedNC(varName,ncid)
%
% Inputs:
%       ncid         : result from netcdf.open
%       varName      : string of variable name to load. To get list of
%                      variable names, type listVarNC(ncid)
% Outputs:
%    varData         : ready to use data (modified according to the
%                      variable attributes)
%    varAtt          : variable attributes
%
% Example:
%    ncid=netcdf.open('IMOS_AUV_B_20070928T014025Z_SIRIUS_FV00.nc','NC_NOWRITE');
%    [varData,varAtt]=getVarUnpackedNC('TIME',ncid)
%
% Other m-files required:
% Other files required:
% Subfunctions: none
% MAT-files required: none
%
% See also: netcdf.open,listVarNC,getGlobAttNC
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Oct 2012; Last revision: 30-Oct-2012
%
% Copyright 2012 IMOS
% The script is distributed under the terms of the GNU General Public License

if ~isnumeric(ncid),          error('ncid must be a numerical value');        end
if ~ischar(varName),          error('varName must be a string');        end


ii=1;
Bool=1;
% preallocation
[~,nVars,~,~] = netcdf.inq(ncid);% nvar is actually the number of Var + dim.
allVarnames = cell(1,nVars);
allVaratts = cell(1,nVars);

while  Bool == 1
    try
        [varname, ~, ~, varatts] = netcdf.inqVar(ncid,ii-1);
        allVarnames{ii} = varname;
        allVaratts{ii} = varatts;
        ii = ii+1;
        Bool = 1;
    catch
        Bool = 0;
    end
end
%
%% get only varData for varName


if ~strcmpi(varName,'TIME')
    varData = [];
    varAtt = struct;
    idxVar = strcmpi(allVarnames,varName)==1;
    strVarName = allVarnames{idxVar};
    varData = netcdf.getVar(ncid,netcdf.inqVarID(ncid,strVarName));

    %% get all variable attributes and put information into a structure

    for ii = 0:allVaratts{idxVar}-1
        varid = netcdf.inqVarID(ncid,allVarnames{idxVar});
        attname = netcdf.inqAttName(ncid,varid,ii);
        if ~isempty(strfind(attname,'_FillValue'))
            varAtt.('FillValue') = netcdf.getAtt(ncid,varid,attname);
        else
            varAtt.(attname) = netcdf.getAtt(ncid,varid,attname);
        end
    end


    %% modify varData according to the attributes
    if isfield(varAtt,'valid_min')
        varData=double(varData);
        varData(varData<varAtt.valid_min) = NaN;
    end

    if isfield(varAtt,'valid_max')
        varData=double(varData);
        varData(varData>varAtt.valid_max) = NaN;
    end

    if isfield(varAtt,'FillValue')
        varData=double(varData);
        varData(varData==varAtt.FillValue) = NaN;
    end

    if isfield(varAtt,'scale_factor') && ~isfield(varAtt,'add_offset')
        varData=double(varData);
        varData = varData*double(varAtt.scale_factor);
    elseif isfield(varAtt,'scale_factor') && isfield(varAtt,'add_offset')
        varData=double(varData);       
        varData = varData * double(varAtt.scale_factor)+ double(varAtt.add_offset);
    elseif ~isfield(varAtt,'scale_factor') && isfield(varAtt,'add_offset')
        varData=double(varData);
        varData = varData+ double(varAtt.add_offset);
    end


else
    try
         % %% we grab the date dimension
         idxTIME = strcmpi(allVarnames,'TIME')==1;
         TimeVarName = allVarnames{idxTIME};

         varAtt = struct;

         %% get all variable attributes and put information into a structure
         for ii = 0:allVaratts{idxTIME}-1
             varid = netcdf.inqVarID(ncid,TimeVarName);
             attname = netcdf.inqAttName(ncid,varid,ii);
             if ~isempty(strfind(attname,'_FillValue'))
                 varAtt.('FillValue') = netcdf.getAtt(ncid,varid,attname);
             else
                 varAtt.(attname) = netcdf.getAtt(ncid,varid,attname);
             end
         end

         [varData] = getTimeDataNC(ncid);
    catch
         disp('File is corrupted, or variable Time is badly spelled')
         varData = [];
         varAtt  = [];
    end

end
end
