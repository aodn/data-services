function deleteFileFromDB(acornStation,DateToDelete)
%deleteFileFromDB
% delete the filenames from the database for a given date DateToDelete.
% This help to reprocess easily files.
%
% Syntax:  deleteFileFromDB(acornStation,DateToDelete)
%
% Inputs:
%
%
% Outputs:
%
%
% Example:
%         deleteFileFromDB('ROT',[2012 07])
%         DateToDelete=[2012 07 1]
%         DateToDelete=[2012 08 ]
%         DateToDelete=[2012 ]
%         deleteFileFromDB('SAG',[2012 07])
%         deleteFileFromDB('SAG',[2012 08])
%         deleteFileFromDB('SAG',[2012 09])
% 
%         deleteFileFromDB('ROT',[2012 07])
%         deleteFileFromDB('ROT',[2012 08])
%         deleteFileFromDB('ROT',[2012 09])
% 
% 
%         deleteFileFromDB('CBG',[2012 06])
%         deleteFileFromDB('CBG',[2012 07])
%         deleteFileFromDB('CBG',[2012 08])
%         deleteFileFromDB('CBG',[2012 09])
% 
% 
%         deleteFileFromDB('COF',[2012 07])
%         deleteFileFromDB('COF',[2012 08])
%         deleteFileFromDB('COF',[2012 09])
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
%

global AGGREGATED_DATA_FOLDER;

TEMPORARY_FOLDER=char(strcat(AGGREGATED_DATA_FOLDER,filesep,'DATA_FOLDER/temporary_',acornStation));

if size(DateToDelete,2) ==3 % we delete all files belonging to one day
    dateRange=datestr(datenum(DateToDelete),'yyyymmdd');
    
elseif  size(DateToDelete,2) ==2 % we delete all files belonging to one month
    dateRange=datestr([DateToDelete, 1,0,0,0],'yyyymm');
    
elseif  size(DateToDelete,2) ==1 % we delete all files belonging to one year
    dateRange=datestr([DateToDelete,1, 1,0,0,0],'yyyy');
end

if exist(fullfile(TEMPORARY_FOLDER,'alreadyAggregated.mat'),'file')
    load (fullfile(TEMPORARY_FOLDER,'alreadyAggregated.mat'))

    [~, s, ~] =regexp(fileAlreadyUsed,['IMOS_ACORN_V_' dateRange '\w*' acornStation  '\w*' ],'match', 'start', 'end');
    s=~cellfun('isempty',s)';
    fileAlreadyUsed(s)=[];
    
    save(fullfile(TEMPORARY_FOLDER,'alreadyAggregated.mat'), '-regexp','fileAlreadyUsed','-v6') %v6 version suppose to be faster
end