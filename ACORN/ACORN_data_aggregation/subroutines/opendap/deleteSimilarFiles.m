function deleteSimilarFiles(acornStation)
%% deleteSimilarFiles
% This function deletes ACORN files from the datafabric in order to keep only the most complete/recent
% monthly/yearly aggregated file for each station.
% For example, if there are two files respectively called:
%-IMOS_ACORN_V_20120801T003000Z_SAG_FV00_monthly-1-hour-avg_END-20120831T063000Z_C-20120911T150000Z.nc
%-IMOS_ACORN_V_20120801T003000Z_SAG_FV00_monthly-1-hour-avg_END-20120808T063000Z_C-20120911T150000Z.nc
%
% then the function deletes the second one following some string
% recognition rules.
%
% % 3 scenarios or more of files to Keep
%
%     A(1) /-----/     B(1)  : both files start at the same time, but don't end at the same time. We keep the bottom line
%     A(2) /------/    B(2)
%
%     A(1) /-------/   B(1)  : both files start at the same time, but don't end at the same time. We keep the top line
%     A(2) /----/      B(2)
%
%     A(1) /-------/   B(1)  :  We keep both
%     A(2)      /----/ B(2)
%
% Syntax:  deleteSimilarFiles(acornStation)
%
% Inputs:  acornStation : string of the station code
%
%
% Outputs:
%
%
% Example:
%    deleteSimilarFiles('ROT')
%   deleteSimilarFiles('SAG')
%
% Other m-files required:readConfig,rdir
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also:
% readConfig,aggregateFiles,Aggregate_ACORN,moveAggregatedFilestoDF
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 10-Sept-2012

DF_ROOT=readConfig('df.path', 'config.txt','=');
ACORN_opendapFolder=readConfig('df.acornAggregation.path', 'config.txt','=');

aggregationType=readConfig('aggregationType', 'config.txt','=');

