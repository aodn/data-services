function date_string=UTCstringfromlocal(time, offset)
% Convert from local to UTC in format for netcdf files
% Inputs
% time - datenum, number
% offset - number of hours to add to input time to convert to UTC
% eg. for Hobart, = -10
% Outputs
% y - string in format eg. '2013-03-25T03:40:00Z'
%       Minutes are rounded down: ie. seconds are re-assigned :00

date_UTC=datenum(time)+datenum([0 0 0 offset 0 0 ]);
vecdate=datevec(date_UTC); vecdate(6)=0; date_UTC=datenum(vecdate);
date_string=datestr(date_UTC,'yyyy-mm-dd HH:MM:SS');
date_string=strrep(date_string,' ','T'); date_string=strcat(date_string,'Z');