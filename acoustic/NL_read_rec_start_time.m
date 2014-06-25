function Date = NL_read_rec_start_time(FileName)
% Read_logger_start_time(FileName) reads the start time of recording (first sample time) 
% from a sea noise logger data (*.DAT) file.
% Start times are stored in date number since 1/01/0001 00:00:00

Date = NaN;
NHeader = 2;

Fid = fopen(FileName, 'r', 'b');
Header = textscan(Fid, '%s', NHeader, 'Delimiter', '');
fclose(Fid);

SH = Header{1}{1};
if ~strcmp(SH(1:13),'Record Header')
    warning('Corrupted data file. It is ignored') 
else
    S = Header{1}{2};
    if length(S) == 38
        DateStr = S(12:30);
        Date = datenum(DateStr, 'yyyy/mm/dd HH:MM:SS');
    else
        warning('Corrupted data file. It is ignored') 
    end
end
