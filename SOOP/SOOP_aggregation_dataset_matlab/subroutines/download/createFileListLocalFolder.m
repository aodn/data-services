function dataFileLocation = createFileListLocalFolder(queryResult)

global TEMPORARY_FOLDER;


if exist(fullfile(TEMPORARY_FOLDER,'alreadyAggregated.mat'),'file')
    load (fullfile(TEMPORARY_FOLDER,'alreadyAggregated.mat'))
else
    fileAlreadyUsed=cell(1,1);
end

vesselName={queryResult.vesselName}';
vesselNameUnique=unique(vesselName);
nVessel=length(vesselNameUnique);

dataFileLocation = struct;


for iiVessel=1:nVessel
    clear timeEndVessel timeEnd timeStartVessel timeStart
    % create vessel folder
    vesselFolder=char(strrep(strcat(TEMPORARY_FOLDER,filesep,vesselNameUnique(iiVessel)),' ','_'));
    mkpath(vesselFolder);
    
    % find all indexes matching one Vessel
    if ~isempty(char(vesselNameUnique(iiVessel)))
        booleanVesselNameArray=strfind(vesselName,char(vesselNameUnique(iiVessel)));
        booleanVesselNameArray=~cellfun('isempty',booleanVesselNameArray);
        indexVesselName=find(booleanVesselNameArray==1);
        nIndexVesselName=length(indexVesselName);
        
        % in case some values are empty
        timeStart={queryResult(indexVesselName). timeStart}';
        timeStart(cellfun('isempty', timeStart)) = {'NULL'}; % we replace the empty value by 'NULL'
        valid = not(strcmp( timeStart, 'NULL')); % look for the non NULL values
        timeStartVessel(valid) = datenum( timeStart(valid),'yyyy-mm-dd HH:MM:SS');
        timeStartVessel(~valid) = NaN;
        
        % in case some values are empty
        timeEnd={queryResult(indexVesselName).timeEnd}';
        timeEnd(cellfun('isempty',timeEnd)) = {'NULL'}; % we replace the empty value by 'NULL'
        valid = not(strcmp(timeEnd, 'NULL')); % look for the non NULL values
        timeEndVessel(valid) = datenum(timeEnd(valid),'yyyy-mm-dd HH:MM:SS');
        timeEndVessel(~valid) = NaN;
        
        % first and last data date for this vessel
        yearStart=str2double(datestr(min(timeStartVessel),'yyyy'));
        yearEnd=str2double(datestr(max(timeStartVessel),'yyyy'));
    else
        emptyID=find(cellfun('isempty',vesselName));
        fprintf('%s - The following DataBase entries are missing some information to be used:\n',datestr(now))
        
        for iiCorrupted=1:length(emptyID)
            fprintf('%s\n',queryResult(emptyID(iiCorrupted)).opendap)
        end
        yearStart=[];
        yearEnd=[];
    end
    
    
    for iiYear=yearStart:yearEnd
        clear yearFile pathFile filepath  filename  ext filesInYearIndex globalIndex indexFacilityPath
        clear indexYearFilesAlreadyUsedSameYearAsiiYear nFilesAlreadyUsedSameYear nFilesYear
        % create year folder
        yearFolder=char(strcat(vesselFolder,filesep,num2str(iiYear)));
        mkpath(yearFolder);
        
        yearNum=datenum(num2str(iiYear),'yyyy');
        filesInYearIndex=find(timeStartVessel>=datenum(num2str(iiYear),'yyyy') & timeStartVessel<datenum(num2str(iiYear+1),'yyyy'));
        
        % get all file names from the SQL query
        globalIndex=indexVesselName(filesInYearIndex);
        [filepath, filename, ext]=cellfun(@fileparts, {queryResult(globalIndex).opendap}', 'un',0);
        indexFacilityPath=cell2mat(regexp(filepath(:),'/IMOS/SOOP/','once') );
        for iiFacilityPath=1:length(indexFacilityPath)
            pathFile{iiFacilityPath}= filepath{iiFacilityPath}(indexFacilityPath+length('/IMOS/SOOP/'):end);%locate the dateStart string
        end
        
        filenameNC=strcat(filename,ext);
        
        % condition for first run
        if ~cellfun('isempty',fileAlreadyUsed)
            %             nFilesAlreadyUsed=length(int16(find(ismember( filenameNC(:), fileAlreadyUsed(:))==0)'));
            %             nFilesAlreadyUsed=sum(~cellfun('isempty',fileAlreadyUsed));
            %% Year for each file previously used (from the *.mat)
            indexFilesAlreadyUsedVessel=~cellfun('isempty',strfind((fileAlreadyUsed),char(vesselNameUnique(iiVessel))));
            FilesAlreadyUsedVessel=fileAlreadyUsed(indexFilesAlreadyUsedVessel);
            
            A=cell2mat(regexp(FilesAlreadyUsedVessel(:),'_[0-9]{8}T','once') ); %index of year string for each file
            if ~isempty(A)
                for jjFileAlreadyUsed=1:length(FilesAlreadyUsedVessel)
                    yearFile(jjFileAlreadyUsed)=str2double( FilesAlreadyUsedVessel{jjFileAlreadyUsed}( A(jjFileAlreadyUsed)+1: A(jjFileAlreadyUsed)+4));%locate the dateStart string
                end
                
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
            fprintf('%s - Vessel: %s Year %d \n%d file(s) has(ve) disappeared from DB,not normal\n',datestr(now),...
                vesselNameUnique{iiVessel},...
                iiYear,...
                int16((nFilesAlreadyUsedSameYear-nFilesYear)))
            
        elseif nFilesYear > nFilesAlreadyUsedSameYear
            fprintf('%s - Vessel: %s Year %d - %d New files to aggregate\n',datestr(now),...
                vesselNameUnique{iiVessel},...
                iiYear,...
                int16(-(nFilesAlreadyUsedSameYear-nFilesYear)))
            
            %% we redownload all the concerned files. The previous
            %% aggregated file has to be deleted
            for iiFiles=1:nFilesYear
                globalIndex=indexVesselName(filesInYearIndex(iiFiles));
                URL=queryResult(globalIndex).opendap;
                
                urlPrefix = 'http://thredds.aodn.org.au/thredds/fileServer/IMOS/';
                urlFile = URL(length(urlPrefix)+1 : end);
                urlPrefix_replace = [ readConfig('df.path', 'config.txt','=') filesep 'opendap' ];
                
                dataFileLocation.(['vessel_' vesselNameUnique{iiVessel}]).(['year_' num2str(iiYear)]){iiFiles} = [urlPrefix_replace filesep urlFile];
            end
            
            
            
        elseif nFilesYear==nFilesAlreadyUsedSameYear
            fprintf('%s - Vessel:%s - No new files to aggregate for year %d\n',datestr(now),vesselNameUnique{iiVessel},iiYear)
        end
        
    end
end


end