function aggregateFiles(soopSubFacility,dataFileLocation)
%% aggregateFiles - aggregation of soop data
%
%
% Syntax:  aggregateFiles
%
% Inputs:
%
%
% Outputs:
%
%
% Example:
%    aggregateFiles
%
% List of Tests:    -more that one data type in this folder
%                   -bad time variable or different grid, Error msg
%                   "Aggregation could not be performed.Corrupted DataSet"
%                   -check time variable never above year 2200 defined by
%                   yearLimit
%                   -Time Var is empty or null
%                   -File has a size of 0bytes
%                   -If the files don't have the same variable names (upper
%                   & lower case), then a ncml file is created to replace
%                   the corresponding NetCDF file in the list of files to
%                   aggregate
%
% Other m-files required:readConfig
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also:
% Aggregation_Sub_SOOP,readConfig,checkFilesBelongsToYear,
% checkFilesBelongsToMonth
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 24-Aug-2012

% global TEMPORARY_FOLDER;
aggregationType=readConfig('aggregationType', 'config.txt','=');


% vesselFolder=dir(TEMPORARY_FOLDER);
% nvesselFolder=length(vesselFolder)-2;

vesselFields = fieldnames(dataFileLocation);
nvessel = length( vesselFields);
for iiVessel=1:nvessel
    
    
    dataFolder = dataFileLocation.(vesselFields{iiVessel});
    
    subFolder = fieldnames(dataFolder);
    nSubFolder = length(subFolder);
    
    for iiSubFolder=1:nSubFolder
        clear prefix ncFileList uniquePrefix m n indexN subfileList
        ncFileList = dataFileLocation.(vesselFields{iiVessel}).(subFolder{iiSubFolder});
        
        
        if ~isempty(ncFileList)  %no files
            
            A=cell2mat(regexp(ncFileList(1),'_[0-9]{8}T','once') ); %8 digits yyyymmdd. we assume all the files have the same year within one folder
            yearVar=str2double( ncFileList{1}(A+1:A+4));
            clear A
            % find prefix
            [filepath, filename, ext]=cellfun(@fileparts, ncFileList, 'un',0);
            B=cell2mat(regexp(ncFileList,'_[0-9]{8}T','once') );
            filename=strcat(filepath,filesep, filename,ext);
            for ii=1:length(B)
                prefix{ii}= filename{ii}(1:B(ii)-1);%locate the dateStart string
            end
            clear B
            
            [uniquePrefix,m,n]=uunique(prefix);
            nUniquePrefix=length(uniquePrefix);
            
            if nUniquePrefix >1 % we have more that one data type in this folder
                %as they are ordered alphabeticaly
                for jj=1:nUniquePrefix
                    indexN= n==n(m(jj));
                    subfileList=sort(filename(indexN));
                    if length(subfileList)>1
                        switch aggregationType
                            case 'year'
                                fileList=checkFilesBelongsToYear(subfileList,yearVar);
                            case 'month'
                                fileList=checkFilesBelongsToMonth(subfileList,yearVar);
                        end
                        
                        
                        % multiple list if multiple month in the same
                        % directory.
                        for nList=1:size(fileList,1)
                            try
                                if sum(~cellfun('isempty',fileList(nList,:)'))~=0
                                    performAggregationFromList(fileList(nList,:)',soopSubFacility)
                                end
                            catch
                                % If aggregation failed at this stage,
                                % probably because of bad time
                                % variable, or different grid. Anyway
                                % the files are likely not too be
                                % consistent. Have to check manually,
                                % and debugging
                                % performAggregationFromList in order
                                % to see what is going on.
                                fprintf('%s - Aggregation could not be performed.Corrupted DataSet: "%s"  and the likes of it. We keep on trying the aggregation for the next files.\n',...
                                    datestr(now),char(fileList(nList,1)))
                            end
                        end
                    end
                    clear subfileList indexN fileList
                end
                
            else % we are in the normal case,implies more than 1 file per directory
                switch aggregationType
                    case 'year'
                        fileList=checkFilesBelongsToYear(ncFileList,yearVar);
                    case 'month'
                        fileList=checkFilesBelongsToMonth(ncFileList,yearVar);
                end
                
                
                for nList=1:size(fileList,1)
                    try
                        if sum(~cellfun('isempty',fileList(nList,:)'))~=0
                            performAggregationFromList(fileList(nList,:)',soopSubFacility)
                        end
                    catch
                        % If aggregation failed at this stage,
                        % probably because of bad time
                        % variable, or different grid. Anyway
                        % the files are likely not too be
                        % consistent. Have to check manually,
                        % and debugging
                        % performAggregationFromList in order
                        % to see what is going on.
                        
                        fprintf('%s - Aggregation could not be performed.Corrupted DataSet: "%s"  and the likes of it. We keep on trying the aggregation for the next files.\n',...
                            datestr(now),char(fileList(nList,1)))
                    end
                end
            end
        end
        clear m n uniquePrefix nUniquePrefix filepath  filename  ext prefix ncFileList
    end
    
    %     end
end
end


function fileList=checkFilesBelongsToYear(ncFileList,yearVar)
%checkFilesBelongsToYear
%This function takes in entry a list of NetCDF files, and check
%individually that each file belongs to the year yearVar. The function
%returns a list of files in order to be aggregated. If the files don't
%have the same variable names (upper & lower case), then a ncml file is
%created and will be used in the list.
%
% Syntax:  fileList=checkFilesBelongsToYear(ncFileList,yearVar)
%
% Inputs:
%
%
% Outputs:
%
%
% Example:
%    checkFilesBelongsToYear
%
% List of Tests:    -bad time variable or different grid, Error msg
%                   "Aggregation could not be performed.Corrupted DataSet"
%                   -check time variable never above year 2200 defined by
%                   yearLimit
%                   -Time Var is empty or null
%                   -File has a size of 0bytes
%
%
% Other m-files required:readConfig
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also: Aggregation_Sub_SOOP,readConfig
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 24-Aug-2012


nNcFiles=length(ncFileList);

% countFiles=0;
% fileList=cell(1);
countFiles=zeros(1,1);
fileList=cell(1,1);
for iiFiles=1:nNcFiles
    ncFileLocation=char(ncFileList(iiFiles));
    if exist(ncFileLocation,'file') == 2
        dirNcFileLocation=dir(ncFileLocation);
        if dirNcFileLocation.bytes~=0%  in case 0 byte, file badly downloaded
            nc = netcdf.open(ncFileLocation,'NC_NOWRITE');
            %% list all the Variables
            [VARNAME,~]=listVarNC(nc);
            
            
            %% we grab the date dimension
            yearLimit=2200;
            [numOffset,~,firstDate,lastDate]= getTimeOffsetNC(nc,VARNAME);
            boundaryTime=[numOffset,datenum(yearLimit,1,1,0,0,0)]; % we assume we should not have any data outside of this range
            
            if ~(firstDate <= boundaryTime(1) || firstDate >= boundaryTime(2) ...
                    || lastDate <= boundaryTime(1) || lastDate >= boundaryTime(2) || firstDate > lastDate)
                
                %now we check that the time data is good.TRV files have
                %problems,we are forced to do so
                [DATA]= getTimeData(nc,VARNAME);
                
                if sum(DATA>boundaryTime(2))==0 || sum(DATA<boundaryTime(1))==0 % no data outside of boundaries
                    
                    % condition for file to be within the year
                    if firstDate >= datenum([yearVar,1,1]) ...
                            && firstDate < datenum([yearVar+1,1,1])
                        %                     countFiles=countFiles+1;
                        %                     fileList{countFiles}=char(ncFileList(iiFiles));
                        countFiles(1)=countFiles(1)+1;
                        fileList{1,countFiles(1)}=char(ncFileList(iiFiles));
                        
                    else
                        fprintf('%s - File is not in the year range:%s\n',datestr(now),ncFileLocation)
                    end
                    
                else
                    fprintf('%s - File has a Time Dimension problem. Time Var is empty or null:%s\n',datestr(now),ncFileLocation)
                end
                
            else
                fprintf('%s - File has a Time Dimension problem. Time Var is empty or null:%s\n',datestr(now),ncFileLocation)
            end
            
            netcdf.close(nc);
        else
            fprintf('The following file has a size of 0bytes. Probably badly downloaded.It will be added on the next launch of the code:%s\n',ncFileLocation)
        end
    else
        fprintf('%s - File can not be found on the data storage:%s\n',datestr(now),ncFileLocation)
    end
end
% fileList=fileList';
clear DATA
end



function fileList=checkFilesBelongsToMonth(ncFileList,yearVar)
%checkFilesBelongsToMonth
%This function takes in entry a list of NetCDF files, and check
%individually that each file belongs to the year yearVar. The function
%returns a list of files in order to be aggregated. If the files don't
%have the same variable names (upper & lower case), then a ncml file is
%created and will be used in the list.
%
% Syntax:  fileList=checkFilesBelongsToMonth(ncFileList,yearVar)
%
% Inputs:
%
%
% Outputs:
%
%
% Example:
%    checkFilesBelongsToMonth
%
% List of Tests:    -bad time variable or different grid, Error msg
%                   "Aggregation could not be performed.Corrupted DataSet"
%                   -check time variable never above year 2200 defined by
%                   yearLimit
%                   -Time Var is empty or null
%                   -File has a size of 0bytes
%
%
% Other m-files required:readConfig
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also: checkFilesBelongsToYear,aggregateFiles
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 24-Aug-2012


nNcFiles=length(ncFileList);
ncFileList=sort(ncFileList);
countFiles=zeros(1,12);
fileList=cell(12,1);
for iiFiles=1:nNcFiles
    ncFileLocation=char(ncFileList(iiFiles));
    if exist(ncFileLocation,'file') == 2
        
        dirNcFileLocation=dir(ncFileLocation);
        yearLimit=2200;
        if dirNcFileLocation.bytes~=0%  in case 0 byte, file badly downloaded
            nc = netcdf.open(ncFileLocation,'NC_NOWRITE');
            %% list all the Variables
            [VARNAME,~]=listVarNC(nc);
            
            
            %% we grab the date dimension
            [numOffset,~,firstDate,lastDate]= getTimeOffsetNC(nc,VARNAME);
            boundaryTime=[numOffset,datenum(yearLimit,1,1,0,0,0)]; % we assume we should not have any data outside of this range
            
            if ~(firstDate <= boundaryTime(1) || firstDate >= boundaryTime(2) ...
                    || lastDate <= boundaryTime(1) || lastDate >= boundaryTime(2) || firstDate > lastDate)
                
                %now we check that the time data is good.TRV files have
                %problems,we are forced to do so
                %             [DATA]= getTimeData(nc,VARNAME);
                %             if sum(DATA>boundaryTime(2))==0 || sum(DATA<boundaryTime(1))==0 % no data outside of boundaries
                
                for month=1:12
                    if firstDate >= datenum([yearVar,month,1])...
                            && firstDate < datenum([yearVar,month+1,1])
                        countFiles(month)=countFiles(month)+1;
                        fileList{month,countFiles(month)}=char(ncFileList(iiFiles));
                        %                 else
                        %                     fprintf('The following file is not in the year range:n%s',ncFileLocation)
                    end
                end
                %             else
                %                 fprintf('The following file has a Time Dimension problem. Time Var is empty or null:n%s',ncFileLocation)
                %             end
            else
                fprintf('%s - File has a Time Dimension problem. Time Var is empty or null:%s\n',datestr(now),ncFileLocation)
                
            end
            
            netcdf.close(nc);
        else
            fprintf('%s - File has a size of 0bytes. Probably badly downloaded.It will be added on the next launch of the code:%s\n',datestr(now),ncFileLocation)
        end
    else
        fprintf('%s - File can not be found on the data storage:%s\n',datestr(now),ncFileLocation)
    end
end
clear DATA
end