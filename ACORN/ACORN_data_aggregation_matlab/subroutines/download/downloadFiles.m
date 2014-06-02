function downloadFiles(fileList,fileSize,acornStation)
%% downloadFiles
% downloadFiles downloads the files needed to be aggregated for each
% acornStation. It takes in entry the output of List_NC_recur.m
%
%
% Functional Requirements/software capabilitie
% <Itemize the detailed functional requirements associated with this feature. These are
% the software capabilities that must be present in order for the user to carry out the
% services provided by the feature, or to execute the use case. Include how the product
% should respond to anticipated error conditions or invalid inputs. Requirements should
% be concise, complete, unambiguous, verifiable, and necessary. Use “TBD” as a placeholder
% to indicate when necessary information is not yet available.>
%
% The first time ever this function is called, it intends to download all
% the files found in fileList. If the file is properly downloaded, it is
% moved into a folder named according to the data year found in the file 
% (following some regexp on the% filename). 
% If the file size is null, the subroutine tries again couple of
% times with the same server opendap1.fileserver (QCIF). If the file size is still
% 0Bytes, the program tries with another server (VPAC). It would be
% possible to modify the code easily to add a new server catalog. If the
% file is still not accessible, or the file size is null, we guess there is
% a problem with the access of both VPAC and QCIF. Therefor, we stop the
% download of the rest of the files from fileList, since we don't want
% this function to run forever. Let's imagine the server is down, and we
% try to download 1000 files, if we add all the pauses, and tries on both
% servers, this could take an enormous amount of time to do absolutely nothing. 
% This is why it is preferable to stop. 
%
% For the next runs of this subroutine, it will open a local *mat file
% which is a local database of all the files which have been previously 
% aggregated together successfully.
% 
% If more hourly files are discovered in fileList for any
% month, then all the files for this month have to be downloaded again. 
% Because:
% 1) we need to create a more complete aggregated NetCDF file for this
% month
% 2) All the files previously downloaded and aggregated together are deleted 
% (to save storage, and because the aggregation script has been written following
% this requirement)
%
% If less files are discovered, we report it and write it in the log file.
% Unfortunately, we cannot do anything else. The reason for this may come from
% an incomplete harvest of the catalog with List_NC_recur.m, due to an
% unreachable opendap catalog. This could be due also to some files no longer 
% available on the opendap catalog.
%
%
%
% Requirements :
%
% Example :
% downloadFiles(fileList,acornStation)
% 
% 
%
% Inputs:
%   fileList                - output from List_NC_Reccur
%   fileSize                - output from List_NC_Reccur
%   acornStation               - string of the station to process
%
% Outputs :
%   
%
% Author: Laurent Besnard <laurent.besnard@utas.edu.au>
%
%
% Other m-files required:List_NC_recur
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also:
% readConfig,List_NC_recur
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 8-Oct-2012

AGGREGATED_DATA_FOLDER = readConfig('dataACORN.path', 'config.txt','=');
TEMPORARY_FOLDER=char(strcat(AGGREGATED_DATA_FOLDER,filesep,'DATA_FOLDER/temporary_',acornStation));
aggregationType=readConfig('aggregationType', 'config.txt','=');

if exist(fullfile(TEMPORARY_FOLDER,'alreadyAggregated.mat'),'file')
    load (fullfile(TEMPORARY_FOLDER,'alreadyAggregated.mat'))
else
    fileAlreadyUsed=cell(1,1);
    fprintf('%s - First launch of this script for the station: "%s". All files found on the opendap catalog will be downloaded\n',datestr(now),char(acornStation))

end

% create station folder
stationFolder=char(strcat(TEMPORARY_FOLDER,filesep,acornStation));
mkpath(stationFolder);

indexTimeQueryResult=cell2mat(regexp(fileList(:),'_[0-9]{8}T','once') ); %index of year string for each file
if ~isempty(indexTimeQueryResult)
    extractTimeStr = cellfun(@(x) x(indexTimeQueryResult+1:indexTimeQueryResult+length('yyyymmddTHHMMSS')),fileList,'UniformOutput',0);
    timeStartStation=datenum(extractTimeStr,'yyyymmddTHHMMSS');
end
clear indexTimeQueryResult