if exist(strcat(DF_ROOT,'/opendap'),'dir') == 7
    fprintf('%s - Data Fabric is connected. We are checking for duplicated files\n',datestr(now))
    datafabricACORNFolder=(strcat(DF_ROOT,ACORN_opendapFolder,filesep,acornStation));
    
    ncFilesAggregated=rdir([datafabricACORNFolder, '/**/*.nc.gz'],'bytes>1000');%bytes to remove ncml files
    
    
    if ~isempty(ncFilesAggregated)
        ncFiles=({ncFilesAggregated.name})';
        
        switch aggregationType
            case 'year'
                
                fprintf('%s - WARNING: NO code has been written yet to delete files for this aggregationType "%s". Sorry for the inconvenience.\n',datestr(now),aggregationType);
                
            case 'month'
                
                [~, filename, ~]=cellfun(@fileparts, ncFiles, 'un',0);
                B=cell2mat(regexp(filename,'_[0-9]{8}T','once') );
                endStr=cell2mat(regexp(filename,'_END-[0-9]{8}T','once') );
                creationDateStr=cell2mat(regexp(filename,'_C-[0-9]{8}T','once') );
                
                % the following does not work well when B is different for
                % each array
                %                 yearMthFile_startFile = datenum(cellfun(@(x) x(B+1:B+6),filename,'UniformOutput',0),'yyyymm');
                %                 yearMthDayFile_startFile = datenum(cellfun(@(x) x(B+1:B+15),filename,'UniformOutput',0),'yyyymmddTHHMMSS');
                %                 yearMthDayFile_endFile = datenum(cellfun(@(x) x(endStr+length('_END-'):endStr+15+length('_END-')-1),filename,'UniformOutput',0),'yyyymmddTHHMMSS');
                %                 creationDateFile=datenum(cellfun(@(x) x(creationDateStr+length('_C-'):creationDateStr+15+length('_C-')-1),filename,'UniformOutput',0),'yyyymmddTHHMMSS');
                
                yearMthDayFile_endFile = zeros(1, length(filename));  % Pre-allocate
                for ii=1:length(filename)
                    yearMthDayFile_endFile(ii) =datenum(filename{ii}(endStr(ii)+length('_END-'):endStr(ii)+15+length('_END-')-1),'yyyymmddTHHMMSS');
                end
                
                creationDateFile = zeros(1, length(filename));  % Pre-allocate
                for ii=1:length(filename)
                    creationDateFile(ii) =datenum(filename{ii}(creationDateStr(ii)+length('_C-'):creationDateStr(ii)+15+length('_C-')-1),'yyyymmddTHHMMSS');
                end
                
                yearMthDayFile_startFile = zeros(1, length(filename));  % Pre-allocate
                for ii=1:length(filename)
                    yearMthDayFile_startFile(ii) =datenum(filename{ii}(B(ii)+1:B(ii)+15),'yyyymmddTHHMMSS');
                end
                
                yearMthFile_startFile = zeros(1, length(filename));  % Pre-allocate
                for ii=1:length(filename)
                    yearMthFile_startFile(ii) =datenum(filename{ii}(B(ii)+1:B(ii)+6),'yyyymm');
                end
                
                yearMthDayFile_endFile=yearMthDayFile_endFile';
                creationDateFile=creationDateFile';
                yearMthDayFile_startFile=yearMthDayFile_startFile';
                yearMthFile_startFile=yearMthFile_startFile';
                
                [uniqueYear,~,e]=unique(yearMthFile_startFile);
                
                if length(uniqueYear) < length(e)  % condition to find if they are more files that they should be
                    
                    %find value of YearMonth which is repeated
                    sa = sortrows(yearMthFile_startFile,1); %this is sorted according to the start date
                    %                     [~,idx1] = unique(sa(:,1),'first');
                    %                     [~,idx2] = unique(sa(:,1),'last');
                    %                     sameMonthValue = sa(idx1~=idx2,:);
                    sameMonthValue=repval(sa);
                    nsameMonthValue=length(sameMonthValue);
                    for iisameMonthValue=1:nsameMonthValue
                        indexsameMonthValue=(sa==sameMonthValue(iisameMonthValue));
                        
                        AA=yearMthDayFile_startFile(indexsameMonthValue);
                        BB=yearMthDayFile_endFile(indexsameMonthValue);
                        CC=creationDateFile(indexsameMonthValue);
                        % AA, and BB are already sorted according to
                        % the start date
                        
                        
                        [startDateToKeep,endDateToKeep,creationDateToKeep]=whichDatesToKeepArray(AA,BB,CC);
                        
                        indexFileToKeep=ismember(yearMthDayFile_startFile,startDateToKeep) & ismember(yearMthDayFile_endFile,endDateToKeep) & ismember(creationDateFile,creationDateToKeep);
                        
                        
                        
                        indexesToRemove=(indexFileToKeep~=indexsameMonthValue) ;
                        filesToDelete= (ncFiles(indexesToRemove));
                        if ~isempty(filesToDelete)
                            for jjfile=1:length(filesToDelete)
                                delete( filesToDelete{jjfile});
                                status=exist(filesToDelete{jjfile},'file');
                                if status==0
                                    fprintf('%s - SUCCESS: FILE DELETED FROM DF "%s"\n',datestr(now),filesToDelete{jjfile});
                                elseif status==2
                                    fprintf('%s - ERROR: FILE NOT DELETED FROM DF "%s"\n',datestr(now), filesToDelete{jjfile});
                                end
                            end
                            %
                        end
                    end
                end
                
        end
        
    end
    
else
    fprintf('%s - ERROR: Data Fabric is NOT connected, BUGGER |-( : Files will be copied next time\n',datestr(now))
end

end


function [startDateToKeep,endDateToKeep,creationDateToKeep]=whichDatesToKeepArray(startDate,endDate,creationDate)
%% whichDatesToKeepArray
% this function gives the dates to keep, given an array of startDate,
% endDate, creationDate.
% all the values are already converted into double, which means this
% function could potentially be used for other purposes
% we assume that StartDate is always sorted
% Syntax:  deleteSimilarFiles(acornStation)
%
% Inputs:  startDate   : array of double, sorted
%          endDate     : array of double
%          creationDate: array of double
% Outputs:
%
%
% Example:
%   startDate=[];endDate=[];creationDate=[];
%    startDate=[1,1,1,1,4,5]
%    endDate=[5,6,6,7,9,9]
%    creationDate=[77,77,78,78,78,78]
%    [startDateToKeep,endDateToKeep,creationDateToKeep]=whichDatesToKeepArray(startDate,endDate,creationDate)
%
%
% Other m-files required:readConfig,rdir
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also:
% readConfig,aggregateFiles,Aggregate_ACORN,moveAggregatedFilestoDF
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Oct 2012; Last revision: 2-Oct-2012

