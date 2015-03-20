function [DATA] = getTimeDataNC(ncid)
% Retrieve the data from the main time variable TIME (no case sensitive).
% Reads the CF string units such as 'days since' or 'seconds since' and convert
% the time appropriately.
%
% Inputs:
%    ncid     : netcdf identifier resulted from netcdf.open
% Output:
%    DATA     : Time value in the matlab format
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Oct 2012; Last revision: 12-mar-2015
%% Copyright 2012 IMOS
% The script is distributed under the terms of the GNU General Public License



if ~isnumeric(ncid),          error('ncid must be a numerical value');        end

[allVarnames,~] = listVarNC(ncid);

%% we grab the date dimension
idxTIME         = strcmpi(allVarnames,'TIME')==1;
TimeVarName     = allVarnames{idxTIME};
date_var_id     = netcdf.inqVarID(ncid,TimeVarName);

try
    date_dim_id = netcdf.inqDimID(ncid,TimeVarName);
    [~, dimlen] = netcdf.inqDim(ncid,date_dim_id);
catch
    %if TIME is not a dimension
    [~, dimlen] = netcdf.inqVar(ncid,date_var_id);
end



DATA = [];
if dimlen >0
    preDATA    = netcdf.getVar(ncid,date_var_id);

    %read time offset from ncid
    strOffset  = netcdf.getAtt(ncid,date_var_id,'units');

    expression = ['(?<year>\d+)-(?<month>\d+)-(?<day>\d+).*(?<hour>\d+):(?<minute>\d+):(?<second>\d+)'];
    tokenNames = regexp(strOffset,expression,'names');
    Y_off      = str2double(tokenNames.year);
    M_off      = str2double(tokenNames.month);
    D_off      = str2double(tokenNames.day);
    H_off      = str2double(tokenNames.hour);
    MN_off     = str2double(tokenNames.minute);
    S_off      = str2double(tokenNames.second);

    if ~isempty(strfind(strOffset,'days'))
        NumDay  = double(D_off+preDATA);
        preDATA = datenum(Y_off, M_off, NumDay, H_off, MN_off, S_off);
        DATA    = [DATA;preDATA];

    elseif ~isempty(strfind(strOffset,'seconds'))
        NumSec  = double(S_off+preDATA);
        preDATA = datenum(Y_off, M_off, D_off, H_off, MN_off, NumSec);
        DATA    = [DATA;preDATA];

    end

elseif dimlen == 0
    frpintf('File is corrupted, or variable Time is badly spelled\n')
    DATA = [];
end

end