function downloadFiles_V1(queryResult,aggregationType)
global AGGREGATED_DATA_FOLDER;
global SCRIPT_FOLDER;
global TEMPORARY_FOLDER;


if exist(fullfile(TEMPORARY_FOLDER,'alreadyAggregated.mat'),'file')
    load (fullfile(TEMPORARY_FOLDER,'alreadyAggregated.mat'))
else
    fileAlreadyUsed=cell(1,1);
end

vesselName={queryResult.vesselName}';
vesselNameUnique=unique(vesselName);
nVessel=length(vesselNameUnique);

for iiVessel=1:nVessel
    % find all indexes matching one Vessel
    if ~isempty(char(vesselNameUnique(iiVessel)))
        booleanVesselNameArray=strfind(vesselName,char(vesselNameUnique(iiVessel)));
        booleanVesselNameArray=~cellfun('isempty',booleanVesselNameArray);
        indexVesselName=find(booleanVesselNameArray==1);
        nIndexVesselName=length(indexVesselName);
        
        % opendapVesselUrl={queryResult(indexVesselName).opendap}';
        timeStartVessel=datenum({queryResult(indexVesselName).timeStart}','yyyy-mm-dd HH:MM:SS');
        timeEndVessel=datenum({queryResult(indexVesselName).timeEnd}','yyyy-mm-dd HH:MM:SS');
        
        % first and last data date for this vessel
        yearStart=str2double(datestr(min(timeStartVessel),'yyyy'));
        yearEnd=str2double(datestr(max(timeStartVessel),'yyyy'));
    else
        emptyID=find(cellfun('isempty',vesselName));
        fprintf('%s - The following DataBase entries are missing some information to be used:\n',datestr(now))
       for iiCorrupted=1:length(emptyID)
            fprintf('%s - %s\n',datestr(now),queryResult(emptyID(iiCorrupted)).opendap)
        end
        yearStart=[];
        yearEnd=[];
    end
    
    
    for iiYear=yearStart:yearEnd
        clear yearFile pathFile filepath  filename  ext filesInYearIndex globalIndex indexFacilityPath
        clear indexYearFilesAlreadyUsedSameYearAsiiYear nFilesAlreadyUsedSameYear nFilesYear
        yearNum=datenum(num2str(iiYear),'yyyy');
        filesInYearIndex=find(timeStartVessel>=datenum(num2str(iiYear),'yyyy') & timeStartVessel<datenum(num2str(iiYear+1),'yyyy'));
        
        % get all file names from the SQL query
        globalIndex=indexVesselName(filesInYearIndex);
        [filepath, filename, ext]=cellfun(@fileparts, {queryResult(globalIndex).opendap}', 'un',0);
        indexFacilityPath=cell2mat(regexp(filepath(:),'/IMOS/SOOP/*/','once','end') );
        for iiFacilityPath=1:length(indexFacilityPath)
            pathFile{iiFacilityPath}= filepath{iiFacilityPath}(indexFacilityPath:end);%locate the dateStart string
        end
        
        uniquePath=uunique(pathFile);
        for jj=1:length(uniquePath)
            mkpath(strcat(TEMPORARY_FOLDER,filesep,uniquePath{jj}))
        end
        
        filenameNC=strcat(pathFile',filesep,filename,ext);
        
        % condition for first run
        if ~cellfun('isempty',fileAlreadyUsed)
            %% Year for each file previously used (from the *.mat)
            indexFilesAlreadyUsedVessel=~cellfun('isempty',strfind((fileAlreadyUsed),char(vesselNameUnique(iiVessel))));
            FilesAlreadyUsedVessel=fileAlreadyUsed(indexFilesAlreadyUsedVessel);
            
            A=cell2mat(regexp(FilesAlreadyUsedVessel(:),'_[0-9]{8}T','once') ); %index of year string for each file
            for jjFileAlreadyUsed=1:length(FilesAlreadyUsedVessel)
                yearFile(jjFileAlreadyUsed)=str2double( FilesAlreadyUsedVessel{jjFileAlreadyUsed}( A(jjFileAlreadyUsed)+1: A(jjFileAlreadyUsed)+4));%locate the dateStart string
            end
            
            indexYearFilesAlreadyUsedSameYearAsiiYear=find(yearFile==iiYear);
            nFilesAlreadyUsedSameYear=length(indexYearFilesAlreadyUsedSameYearAsiiYear);
        else
            nFilesAlreadyUsedSameYear=0;
        end
        
        nFilesYear=length(filesInYearIndex);
        
        % if the number of files is not the same,different possibilities
        if nFilesYear < nFilesAlreadyUsedSameYear
                        fprintf('%s - Vessel:%s Year %d \n%d file(s) has(ve) disappeared from DB,not normal\n',datestr(now),...
                vesselNameUnique{iiVessel},...
                iiYear,...
                int16((nFilesAlreadyUsedSameYear-nFilesYear)))

%             fprintf('-Vessel:%s Year %d \n%d file(s) has(ve) disappeared from DB,not normal\n',...
%                 vesselNameUnique{iiVessel},...
%                 iiYear,...
%                 int16((nFilesAlreadyUsedSameYear-nFilesYear)))
        elseif nFilesYear > nFilesAlreadyUsedSameYear
             fprintf('%s - Vessel:%s Year %d - %d New files to aggregate\n',datestr(now),...
                vesselNameUnique{iiVessel},...
                iiYear,...
                int16(-(nFilesAlreadyUsedSameYear-nFilesYear)))
%             fprintf('-Vessel:%s - %d/nNew files to aggregate\n',...
%                 vesselNameUnique{iiVessel},...
%                 iiYear,...
%                 int16(nFilesYear-nFilesAlreadyUsedSameYear))
            %% we redownload all the concerned files. The previous
            %% aggregated file has to be deleted
            for iiFiles=1:nFilesYear
                globalIndex=indexVesselName(filesInYearIndex(iiFiles));
                URL=queryResult(globalIndex).opendap;
                fileName=filenameNC(iiFiles);
                
                opendap_server_online=0;
                TimeElapsed=0;
                while opendap_server_online==0 && TimeElapsed < 60
                    tic;
                    try
                        ncFileLocation=char(strcat(TEMPORARY_FOLDER,filesep,fileName));
                        urlwrite(URL,ncFileLocation);
                        dirNcFileLocation=dir(ncFileLocation);
                        
                        while dirNcFileLocation.bytes==0%  in case 0 byte, file badly downloaded
                            urlwrite(URL,ncFileLocation);
                            dirNcFileLocation=dir(ncFileLocation);
                        end
                        
                        opendap_server_online=1;
                        TimeElapsed=0;
                    catch
                        secWait=2;
                        fprintf('%s - WARNING: Cannot reach URL:"%s"  We wait %d secs\n',datestr(now),URL,secWait)
%                         fprintf('Cannot reach URL:"%s" \n We wait %d secs',URL,secWait)
                        
                        opendap_server_online=0;
                        pause(secWait);
                        TimeElapsed=toc+TimeElapsed;
                        ncFiles=[];
                    end
                end
                
            end
        elseif nFilesYear==nFilesAlreadyUsedSameYear
            fprintf('%s - Vessel:%s - No new files to aggregate for year %d\n',datestr(now),vesselNameUnique{iiVessel},iiYear)
        end
        
    end
end
