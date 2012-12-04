function Date = NL_read_rec_start_time(FileName)
% Read_logger_start_time(FileName) reads the start time of recording (first sample time) 
% from a sea noise logger data (*.DAT) file.
% Start times are stored in date number since 1/01/0001 00:00:00
Fid = fopen(FileName, 'r', 'b');
SH = fgetl(Fid);
if ~strcmp(SH(1:13),'Record Header')
    Date = [];
    warning('Corrupted data file. It is ignored') 
else
    S = fgetl(Fid);
    if length(S)== 38
        Year = str2double(S(12:15));
        Month = str2double(S(17:18));
        Day = str2double(S(20:21));
        Hour = str2double(S(23:24));
        Minute = str2double(S(26:27));
        Second = str2double(S(29:30));
        Date = datenum(Year, Month, Day, Hour, Minute, Second);
    else
        Date = [];
        warning('Corrupted data file. It is ignored') 
    end
end
fclose(Fid);
