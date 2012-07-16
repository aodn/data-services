function [listAllFiles, theoreticalListFiles] = getListFiles(year, month, day, hour, station, theoreticalList)
%This subfunction will return a list of files available on the ARCS
%DATAFABRIC from the date specified and for a specific radar station
%The list of files is stored in the variable "listAllFiles"

%see files radar_WERA_main.m / radar_CODAR_main.m and config.txt for any changes on the
%following global variable
global delayedModeEnd
global delayedMode
global dfradialdata
global dateFormat

listAllFiles = {};
j = 1;
isComplete = false;

if delayedMode
    [lastYear, lastMonth, lastDay, lastHour, ~, ~] = datevec(delayedModeEnd, dateFormat);
else
    [lastYear, lastMonth, lastDay, lastHour, ~, ~] = datevec(now_utc);
end
lastYear    = num2str(lastYear,     '%i');
lastMonth   = num2str(lastMonth,    '%02i');
lastDay     = num2str(lastDay,      '%02i');

%The search of netCDF files starts at the specified day
fileInput = fullfile(dfradialdata, station, year, month, day, '*.nc');
listFiles = dir(fileInput);
nFiles = length(listFiles);
for i = 1:nFiles
    % we only want files for that day after the specified hour
    underScorePos = strfind(listFiles(i).name, '_');
    % we assume the date is the fourth element '_' separated in the file name and has the
    % following format '20120305T042000Z', ex. : IMOS_ACORN_RV_20120305T042000Z_RRK_FV00_radial.nc
    currentHourFile = str2double(listFiles(i).name(underScorePos(3)+10:underScorePos(3)+11));
    if (currentHourFile > hour)
        if strcmpi(year, lastYear) && strcmpi(month, lastMonth) && strcmpi(day, lastDay)
            if (currentHourFile <= lastHour)
                listAllFiles{j, 1} = listFiles(i).name;
                j = j + 1;
            else
                isComplete = true;
                break;
            end
        else
            listAllFiles{j, 1} = listFiles(i).name;
            j = j + 1;
        end
    end
end
clear fileInput listFiles nFiles

if (~isComplete)
    %The search of netCDF files continues at the specified month
    nMonths = fullfile(dfradialdata, station, year, month);
    listDays = dir(nMonths);
    nDays = length(listDays);
    for k = 3:nDays %from 3 to avoid . and ..
        % we only want days after the specified one
        if (str2double(listDays(k).name) > str2double(day))
            if (str2double(listDays(k).name) <= str2double(lastDay))
                if strcmpi(year, lastYear) && strcmpi(month, lastMonth) && strcmpi(listDays(k).name, lastDay)
                    % we take all the files for each of those days until the
                    % last day, last hour
                    fileInput = fullfile(nMonths, listDays(k).name, '*.nc');
                    listFiles = dir(fileInput);
                    nFiles = length(listFiles);
                    for i = 1:nFiles
                        underScorePos = strfind(listFiles(i).name, '_');
                        currentHourFile = str2double(listFiles(i).name(underScorePos(3)+10:underScorePos(3)+11));
                        if (currentHourFile <= lastHour)
                            listAllFiles{j, 1} = listFiles(i).name;
                            j = j + 1;
                        else
                            isComplete = true;
                            break;
                        end
                    end
                    if isComplete, break; end
                else
                    % we take all the files for each of those days
                    fileInput = fullfile(nMonths, listDays(k).name, '*.nc');
                    listFiles = dir(fileInput);
                    nFiles = length(listFiles);
                    for i = 1:nFiles
                        listAllFiles{j, 1} = listFiles(i).name;
                        j = j + 1;
                    end
                end
            else
                isComplete = true;
                break;
            end
        end
    end
    clear nMonths listDays nDays fileInput listFiles nFiles
end

