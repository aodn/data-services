function DATA = getVarNC(varName,ncid)
%%getVarNC gets the data of a variable from a NetCDF file.
%
% WARNING : This function DOES NOT modifies the values found in a variable with
% information from valid_min max, scale factor, add offset...
% SEE getVarNetCDF for this
%
% The script lists all the Variables in the NetCDF file. If the
% variable is called TIME (case does not matter), then the variable is
% converted to a matlab time value, by adding the time offset ... following
% the CF conventions
% If the variable to load is not TIME, the data is extracted, and all values
% are modified according to the attributes of the variable following the CF
% convention (such as value_min value_max, scale-factor , _Fillvalue ...)
% http://cf-pcmdi.llnl.gov/documents/cf-conventions/1.1/cf-conventions.html
% Syntax:  [varData,varAtt]=getVarNetCDF(varName,ncid)
%
% Inputs:
%       ncid         : result from netcdf.open
%       varName      : string of variable name to load. To get list of
%                      variable names, type listVarNC(ncid)
% Outputs:
%    DATA            : var data unmodified
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Oct 2012; Last revision: 30-Oct-2012
%% Copyright 2012 IMOS
% The script is distributed under the terms of the GNU General Public License




[allVarnames,~] = listVarNC(ncid);

if ~isnumeric(ncid),          error('ncid must be a numerical value');        end
if ~ischar(varName),          error('varName must be a string');        end

idxVar     = strcmpi(allVarnames,varName)==1;
strVarName = allVarnames{idxVar};
DATA       = netcdf.getVar(ncid,netcdf.inqVarID(ncid,strVarName));
end