[yearFile,~,~]=datevec(timeStartStation);


switch aggregationType
    case 'year'
        yearStation=uunique(yearFile);
        yearStart=min(yearStation);
        yearEnd=max(yearStation);
        
        % populate date for each file previously downloaded
        if ~cellfun('isempty',fileAlreadyUsed)
            % Year for each file previously used (from the *.mat)
            indexFilesAlreadyUsedStation=~cellfun('isempty',strfind((fileAlreadyUsed),char(acornStation)));
            FilesAlreadyUsedStation=fileAlreadyUsed(indexFilesAlreadyUsedStation);
            
            indexTimeAlreadyDownloadedFiles=cell2mat(regexp(FilesAlreadyUsedStation(:),'_[0-9]{8}T','once') ); %index of year string for each file
            if ~isempty(indexTimeAlreadyDownloadedFiles)
                yearFile = str2double(cellfun(@(x) x(indexTimeAlreadyDownloadedFiles+1:indexTimeAlreadyDownloadedFiles+4),FilesAlreadyUsedStation,'UniformOutput',0));
            end
        end
        
        for iiYear=yearStart:yearEnd
            clear pathFile filepath  filename  ext filesInYearIndex globalIndex indexFacilityPath
            clear indexYearFilesAlreadyUsedSameYearAsiiYear nFilesAlreadyUsedSameYear nFilesYear
            % create year folder
            yearFolder=char(strcat(stationFolder,filesep,num2str(iiYear)));
            mkpath(yearFolder);
            
            %             yearNum=datenum(num2str(iiYear),'yyyy');
            filesInYearIndex=find(timeStartStation>=datenum(num2str(iiYear),'yyyy') & timeStartStation<datenum(num2str(iiYear+1),'yyyy'));
            
            % get all file names from the query
            [~, filename, ext]=cellfun(@fileparts, fileList(filesInYearIndex), 'un',0);
            filenameNC=strcat(filename,ext);
            
            % condition for first run
            if ~cellfun('isempty',fileAlreadyUsed)
                if ~isempty(indexTimeAlreadyDownloadedFiles)
                    indexYearFilesAlreadyUsedSameYearAsiiYear=find(yearFile==iiYear);
                    nFilesAlreadyUsedSameYear=length(indexYearFilesAlreadyUsedSameYearAsiiYear);
                else
                    nFilesAlreadyUsedSameYear=0;
                end
                
            else
                nFilesAlreadyUsedSameYear=0;
            end
            
            nFilesYear=length(filesInYearIndex);
            
            % if the number of files is not the same,different possibilities
            if nFilesYear < nFilesAlreadyUsedSameYear
                fprintf('%s - Station:%s - %d file(s) has(ve) disappeared from OpenDap(?) for year/month %d,not normal. Manual check required\n',...
                    datestr(now),char(acornStation),...
                    int16(nFilesYear-nFilesAlreadyUsedSameYear),...
                    iiYear)
            elseif nFilesYear > nFilesAlreadyUsedSameYear
                fprintf('%s - Station:%s - %d new files to aggregate for year/month %d\n',...
                    datestr(now),char(acornStation),...
                    int16(nFilesYear-nFilesAlreadyUsedSameYear),...
                    iiYear)
                %% we redownload all the concerned files. The previous
                %% aggregated file has to be deleted
                for iiFiles=1:nFilesYear
                    globalIndex=(filesInYearIndex(iiFiles));
                    URL=strcat(readConfig('opendap1.fileserver', 'config.txt','='),char(fileList(globalIndex)));
                    filePath=strcat(yearFolder,filesep);
                    fileName=filenameNC(iiFiles);
                    [online]=downloadURL(fileName,filePath,URL);
                    if ~online
                        fprintf('%s - Both VPAC and QCIF servers to download the data seems to be not accessible. We stop downloading data.\n',datestr(now))
                        return
                    end
                end
                
            elseif nFilesYear==nFilesAlreadyUsedSameYear
                fprintf('%s - Station:%s - No new files to aggregate for year/month %d\n',datestr(now),char(acornStation),iiYear)
            end
            
        end
        
    case 'month'
        monthStation=cellfun(@(x) x(1:6),extractTimeStr,'UniformOutput',0);
        monthStation=uunique(monthStation);
        monthStation=str2double(monthStation);
        
        % populate date for each file previously downloaded
        if ~cellfun('isempty',fileAlreadyUsed)
            % Month for each file previously used (from the *.mat)
            indexFilesAlreadyUsedStation=~cellfun('isempty',strfind((fileAlreadyUsed),char(acornStation)));
            FilesAlreadyUsedStation=fileAlreadyUsed(indexFilesAlreadyUsedStation);
            
            indexTimeAlreadyDownloadedFiles=cell2mat(regexp(FilesAlreadyUsedStation(:),'_[0-9]{8}T','once') ); %index of month string for each file
            if ~isempty(indexTimeAlreadyDownloadedFiles)
                monthFile = str2double(cellfun(@(x) x(indexTimeAlreadyDownloadedFiles+1:indexTimeAlreadyDownloadedFiles+6),FilesAlreadyUsedStation,'UniformOutput',0));
            end
        end
        
        for iiMonth=monthStation'
            clear pathFile filepath  filename  ext filesInMonthIndex globalIndex indexFacilityPath
            clear indexMonthFilesAlreadyUsedSameMonthAsiiMonth nFilesAlreadyUsedSameMonth nFilesMonth
            % create month folder
            monthStr=num2str(iiMonth);
            %             monthFolder=char(strcat(stationFolder,filesep,monthStr(1:4),filesep,monthStr(5:6)));% create one month subfolder
            monthFolder=char(strcat(stationFolder,filesep,monthStr(1:4))); %only one folder per year
            mkpath(monthFolder);
            
            monthNum=datenum(num2str(iiMonth),'yyyymm');
            filesInMonthIndex=find(timeStartStation>=monthNum & timeStartStation<datenum(num2str(iiMonth+1),'yyyymm'));
            
            % get all file names from the query
            [~, filename, ext]=cellfun(@fileparts, fileList(filesInMonthIndex), 'un',0);
            filenameNC=strcat(filename,ext);
            filesizeNC=fileSize(filesInMonthIndex);
            
            % condition for first run
            if ~cellfun('isempty',fileAlreadyUsed)
                if ~isempty(indexTimeAlreadyDownloadedFiles)
                    indexMonthFilesAlreadyUsedSameMonthAsiiMonth=find(monthFile==iiMonth);
                    nFilesAlreadyUsedSameMonth=length(indexMonthFilesAlreadyUsedSameMonthAsiiMonth);
                else
                    nFilesAlreadyUsedSameMonth=0;
                end
                
            else
                nFilesAlreadyUsedSameMonth=0;
            end
            
            nFilesMonth=length(filesInMonthIndex);
            
            % if the number of files is not the same,different possibilities
            if nFilesMonth < nFilesAlreadyUsedSameMonth
                fprintf('%s - Station:%s - %d file(s) has(ve) disappeared from OpenDap(?) for year/month %d,not normal. Manual check required\n',...
                    datestr(now),char(acornStation),...
                    int16(nFilesMonth-nFilesAlreadyUsedSameMonth),...
                    iiMonth)
            elseif nFilesMonth > nFilesAlreadyUsedSameMonth
                fprintf('%s - Station:%s - %d new files to aggregate for year/month %d\n',...
                    datestr(now),char(acornStation),...
                    int16(nFilesMonth-nFilesAlreadyUsedSameMonth),...
                    iiMonth)
                %% we redownload all the concerned files. The previous
                %% aggregated file has to be deleted
                for iiFiles=1:nFilesMonth
                    globalIndex=(filesInMonthIndex(iiFiles));
                    URL=strcat(readConfig('opendap1.fileserver', 'config.txt','='),char(fileList(globalIndex)));
                    filePath=strcat(monthFolder,filesep);
                    fileName=filenameNC(iiFiles);
                    
                    if filesizeNC(iiFiles)~=0
                        [online]=downloadURL(fileName,filePath,URL);
                        if ~online
                            fprintf('%s - Both VPAC and QCIF servers to download the data seems to be not accessible. We stop downloading data.\n',datestr(now))
                            return
                        end
                    else
                        fprintf('%s - WARNING: File %s has a size of 0bytes. File is corrupted from the source\n',datestr(now),char(fileName))
                    end
                end
                
            elseif nFilesMonth==nFilesAlreadyUsedSameMonth
                fprintf('%s - Station:%s - No new files to aggregate for month %d\n',...
                    datestr(now),char(acornStation),iiMonth)
            end
            
        end
        