%NOT complete
if length(startDate)==2
    % quicker algorithm
    if (startDate(1) < startDate(2)) && (endDate(1) < endDate(2))
        startDateToKeep= [startDate(1),startDate(2)];
        endDateToKeep=[endDate(1),endDate(2)];
        creationDateToKeep=[creationDate(1),creationDate(2)];
        
    elseif (startDate(1) <= startDate(2)) && (endDate(1) > endDate(2))
        startDateToKeep= startDate(1);
        endDateToKeep=endDate(1);
        creationDateToKeep=creationDate(1);
    elseif (startDate(1) <= startDate(2)) && (endDate(1) == endDate(2))
        startDateToKeep= startDate(creationDate==max(creationDate));
        endDateToKeep=endDate(creationDate==max(creationDate));
        creationDateToKeep=max(creationDate);
        
    elseif (startDate(1) == startDate(2)) && (endDate(1) < endDate(2))
        startDateToKeep= startDate(2);
        endDateToKeep=endDate(2);
        creationDateToKeep=creationDate(2);
    end
    
elseif length(startDate)>2
    
    %% first test to find files with similar start and end dates. we only keep the most recent creation date
    for iiDate=1:length(startDate)
        test= (startDate(iiDate)== startDate & endDate(iiDate)==endDate);
        if sum(test)==1 && test(iiDate)==1
            conditionToRemove1(iiDate)=0;
        else
            if creationDate(iiDate)== max(creationDate(test))
                conditionToRemove1(iiDate)=0;
            else
                conditionToRemove1(iiDate)=1;
            end
        end
    end
    
    %% second test only indexes where conditionToRemove from the first test is == 0 to find files with similar startdate, but keep the latest enddate one
    for iiDate=1:length(startDate)
        test2=(startDate(iiDate) == startDate & endDate(iiDate)<endDate);
        if sum(test2)==1 && test2(iiDate)==1 %matchs its own dates
            %nothing
            conditionToRemove2(iiDate)=0;
        elseif  sum(test2)==1 && test2(iiDate)~=1 %matchs its own dates
            %nothing
            conditionToRemove2(iiDate)=1;
        elseif sum(test2)>1
            conditionToRemove2(iiDate)=1;
        else
            conditionToRemove2(iiDate)=0;
        end
        
    end
    
    conditionToRemove=conditionToRemove1 | conditionToRemove2;
    
    %% third test only indexes where conditionToRemove from conditionToRemove is == 0
    iiDateBis=1;
    for iiDate=1:length(startDate)
        if conditionToRemove(iiDate)==0
            test3=startDate(iiDate) >= startDate(~conditionToRemove) & endDate(iiDate)<=endDate(~conditionToRemove);
            
            if sum (test3)==1 && test3(iiDateBis)==1 %matchs its own dates
                %nothing
                conditionToRemove3(iiDate)=0;
            elseif sum (test3)==1 && test3(iiDateBis)~=1
                conditionToRemove3(iiDate)=1;
            elseif sum (test3)>1
                conditionToRemove3(iiDate)=1;
            else
                conditionToRemove3(iiDate)=0;
            end
            iiDateBis=iiDateBis+1;
        end
    end
    conditionToRemove=conditionToRemove | conditionToRemove3;
    
    
    if sum(conditionToRemove)==length(startDate)
        warning('MATLAB:BadAlgorithm','the number of files to delete is equal to the number of files given')
        startDateToKeep=startDate;
        endDateToKeep=endDate;
        creationDateToKeep=creationDate;
    else
        indexToKeep= ~conditionToRemove;
        startDateToKeep=startDate(indexToKeep);
        endDateToKeep=endDate(indexToKeep);
        creationDateToKeep=creationDate(indexToKeep);
    end
end
end
