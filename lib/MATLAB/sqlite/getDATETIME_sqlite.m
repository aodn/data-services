function data = getDATETIME_sqlite (fileName,varargin)
%% getDATETIME_sqlite reads the text output of a select * from a
% sqlite file and returns a datenum array
% This is for a column of DATETIME type
%
% THIS FUNCTION IS CALLED BY getColumnValues_sqlite.m
%
% Inputs: fileName   : text output of a select query
%
% Outputs: data      : datenum array 
%
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Dec 2014; Last revision: 09-Dec-2014

fid   = fopen(fileName);
tline = fgets(fid);
i     = 1;
while ischar(tline)
    data{i} = tline;
    i       = i+1;
    tline   = fgets(fid);
end
fclose(fid);

%%% DEPRECIATED 
% find the machine timezone since SQLITE export without the timestamp
% timezone_datenum = getMachineTimezone;

nVarargs = size(varargin,1); % option to convert the time faster by knowing the type
if nVarargs == 1
    timeFormatOption = varargin{1};
    data = datenum(data,timeFormatOption);
else 
    data = datenum(data) ;
end
end

