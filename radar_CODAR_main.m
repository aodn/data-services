function radar_CODAR_main(site_code, isQC)
%example of function call
%radar_CODAR_main('TURQ', false)
%
%The text file 'TURQ_last_update.txt' contains the date of the last update one
%the first line of the file.
%

%see files acorn_summary_CODAR.m and config.txt for any changes on the
%following global variables
global delayedModeStart
global delayedMode
global logfile 
global datadir

%new global variables are defined
global dfradialdata
global inputdir
global outputdir
global ncwmsdir
global dateFormat

nProcessedFiles = 0;

if isQC
    suffixConfigQC = 'QC';
    suffixUpdateQC = '_QC';
else
    suffixConfigQC = 'nonQC';
    suffixUpdateQC = '';
end

dfradialdata    = fullfile(readConfig('df.path'),   readConfig(['df.CODAR' suffixConfigQC '.subpath']));
inputdir        = fullfile(datadir,                 readConfig(['inputCODAR' suffixConfigQC '.subpath']));
outputdir       = fullfile(inputdir,                readConfig(['outputCODAR' suffixConfigQC '.subpath']));
ncwmsdir        = fullfile(readConfig('ncwms.path'),readConfig(['ncwmsCODAR' suffixConfigQC '.subpath']));
dateFormat      = 'yyyymmddTHHMMSS';

%
%USE of the site_code input to find the corresponding radar station
switch site_code
    case 'TURQ' % Turquoise Coast Group site (Western Australia)
        filelastupdate = fullfile(inputdir, ['TURQ' suffixUpdateQC '_last_update.txt']);
    case 'BONC' % Bonney Coast Group site (South Australia)
        filelastupdate = fullfile(inputdir, ['BONC' suffixUpdateQC '_last_update.txt']);
end

if delayedMode
    lastUpdate = delayedModeStart;
else
    %OPEN the text file and read the first line
    fid = fopen(filelastupdate, 'r');
    lastUpdate = fgetl(fid);
    fclose(fid);
end

[year, month, day, hour, ~, ~] = datevec(lastUpdate, dateFormat);
year    = num2str(year,     '%i');
month   = num2str(month,    '%02i');
day     = num2str(day,      '%02i');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Call the subfunction "getListFiles"
%the subfunction will return a list of NetCDF files available on the ARCS DAtafabric
%and ready for processing for a particular radar station
%the variables "listFiles" is then created

fprintf('%-30s ..... ', 'Listing available input files'); tic;

gotListFilesSite = false;
try
    listFiles = getListFiles(year, month, day, hour, site_code, false);
    if ~isempty(listFiles), gotListFilesSite = true; end
catch e
		% print error to logfile and console
		titleErrorFormat = '%s %s %s %s :\r\n';
		titleError = ['Problem in ' func2str(@getListFiles) ...
        ' to access files for this site from the following date'];
		messageErrorFormat = '%s\r\n';
		stackErrorFormat = '\t%s\t(%s: %i)\r\n';
    clockStr = datestr(clock);
    
    fid_w5 = fopen(logfile, 'a');
    fprintf(fid_w5, titleErrorFormat, clockStr, site_code, titleError, lastUpdate);
    fprintf(titleErrorFormat, clockStr, site_code, titleError, lastUpdate);
    fprintf(fid_w5, messageErrorFormat, e.message);
    fprintf(messageErrorFormat, e.message);
    s = e.stack;
    for k=1:length(s)
        fprintf(fid_w5, stackErrorFormat, s(k).name, s(k).file, s(k).line);
        fprintf(stackErrorFormat, s(k).name, s(k).file, s(k).line);
    end
    fclose(fid_w5);
end

fprintf('%3.3f %s\n', toc, 'sec')

if gotListFilesSite
    
    tic;
    
    dimfile = length(listFiles);
    for i = 1:dimfile
        try
            currentTimeStamp = radar_CODAR_create_current_data(listFiles{i, 1}, site_code, isQC);
            disp(currentTimeStamp);
            nProcessedFiles = nProcessedFiles + 1;
            
            if ~delayedMode
                %The date included in the input file is then updated
                fid_w4 = fopen(filelastupdate, 'w');
                fprintf(fid_w4, '%s\n', currentTimeStamp);
                fclose(fid_w4);
            end
        catch e
        		% print error to logfile and console
						titleErrorFormat = '%s %s %s\r\n';
						titleError = ['Problem in ' func2str(@radar_CODAR_create_current_data) ' to process the following file'];
						messageErrorFormat = '%s\r\n';
						stackErrorFormat = '\t%s\t(%s: %i)\r\n';
    				clockStr = datestr(clock);
    
            fid_w5 = fopen(logfile, 'a');
            fprintf(fid_w5, titleErrorFormat, clockStr, titleError, listFiles{i, 1});
            fprintf(titleErrorFormat, clockStr, titleError, listFiles{i, 1});
            fprintf(fid_w5, messageErrorFormat, e.message);
            fprintf(messageErrorFormat, e.message);
            s = e.stack;
            for k=1:length(s)
                fprintf(fid_w5, stackErrorFormat, s(k).name, s(k).file, s(k).line);
                fprintf(stackErrorFormat, s(k).name, s(k).file, s(k).line);
            end
            fclose(fid_w5);
        end
    end
    fprintf('%-30s ..... ', ['Done : ' num2str(nProcessedFiles) ' files']);
    fprintf('%3.3f %s\n', toc, 'sec')
else
    disp('No files to process');
    fid_w5 = fopen(logfile, 'a');
    fprintf(fid_w5, '%s %s %s %s\r\n', datestr(clock), site_code, ...
        'Problem : NO FILES TO PROCESS', lastUpdate);
    fclose(fid_w5);
end

end
