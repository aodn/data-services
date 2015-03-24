function [numOffset,strOffset,firstDate,LastDate] = getTimeOffsetNC(ncid)
% Retrieve information from the main time variable TIME (no case sensitive).
% Reads the CF string units such as 'days since' or 'seconds since'
%
% Inputs       :
%    ncid      : netcdf identifier resulted from netcdf.open
% Output       :
%    strOffset : 'units' attribute in the string format
%    numOffset : 'units' attribute in the matlab time format
%    firstDate : first date of the TIME value
%    LastDate  : last date of the TIME value
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Oct 2012; Last revision: 12-Mar-2015
%% Copyright 2012 IMOS
% The script is distributed under the terms of the GNU General Public License



if ~isnumeric(ncid),          error('ncid must be a numerical value');        end

[allVarnames,~] = listVarNC(ncid);

%% we grab the date dimension
idxTIME     = strcmpi(allVarnames,'TIME')==1;
TimeVarName = allVarnames{idxTIME};
date_var_id = netcdf.inqVarID(ncid,TimeVarName);

try
    date_dim_id = netcdf.inqDimID(ncid,TimeVarName);
    [~, dimlen] = netcdf.inqDim(ncid,date_dim_id);
catch
    %if TIME is not a dimension
    [~, dimlen] = netcdf.inqVar(ncid,date_var_id);
end


if dimlen >0
    firstDate = netcdf.getVar(ncid,date_var_id,0);
    if dimlen==1
        LastDate = netcdf.getVar(ncid,date_var_id,0);
    else
        LastDate = netcdf.getVar(ncid,date_var_id,dimlen-1);
    end

    %read time offset from ncid
    strOffset    = netcdf.getAtt(ncid,date_var_id,'units');

    expression = ['(?<year>\d+)-(?<month>\d+)-(?<day>\d+).*(?<hour>\d+):(?<minute>\d+):(?<second>\d+)'];
    tokenNames = regexp(strOffset,expression,'names');
    Y_off      = str2double(tokenNames.year);
    M_off      = str2double(tokenNames.month);
    D_off      = str2double(tokenNames.day);
    H_off      = str2double(tokenNames.hour);
    MN_off     = str2double(tokenNames.minute);
    S_off      = str2double(tokenNames.second);

    numOffset = datenum(Y_off, M_off, D_off, H_off, MN_off,S_off);

    if ~isempty(strfind(strOffset,'days'))
        firstDate                                   = datenum([Y_off, M_off, double((D_off+firstDate)), H_off, MN_off, S_off]);
        LastDate                                    = datenum([Y_off, M_off, double((D_off+LastDate)), H_off, MN_off, S_off]);

    elseif ~isempty(strfind(strOffset,'seconds'))
        firstDate                                   = datenum([Y_off, M_off, D_off, H_off, MN_off, double((S_off+firstDate))]);
        LastDate                                    = datenum([Y_off, M_off, D_off, H_off, MN_off, double(S_off+LastDate)]);

    end

elseif dimlen ==0
    fprintf('File is corrupted, or variable Time is badly spelled\n')
    numOffset = [];
    strOffset = [];
    firstDate = [];
    LastDate  = [];
end

end