end

end

function [opendap_server_online]=downloadURL(fileName,filePath,URL)
% downloadURL download the URL to the folder filePath
%
% Functional Requirements/software capabilitie
%If the file size is null, the subroutine tries again couple of
% times with the same server opendap1.fileserver (QCIF). If the file size is still
% 0Bytes, the program tries with another server (VPAC). It would be
% possible to modify the code easily to add a new server catalog. If the
% file is still not accessible, or the file size is null, we guess there is
% a problem with the access of both VPAC and QCIF.
%
%
% Requirements : URLWRITE2 from Fu-Sung Wang
%
% Example :
% [opendap_server_online]=downloadURL(fileName,filePath,URL)
%
% Inputs:
%   fileName                - filename to download
%   filePath                - folder where the file will be downloaded
%   URL                     - URL of the file to download 
%
% Outputs :
%   opendap_server_online     - boolean (1 if success, 0 if not)
%
% Author: Laurent Besnard <laurent.besnard@utas.edu.au>
%
%
% Other m-files required:readConfig
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also:
% readConfig,aggregateFiles
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 10-Sept-2012
timeOut=20000;%in ms
timeToPause=2;%in sec

ncFileLocation=char(strcat(filePath,fileName));
[~,opendap_server_online]=urlwrite2(URL,ncFileLocation,[],[],timeOut);

