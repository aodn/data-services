function aggregateFiles(acornStation)
% aggregateFiles - aggregation of acorn data
%
% Functional Requirements/software capabilitie
% <Itemize the detailed functional requirements associated with this feature. These are
% the software capabilities that must be present in order for the user to carry out the 
% services provided by the feature, or to execute the use case. Include how the product
% should respond to anticipated error conditions or invalid inputs. Requirements should
% be concise, complete, unambiguous, verifiable, and necessary. Use “TBD” as a placeholder 
% to indicate when necessary information is not yet available.>
% 
% This function lists all the hourly files downloaded in the different
% subfolders of one station folder (for example
% DATA_FOLDER/temporary_ROT/ROT). Then it creates a yearly or monthly list of files to
% aggregate according to the user choice. 
%
% During the creating of these lists, a series of tests is performed to
% make sure the aggregation will work properly. Here is the list of test:
% -no more that one data type in this folder (by checking there is only one
% similar filename prefix to aggregate  
% -if corrupted time variable or different grid to aggregate together, the message
% will be: "Aggregation could not be performed.Corrupted DataSet"
% -check time variable is never above year 2200 defined by yearLimit
% -Time Var is not empty nor null
% -File has not a size of 0bytes
% -If the files don't have the same variable names (upper & lower case), then 
% a ncml file is created to replace the corresponding NetCDF file in the 
% list of files to aggregate
%
% Syntax:  aggregateFiles(acornStation)
%
% Inputs:  acornStation : string of the station code
%   
%
% Outputs:
%    
%
% Example: 
%    aggregateFiles('ROT')
%
%
%
% Other m-files required:readConfig
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also:
% Aggregation_Sub_ACORN,readConfig,checkFilesBelongsToYear,
% checkFilesBelongsToMonth,performAggregationFromList
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% June 2012; Last revision: 24-Aug-2012
global TEMPORARY_FOLDER;

aggregationType=readConfig('aggregationType', 'config.txt','=');

stationFolder=dir(TEMPORARY_FOLDER);
nstationFolder=length(stationFolder)-2;

% main directory where data where downloaded
for iiStation=1+2:nstationFolder+2
    if isempty(strfind(stationFolder(iiStation).name,'aggregated_datasets')) && stationFolder(iiStation).isdir==1
        
        dataFolder=strcat(TEMPORARY_FOLDER,filesep,...,
            stationFolder(iiStation).name,filesep);
        
        [subFolder]=listSubDir(dataFolder);
        nSubFolder=length(subFolder);
        
        for iiSubFolder=1:nSubFolder
            clear prefix ncFiles uniquePrefix m n indexN subfileList
            ncFiles=DIRR(char(subFolder(iiSubFolder)),'name','.nc','isdir','0','bytes','>1000');%bytes to remove ncml files
            
            if ~isempty(ncFiles)  %no files
                ncFiles=strcat(subFolder(iiSubFolder),filesep,({ncFiles.name})');
                
                A=cell2mat(regexp(ncFiles(1),'_[0-9]{8}T','once') ); %8 digits yyyymmdd. we assume all the files have the same year within one folder
                yearVar=str2double( ncFiles{1}(A+1:A+4));
                clear A
                % find prefix in IMOS filename, cf IMOS filenaming
                % convention
                [filepath, filename, ext]=cellfun(@fileparts, ncFiles, 'un',0);
                B=cell2mat(regexp(ncFiles,'_[0-9]{8}T','once') );
                %                 yearVar=str2double( ncFiles{1}(B(1)+1:B(1)+4));
                filename=strcat(filepath,filesep, filename,ext);
                prefix = cellfun(@(x) x(1:B-1),filename,'UniformOutput',0);
                
                clear B
                
                [uniquePrefix,m,n]=uunique(prefix);
                nUniquePrefix=length(uniquePrefix);
                
                % we check the number of different prefix of filename in
                % the same directory.Because we don't want to aggregate
                % different filetypes in the same file. It wouldn't work.
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
                                        performAggregationFromList(fileList(nList,:)',acornStation)
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
                    
                else
                    % we are in the normal case,where there is only one
                    % data type per directory
                    switch aggregationType
                        case 'year'
                            fileList=checkFilesBelongsToYear(ncFiles,yearVar);
                        case 'month'
                            fileList=checkFilesBelongsToMonth(ncFiles,yearVar);
                    end
                    
                    for nList=1:size(fileList,1)
                        try
                            if sum(~cellfun('isempty',fileList(nList,:)'))~=0
                                performAggregationFromList(fileList(nList,:)',acornStation)
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
            clear m n uniquePrefix nUniquePrefix filepath  filename  ext prefix ncFiles
        end
        
    end
end
end

function aggregationListFile=checkFilesBelongsToYear(ncFileList,yearToAggregate)
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
% aggregationListFile=cell(1);
countFiles=zeros(1,1);
aggregationListFile=cell(1,1);
for iiFiles=1:nNcFiles
    ncFileLocation=char(ncFileList(iiFiles));
    dirNcFileLocation=dir(ncFileLocation);
    if dirNcFileLocation.bytes~=0%  in case 0 byte, file badly downloaded
        nc = netcdf.open(ncFileLocation,'NC_NOWRITE');
        %% list all the Variables
        [VARNAME,~]=listVarNC(nc);
        
        
        %% we grab the date dimension
        [numOffset,~,firstDate,lastDate]= getTimeOffsetNC(nc);
        boundaryTime=[numOffset,datenum(2200,1,1,0,0,0)]; % we assume we should not have any data outside of this range
        
        if ~(firstDate <= boundaryTime(1) || firstDate >= boundaryTime(2) ...
                || lastDate <= boundaryTime(1) || lastDate >= boundaryTime(2) || firstDate > lastDate)
            
            %now we check that the time data is good.TRV files have
            %problems,we are forced to do so
            [DATA]= getTimeDataNC(nc);
            
            if sum(DATA>boundaryTime(2))==0 || sum(DATA<boundaryTime(1))==0 % no data outside of boundaries
                
                % condition for file to be within the year
                if firstDate >= datenum([yearToAggregate,1,1]) ...
                        && firstDate < datenum([yearToAggregate+1,1,1])
                    %                     countFiles=countFiles+1;
                    %                     aggregationListFile{countFiles}=char(ncFileList(iiFiles));
                    countFiles(1)=countFiles(1)+1;
                    aggregationListFile{1,countFiles(1)}=char(ncFileList(iiFiles));
                    
                else
                    fprintf('%s - WARNING: File is not in the year range:n%s',datestr(now),ncFileLocation)
                end
                
            else
                fprintf('%s - WARNING: File has a Time Dimension problem. Time Var is empty or null:n%s',datestr(now),ncFileLocation)
            end
            
        else
            fprintf('%s - WARNING: File has a Time Dimension problem. Time Var is empty or null:n%s',datestr(now),ncFileLocation)
        end
        
        netcdf.close(nc);
    else
        fprintf('%s - WARNING: The following file has a size of 0bytes. Probably badly downloaded.It will be added to the next launch of the code:\n%s',datestr(now),ncFileLocation)
    end
end
% aggregationListFile=aggregationListFile';
clear DATA
end


function aggregationListFile=checkFilesBelongsToMonth(ncFileList,yearToAggregate)
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
aggregationListFile=cell(12,1);
for iiFiles=1:nNcFiles
    ncFileLocation=char(ncFileList(iiFiles));
    dirNcFileLocation=dir(ncFileLocation);
    if dirNcFileLocation.bytes~=0%  in case 0 byte, file badly downloaded
        nc = netcdf.open(ncFileLocation,'NC_NOWRITE');
        %% list all the Variables
        [VARNAME,~]=listVarNC(nc);
        
        
        %% we grab the date dimension
        [numOffset,~,firstDate,lastDate]= getTimeOffsetNC(nc);
        boundaryTime=[numOffset,datenum(2200,1,1,0,0,0)]; % we assume we should not have any data outside of this range
        
        if ~(firstDate <= boundaryTime(1) || firstDate >= boundaryTime(2) ...
                || lastDate <= boundaryTime(1) || lastDate >= boundaryTime(2) || firstDate > lastDate)
            
            %now we check that the time data is good.TRV files have
            %problems,we are forced to do so
            %             [DATA]= getTimeData(nc,VARNAME);
            %             if sum(DATA>boundaryTime(2))==0 || sum(DATA<boundaryTime(1))==0 % no data outside of boundaries
            
            for month=1:12
                if firstDate >= datenum([yearToAggregate,month,1])...
                        && firstDate < datenum([yearToAggregate,month+1,1])
                    countFiles(month)=countFiles(month)+1;
                    aggregationListFile{month,countFiles(month)}=char(ncFileList(iiFiles));
                    %                 else
                    %                     fprintf('The following file is not in the year range:n%s',ncFileLocation)
                end
            end
            %             else
            %                 fprintf('The following file has a Time Dimension problem. Time Var is empty or null:n%s',ncFileLocation)
            %             end
        else
            fprintf('%s - WARNING: File has a Time Dimension problem. Time Var is empty or null:n%s',datestr(now),ncFileLocation)
            
        end
        
        netcdf.close(nc);
    else
        fprintf('%s - WARNING: File has a size of 0bytes. Probably badly downloaded.It will be added to the next launch of the code:\n%s',datestr(now),ncFileLocation)
    end
end
clear DATA
end