if (~isComplete)
    %The search of netCDF files continues at the specified year
    yearInput = fullfile(dfradialdata, station, year);
    listMonths = dir(yearInput);
    nMonths = length(listMonths);
    for k = 3:nMonths %from 3 to avoid . and ..
        % we only want months after the specified one
        if (str2double(listMonths(k).name) > str2double(month))
            if (str2double(listMonths(k).name) <= str2double(lastMonth))
                % we take all the days for each of those months
                nMonths = fullfile(yearInput, listMonths(k).name);
                listDays = dir(nMonths);
                nDays = length(listDays);
                for l = 3:nDays
                    if strcmpi(year, lastYear) && strcmpi(listMonths(k).name, lastMonth) && strcmpi(listDays(l).name, lastDay)
                        % we take all the files for each of those days until the
                        % last day, last hour
                        fileInput = fullfile(nMonths, listDays(l).name, '*.nc');
                        listFiles = dir(fileInput);
                        nFiles = length(listFiles);
                        for i = 1:nFiles
                            underScorePos = strfind(listFiles(i).name, '_');
                            currentHourFile = str2double(listFiles(i).name(underScorePos(3)+10:underScorePos(3)+11));
                            if (currentHourFile <= lastHour)
                                listAllFiles{j, 1} = listFiles(i).name;
                                j = j + 1;
                            else
                                isComplete = true;
                                break;
                            end
                        end
                        if isComplete, break; end
                    else
                        % we take all the files for each of those days
                        fileInput = fullfile(nMonths, listDays(l).name, '*.nc');
                        listFiles = dir(fileInput);
                        nFiles = length(listFiles);
                        for i = 1:nFiles
                            listAllFiles{j, 1} = listFiles(i).name;
                            j = j + 1;
                        end
                    end
                end
                if isComplete, break; end
            else
                isComplete = true;
                break;
            end
        end
    end
    clear yearInput listMonths nMonths nMonths listDays nDays fileInput listFiles nFiles
end

if (~isComplete)
    %Let's finally look for netCDF files for the following years after the
    %specified one
    stationInput = fullfile(dfradialdata, station);
    listYears = dir(stationInput);
    nYears = length(listYears);
    for k = 3:nYears %from 3 to avoid . and ..
        % we only want years after the specified one
        if (str2double(listYears(k).name) > str2double(year))
            if (str2double(listYears(k).name) <= str2double(lastYear))
                % we take all the months for each of those years
                yearInput = fullfile(stationInput, listYears(k).name);
                listMonths = dir(yearInput);
                nMonths = length(listMonths);
                for m = 3:nMonths
                    % we take all the days for each of those months
                    monthInput = fullfile(yearInput, listMonths(m).name);
                    listDays = dir(monthInput);
                    nDays = length(listDays);
                    for l = 3:nDays
                        if strcmpi(listYears(k).name, lastYear) && strcmpi(listMonths(m).name, lastMonth) && strcmpi(listDays(l).name, lastDay)
                            % we take all the files for each of those days until the
                            % last day, last hour
                            fileInput = fullfile(monthInput, listDays(l).name, '*.nc');
                            listFiles = dir(fileInput);
                            nFiles = length(listFiles);
                            for i = 1:nFiles
                                underScorePos = strfind(listFiles(i).name, '_');
                                currentHourFile = str2double(listFiles(i).name(underScorePos(3)+10:underScorePos(3)+11));
                                if (currentHourFile <= lastHour)
                                    listAllFiles{j, 1} = listFiles(i).name;
                                    j = j + 1;
                                else
                                    isComplete = true;
                                    break;
                                end
                            end
                            if isComplete, break; end
                        else
                            % we take all the files for each of those days
                            fileInput = fullfile(monthInput, listDays(l).name, '*.nc');
                            listFiles = dir(fileInput);
                            nFiles = length(listFiles);
                            for i = 1:nFiles
                                listAllFiles{j, 1} = listFiles(i).name;
                                j = j + 1;
                            end
                        end
                    end
                    if isComplete, break; end
                end
                if isComplete, break; end
            else
                isComplete = true;
                break;
            end
        end
    end
    clear stationInput listYears nYears yearInput listMonths nMonths monthInput listDays nDays fileInput listFiles nFiles
end

% what is best for the following processing is to have a theoretical list
% of files if we would have all the files found on the DF
startDate   = datestr(datenum(str2double(year), str2double(month), str2double(day), hour, 0, 0) + (1/24), dateFormat);

lastFile = listAllFiles{end};

underScorePos = strfind(lastFile, '_');
% we assume the date is the fourth element '_' separated in the file name and has the
% following format '20120305T042000Z', ex. : IMOS_ACORN_RV_20120305T042000Z_RRK_FV00_radial.nc
endDate = lastFile(underScorePos(3)+1:underScorePos(3)+16);

if strcmpi(endDate(13), '5'), startDate(13) = '5'; end

nIdealFiles = round((datenum(endDate, dateFormat) - datenum(startDate, dateFormat))/((1/24)/6)) + 1;
allDatesNum = (datenum(startDate, dateFormat):((1/24)/6):datenum(endDate, dateFormat))';

prefix = repmat(lastFile(1:underScorePos(3)), nIdealFiles, 1);
suffix = repmat(lastFile(underScorePos(4)-1:end), nIdealFiles, 1);

theoreticalListFiles = cellstr([prefix datestr(allDatesNum, dateFormat) suffix]);
    
if theoreticalList && ~isempty(listAllFiles)
    % we set to empty where there is no file
    iExist = ismember(theoreticalListFiles, listAllFiles);
    listAllFiles = theoreticalListFiles;
    if any(~iExist), [listAllFiles{~iExist}] = deal(''); end
end

end