if opendap_server_online
    dirNcFileLocation=dir(ncFileLocation);
    
    % in case the downloaded file has a size of 0bytes, we try nCountLimit
    % times
    nCount=0;
    nCountLimit=10;
    while dirNcFileLocation.bytes==0 && nCount <= nCountLimit%  in case 0 byte, file probably badly downloaded
        pause(timeToPause) %in sec , and we start again
        [~,opendap_server_online]=urlwrite2(URL,ncFileLocation,[],[],timeOut);
        dirNcFileLocation=dir(ncFileLocation);
        nCount=nCount+1;
    end
    
    if dirNcFileLocation.bytes==0
        opendap_server_online=0;
    end
end

%% if not online we try with another server and do the same thing again
if ~opendap_server_online
    fprintf('%s - ERROR: UNREACHABLE URL:"%s". We are trying with another server\n',...
        datestr(now),URL)
    %     URL_VPAC=strrep(URL,'qcif','vpac'); % we don't do this anymore, in
    %     case we want to add a new server in the future
    URL_secondServer_pre=readConfig('opendap2.fileserver', 'config.txt','=');
    sizeURL1=length(readConfig('opendap1.fileserver', 'config.txt','='));
    suffixeURL=URL(sizeURL1+1:end);
    URL_secondServer=[URL_secondServer_pre suffixeURL];
    [~,opendap_server_online]=urlwrite2(URL_secondServer,ncFileLocation,[],[],timeOut);
    
    if opendap_server_online
        dirNcFileLocation=dir(ncFileLocation);
        
        % in case the downloaded file has a size of 0bytes, we try nCountLimit
        % times
        nCount=0;
        nCountLimit=4;
        while dirNcFileLocation.bytes==0 && nCount <= nCountLimit%  in case 0 byte, file badly downloaded
            pause(timeToPause) %in sec , and we start again
            [~,opendap_server_online]=urlwrite2(URL_secondServer,ncFileLocation,[],[],timeOut);
            dirNcFileLocation=dir(ncFileLocation);
            nCount=nCount+1;
        end
        
        if ~opendap_server_online
            fprintf('%s - ERROR: UNREACHABLE URL:"%s"\n',datestr(now),URL_secondServer)
        end
        
        if dirNcFileLocation.bytes==0
            fprintf('%s - ERROR: Tried to download the file %s on both server, but it has a size of 0bytes. Maybe the file is corrupted from the source"\n',datestr(now),URL_secondServer)
            opendap_server_online=1;
            delete(ncFileLocation)
        end
    end
end

end