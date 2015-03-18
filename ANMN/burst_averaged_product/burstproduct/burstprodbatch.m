function burstprodbatch()
% **** run from 10-nsp-mel
runStartDate = now;
fprintf('Start date of run: %s\n', datestr(runStartDate));

dataServicesDir = getenv('DATA_SERVICES_DIR');
opendapDir      = getenv('OPENDAP');
wipDir          = getenv('DATA');

lastrunFile = fullfile(dataServicesDir, 'ANMN/burst_averaged_product/burstproduct/lastrun.txt');
fLastrun = fopen(lastrunFile);
lastrunDate = textscan(fLastrun, '%f');   	% date of last run in datenum format, in cell
fclose(fLastrun);

timeSinceLastrun = runStartDate - lastrunDate{1};	% in days
fprintf('Time since last run: %3.2f days\n', timeSinceLastrun);

destDir = fullfile(wipDir, 'Products_Temp');

% **************** Reprocess any failures left from the last run: ***************
failedFiles     = {};
successFiles    = {};
faillistFile = fullfile(dataServicesDir, 'ANMN/burst_averaged_product/burstproduct/faillist.txt');
failedListString = fileread(faillistFile);
if ~isempty(failedListString)
    lastFailedFiles = textscan(failedListString, '%s\n'); % lastFailedFiles is a cell of cells
    lastFailedFiles = lastFailedFiles{1};
    
    nLastFailedFiles = length(lastFailedFiles);
    successFiles = cell(1, nLastFailedFiles);
    failedFiles  = cell(1, nLastFailedFiles);
    for i=1:nLastFailedFiles
        % retry the ith failed file
        lastFailedFile = lastFailedFiles{i};
        fprintf('Retrying file: %s\n', lastFailedFile)
        try
            if ~isempty(strfind(lastFailedFile, 'WQM'))
                burstAvgFile = singleWQMburstavproduct(lastFailedFile, destDir); % singleWQMburstavproduct creates and moves new prod file to destDir
            elseif ~isempty(strfind(lastFailedFile, 'CTD'))
                burstAvgFile = singleCTDburstavproduct(lastFailedFile, destDir);
            else
                fprintf('Error. Filename does not include WQM or CTD: %s\n', lastFailedFile);
                failedFiles{i} = lastFailedFile;
                continue;
            end
            successFiles{i} = lastFailedFile;
            fprintf('Success\n');
        catch exc
            fprintf('Error. %s\n', getReport(exc, 'extended'));
            failedFiles{i} = lastFailedFile;
        end
    end
end
% empty content of faillist.txt
fclose(fopen(faillistFile, 'w')); % create/open file for writing. Discard existing contents, if any.

if ~isempty(failedFiles)
	TotalfailedFiles = failedFiles;
else
	TotalfailedFiles = [];		% initialise for later concatenation
end
if ~isempty(successFiles)
	TotalsuccessfulFiles = successFiles;
else
	TotalsuccessfulFiles = [];	% same
end

%% 1. WQM instrument files
failedFiles  = {}; 
successFiles = {};
anmnDir = fullfile(opendapDir, 'ANMN');
fprintf('Scanning directory %s for WQM:\n', anmnDir);
[~, cmdout] = system(['find ' anmnDir ' -type f -name "*_FV01_*-WQM-*.nc" -cnewer ' lastrunFile]);
% find any .nc files that have been accessed (including moved to anmnDir) at a later date than
% lastrun.txt was modified (at the end of the previous run of this program)
% cmdout is the listing of latest nc files (probably empty), but format 1 x n string, filenames all joined tog
% Now extract the path strings from the appended string output in cmdout.
if ~isempty(cmdout)
    cmdoutEnds = strfind(cmdout, char(10)); % 10 is the ASCII code for '\n'
    cmdoutStart = [1, cmdoutEnds(1:end-1)+1];
    cmdoutEnds = cmdoutEnds-1; % we don't want the carriage return
    nFoundFiles = length(cmdoutEnds);
    for i=1:nFoundFiles
        foundFile = cmdout(cmdoutStart(i):cmdoutEnds(i));
        fprintf('Found recent file: %s\n', foundFile);
        if  ~isempty(strfind(foundFile, '200804')) && ~isempty(strfind(foundFile, 'NRSMAI'))
            printf('Excluded NRSMAI 200804.\n');
        else
            try
                burstAvgFile = singleWQMburstavproduct(foundFile, destDir); % singleWQMburstavproduct creates and moves new prod file to destDir
                burstAvgFileInfo = dir(burstAvgFile);
                % no call to remove old prod, because we're only processing new files with this version.
                if burstAvgFileInfo.bytes < 5000
                    fprintf('Warning: output file may be empty: %s\n', burstAvgFileInfo.name);
                end
                successFiles = [successFiles, {foundFile}];
                
            catch exc
                getReport(exc, 'extended')
                fprintf('Failed file %s\n', foundFile);
                failedFiles = [failedFiles, {foundFile}];
            end
        end
    end
    if ~isempty(failedFiles)
        TotalfailedFiles = [TotalfailedFiles, failedFiles];
    end
    if ~isempty(successFiles)
        TotalsuccessfulFiles = [TotalsuccessfulFiles, successFiles];
    end
    fprintf('Number of WQM files tried = %3.0f\n', nFoundFiles);
