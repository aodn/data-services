function data = getDATETIME_sqlite (filename,varargin)

fid = fopen(filename);
tline = fgets(fid);
i=1;
while ischar(tline)
    data{i} = tline;
    i =i+1;
    tline = fgets(fid);
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

