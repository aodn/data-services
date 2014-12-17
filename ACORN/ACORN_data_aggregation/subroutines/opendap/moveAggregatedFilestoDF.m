function moveAggregatedFilestoDF(acornStation)
%% moveAggregatedFilestoDF
% This function moves the aggreated files to their respective folder on the
% DataFabric.
% Each file is also backed up and tar.gz in
% AGGREGATED_DATA_FOLDER/temp_archive/[acornStation]/[year]
%
% Syntax:  moveAggregatedFilestoDF(acornStation)
%
% Inputs:  acornStation : string of the station code
%
%
% Outputs:
%
%
% Example:
%    moveAggregatedFilestoDF('ROT')
%
%
% Other m-files required:readConfig
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also:
% readConfig,aggregateFiles,Aggregate_ACORN,moveAggregatedFilestoDF,deleteSimilarFiles
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 10-Sept-2012

DF_ROOT=readConfig('df.path', 'config.txt','=');
ACORN_opendapFolder=readConfig('df.acornAggregation.path', 'config.txt','=');

AGGREGATED_DATA_FOLDER = readConfig('dataACORN.path', 'config.txt','=');
TEMPORARY_FOLDER=char(strcat(AGGREGATED_DATA_FOLDER,filesep,'DATA_FOLDER/temporary_',acornStation));


if exist(strcat(DF_ROOT,'/opendap'),'dir') == 7
    fprintf('%s - Data Fabric is connected, SWEET ;) : We are copying aggregated files to it\n',datestr(now))
    datafabricACORNFolder=(strcat(DF_ROOT,ACORN_opendapFolder,'/'));
    %     mkpath(datafabricACORNFolder);
    
    stationLocalFolder=strcat(TEMPORARY_FOLDER,filesep,'aggregated_datasets');
    ncFilesAggregated=DIRR(stationLocalFolder,'name','.nc','isdir','0','bytes','>1000');%bytes to remove ncml files
    
    if ~isempty(ncFilesAggregated)
        ncFiles=strcat(stationLocalFolder,filesep,({ncFilesAggregated.name})');
        % [subFolder]=listSubDir(stationLocalFolder);
        %         A=cell2mat(regexp(ncFiles(1),'_[0-9]{8}T','once') ); %8 digits yyyymmdd. we assume all the files have the same year within one folder
        %         yearVar=str2double( ncFiles{1}(A+1:A+4));
        %         clear A
        [filepath, filename, ext]=cellfun(@fileparts, ncFiles, 'un',0);
        B=cell2mat(regexp(filename,'_[0-9]{8}T','once') );
        
        yearFile = str2double(cellfun(@(x) x(B+1:B+4),filename,'UniformOutput',0));
        
        [uniqueYear,~,~]=uunique(yearFile);
        
        nYear=length(uniqueYear);
        for iiYear=1:nYear
            indexFilesToMove=(yearFile==uniqueYear(iiYear));
            
            filesToMove=strcat(filepath(indexFilesToMove),filesep,...
                filename(indexFilesToMove),ext(indexFilesToMove));
            
            for nnFiles=1:length(filesToMove)
                folderStationYearDF=strcat(datafabricACORNFolder,acornStation,filesep,num2str(uniqueYear(iiYear)));
                mkpath(char(folderStationYearDF))
                %                 [status,~,~]=copyfile( char(filesToMove(nnFiles)),char(folderStationYearDF));
                
%                 [originalPathFileToMove, nameFileToMove, extFileToMove]= fileparts(char(filesToMove(nnFiles)));
                commandStr=['gzip -c '  char(filesToMove(nnFiles)) ' > ' strcat(char(filesToMove(nnFiles)),'.gz') ];
                
                %                 commandStr=['gzip -c '  char(filesToMove(nnFiles)) ' > ' strcat(folderStationYearDF,filesep,char(nameFileToMove),char(extFileToMove),'.gz') ];
                statusGzip=system(commandStr) ;
                statusGzip=~statusGzip;
                if statusGzip==1
                    delete( char(filesToMove(nnFiles)))
                end
                
                [statusCopyToDF,~,~]=copyfile( strcat(char(filesToMove(nnFiles)),'.gz'),char(folderStationYearDF));
                
                if statusCopyToDF ==1
                    mkpath(char(strcat(AGGREGATED_DATA_FOLDER,filesep,'temp_archive',filesep,acornStation,filesep,num2str(uniqueYear(iiYear)))))
                    %                     commandStr=['gzip -c '  char(filesToMove(nnFiles)) ' > ' strcat(AGGREGATED_DATA_FOLDER,filesep,'temp_archive',filesep,acornStation,filesep,num2str(uniqueYear(iiYear)),filesep,char(nameFileToMove),char(extFileToMove),'.gz') ];
                    %                     statusUnix=system(commandStr) ;
                    [statusCopyToTemp,~,~]=copyfile( strcat(char(filesToMove(nnFiles)),'.gz'),strcat(AGGREGATED_DATA_FOLDER,filesep,'temp_archive',filesep,acornStation,filesep,num2str(uniqueYear(iiYear))));
                    
                    if statusCopyToTemp
                        delete( strcat(char(filesToMove(nnFiles)),'.gz'));%we keep the files zipped in an archived folder in case the DF deletes suddenly everything. Files can be deleted here at any time by the user.
                    end
                    
                    fprintf('%s - SUCCESS: file "%s" has been copied to the Data Fabric\n',datestr(now),char(filesToMove(nnFiles)))
                elseif statusCopyToDF ==0
                    fprintf('%s - ERROR: file "%s" has not been copied to the Data Fabric\n',datestr(now),char(filesToMove(nnFiles)))
                end
            end
            
            clear filesToMove
        end
        
        clear uniqueYear m n B yearVar A filepath  filename  ext
    else
        fprintf('%s - No file to move to the DataFabric\n',datestr(now))
        
    end
    
else
    fprintf('%s - ERROR: Data Fabric is NOT connected, BUGGER |-( : Files will be copied next time\n',datestr(now))
end