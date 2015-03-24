function [ firstDate,lastDate,creationDate ] = AIMS_fileDates( ncFile )
%AIMS_fileDates returns the firstdate, last date and creation date as
%written in the filename of an AIMS IMOS netcdf file
    A=textscan(ncFile,'%s', 14, 'delimiter', '_');
    firstDate =  datenum(A{1}{4},'yyyymmddTHHMMSS');
    lastDate = datenum(A{1}{7}(5:end),'yyyymmddTHHMMSS');
    creationDate = datenum(A{1}{8}(3:end),'yyyymmddTHHMMSS');

end