end

%% 2. NXIC-CTD instrument files
failedFiles  = {};
successFiles = {};
fprintf('Scanning directory %s for NXIC-CTD:\n', anmnDir);
[~, cmdout] = system(['find ' anmnDir ' -type f -name "*_FV01_*-NXIC-CTD-*.nc" -cnewer ' lastrunFile]);
% find any .nc files that have been accessed (including moved to kdirpath) at a later date than
% lastrun.txt was modified (at the end of the previous run of this program)
% cmdout is the listing of latest nc files (probably empty), but format 1 x n string, filenames all joined tog
% Now extract path strings from the appended string output in cmdout.
if ~isempty(cmdout)
    cmdoutEnds = strfind(cmdout, char(10)); % 10 is the ASCII code for '\n'
    cmdoutStart = [1, cmdoutEnds(1:end-1)+1];
    cmdoutEnds = cmdoutEnds-1; % we don't want the carriage return
    nFoundFiles = length(cmdoutEnds);
    for i=1:nFoundFiles
        foundFile = cmdout(cmdoutStart(i):cmdoutEnds(i));
        fprintf('Found recent file: %s\n', foundFile);
        try
            burstAvgFile = singleCTDburstavproduct(foundFile, destDir);
            burstAvgFileInfo = dir(burstAvgFile);
            %		removeoldproduct(newprod_filepath,dest)
            % removed a call to remove old prod, because we're not producing duplicates.
            if burstAvgFileInfo.bytes < 5000
                fprintf('Warning: output file may be empty: %s\n', burstAvgFileInfo.name);
            end
            successFiles = [successFiles, {foundFile}];
            
        catch exc
            getReport(exc, 'extended')
            fprintf('Failed file %s\n', foundFile);
            failedFiles = [failedFiles, {foundFile}];
        end
    end
    if ~isempty(failedFiles)
        TotalfailedFiles = [TotalfailedFiles, failedFiles];
    end
    if ~isempty(successFiles)
        TotalsuccessfulFiles = [TotalsuccessfulFiles, successFiles];
    end
    fprintf('Number of NXIC-CTD files tried = %3.0f\n', nFoundFiles);
end

if ~isempty(TotalsuccessfulFiles)
    fprintf('List of successfully processed files:\n');
    for j=1:length(TotalsuccessfulFiles)
        fprintf('%s\n', TotalsuccessfulFiles{j});
    end
end

if ~isempty(TotalfailedFiles)
    fprintf('List of files causing errors:\n');
    fFaillist = fopen(faillistFile, 'w');	% will overwrite any previous stuff in faillist.txt
    for j=1:length(TotalfailedFiles)
        fprintf('%s\n', TotalfailedFiles{j});
        fprintf(fFaillist, '%s\n', TotalfailedFiles{j});
    end
    fclose(fFaillist);
else
    fprintf('No failures.\n')
end

runEndDate = datenum(clock);		% time at end of run in datenum format
fLastrun = fopen(lastrunFile, 'w');
fprintf(fLastrun, '%f', runEndDate);
fclose(fLastrun);
end