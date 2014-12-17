function moveAggregatedFiles(soopSubFacility) %create one file per year
%moveAggregatedFiles
% Move the aggreated files to their respective folder on the DataFabric,
% following the rules set up in config.txt
% each file is also backed up and tar.gz in
% AGGREGATED_DATA_FOLDER/temp_archive
%
% Syntax:  moveAggregatedFiles(soopSubFacility)
%
% Inputs:
%
%
% Outputs:
%
%
% Example:
%    moveAggregatedFiles('soop_asf_mv')
%
%
% Other m-files required:readConfig
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also:
% readConfig,aggregateFiles,deleteSimilarSOOPFiles
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 18-Sept-2012

DF_ROOT= readConfig('df.path', 'config.txt','=');
AGGREGATED_DATA_FOLDER = readConfig('dataSoop.path', 'config.txt','=');
TEMPORARY_FOLDER=char(strcat(AGGREGATED_DATA_FOLDER,filesep,'DATA_FOLDER/temporary_',soopSubFacility,filesep,'aggregated_datasets'));
subFacility_Datafabric_path=[DF_ROOT filesep 'opendap' filesep readConfig([soopSubFacility '.DF.path'], 'config.txt','=')];


if exist(strcat(DF_ROOT,'/opendap'),'dir') == 7
    fprintf('%s - Data Fabric is connected\n',datestr(now))
    
    
    % "yes" if we use the same folder hierarchy as the one found
    % locally in [dataSoop.path] for each data set ( such as soop
    % asf which has a 'flux_product' and 'meteorological_sst_observations' folder.
    % "no" if we use the path defined by platform.[platformCode].path
    boolean= readConfig([soopSubFacility '.followLocalFolderStructure'], 'config.txt','=');
    
    % we list reccursively all the local files
    [~,~,ncFileList]=DIRR(strcat(TEMPORARY_FOLDER,filesep,'*.nc'),'name');
    ncFileList=ncFileList';
    [filepath, filename, ext]=cellfun(@fileparts, ncFileList, 'un',0);
    nNCFILE=length(ncFileList);
    
    if strfind(boolean,'yes')
        
        for iiFile=1:nNCFILE
            if strfind(ext{iiFile},'.nc')
                
%                 newPath=[subFacility_Datafabric_path filesep 'aggregated_datasets' filesep filepath{iiFile}(length(TEMPORARY_FOLDER)+2:end)  filesep  ];
              newPath=[subFacility_Datafabric_path filesep 'aggregated_datasets' filesep filepath{iiFile}(length(TEMPORARY_FOLDER)+2:end)    ];

                try
                    mkpath(newPath)
                catch
                    try
                        mkpath(newPath)
                    catch err
                        warning('Warning:mkpath','Device or resource busy')
                        %                         rethrow(err)
                        continue
                    end
                end
                
                
                commandStr=['gzip -c '  char(ncFileList(iiFile)) ' > ' strcat(char(ncFileList(iiFile)),'.gz') ];
                statusGzip=system(commandStr) ;
                statusGzip=~statusGzip;
                if statusGzip==1
                    delete( char(ncFileList(iiFile)))
                end
                
                [statusCopyToDF,~,~]=copyfile( strcat(char(ncFileList(iiFile)),'.gz'),char(newPath));
                
                if statusCopyToDF ==1
                    tempPath=[AGGREGATED_DATA_FOLDER filesep 'temp_archive',filesep readConfig([soopSubFacility '.DF.path'], 'config.txt','=') filesep 'aggregated_datasets' filesep filepath{iiFile}(length(TEMPORARY_FOLDER)+2:end)];
                    mkpath(char(tempPath))                
                    [statusCopyToTemp,~,~]=copyfile( strcat(char(ncFileList(iiFile)),'.gz'),char(tempPath));
                    
                    if statusCopyToTemp
                        delete( strcat(char(ncFileList(iiFile)),'.gz'));%we keep the files zipped in an archived folder in case the DF deletes suddenly everything. Files can be deleted here at any time by the user.
                    end
                    
                    fprintf('%s - SUCCESS: file "%s" has been copied to the Data Fabric\n',datestr(now),char(ncFileList(iiFile)))
                elseif statusCopyToDF ==0
                    fprintf('%s - ERROR: file "%s" has not been copied to the Data Fabric\n',datestr(now),char(ncFileList(iiFile)))
                end
                
                
                
%                 [status,~,~]=copyfile(ncFileList{iiFile},newPath);
%                 
%                 if status ==1
%                     %we keep a tar.gz archive locally
%                     
%                     mkpath(char(strcat(AGGREGATED_DATA_FOLDER,filesep,'temp_archive',filesep, filepath{iiFile}(length([AGGREGATED_DATA_FOLDER filesep 'DATA_FOLDER/'])+1:end))))
%                     commandStr=['gzip -c '  char(ncFileList{iiFile}) ' > ' strcat(AGGREGATED_DATA_FOLDER,filesep,'temp_archive',filesep, filepath{iiFile}(length([AGGREGATED_DATA_FOLDER filesep 'DATA_FOLDER/'])+1:end),filesep,char(filename{iiFile}),char(ext(iiFile)),'.gz') ];
%                     statusUnix=system(commandStr) ;
%                     if ~statusUnix
%                         delete(char(ncFileList{iiFile}));%we keep the files zipped in an archived folder in case the DF deletes suddenly everything. Files can be deleted here at any time by the user.
%                     end
%                     
%                     fprintf('%s - SUCCESS: file "%s" has been copied to the Data Fabric\n',datestr(now),char(ncFileList{iiFile}))
%                 elseif status ==0
%                     fprintf('%s - ERROR: file "%s" has not been copied to the Data Fabric\n',datestr(now),char(ncFileList{iiFile}))
%                 end
            end
        end
        
        
    elseif strfind(boolean,'no')
        
        for iiFile=1:nNCFILE
            if strfind(ext{iiFile},'.nc')
                clear gattval gattname
                B=cell2mat(regexp(filename(iiFile),'_[0-9]{8}T','once') );
                yearFile = (filename{iiFile}(B+1:B+4));
                
                % look for the platform code of the file in oder to get the good
                % folder name on the datafabric
                nc=netcdf.open(ncFileList{iiFile},'NC_NOWRITE');
                [gattname,gattval]=getGlobAttNC(nc);
                netcdf.close(nc);
                platform_code=gattval(strcmp('platform_code',gattname));
                platformFolder= readConfig(['platform.' char(platform_code) '.path'], 'config.txt','=');
                
                % create the path on the datafabric, and copy the file onto it
                newPath=[subFacility_Datafabric_path filesep 'aggregated_datasets' filesep platformFolder filesep yearFile ];
                

                
                try
                    mkpath(newPath)
                catch
                    try
                        mkpath(newPath)
                    catch err
                        warning('Warning:mkpath','Device or resource busy')
                        %                         rethrow(err)
                        continue
                    end
                end
                
%                 [status,~,~]=copyfile(ncFileList{iiFile},newPath);
%                 commandStr=['gzip -c '  char(ncFileList{iiFile}) ' > ' strcat(newPath,filesep,char(pathstr_NcFile(nnFiles)),'.nc.gz') ];              
                % commandStr=['gzip -c '  char(filesToMove(nnFiles)) ' > ' strcat(folderStationYearDF,filesep,char(nameFileToMove),char(extFileToMove),'.gz') ];
                
                commandStr=['gzip -c '  char(ncFileList(iiFile)) ' > ' strcat(char(ncFileList(iiFile)),'.gz') ];
                statusGzip=system(commandStr) ;
                statusGzip=~statusGzip;
                if statusGzip==1
                    delete( char(ncFileList(iiFile)))
                end
                
                [statusCopyToDF,~,~]=copyfile( strcat(char(ncFileList(iiFile)),'.gz'),char(newPath));
                
                if statusCopyToDF ==1
                    tempPath=[AGGREGATED_DATA_FOLDER filesep 'temp_archive' filesep readConfig([soopSubFacility '.DF.path'], 'config.txt','=') filesep 'aggregated_datasets' filesep platformFolder filesep yearFile ];
                    mkpath(char(tempPath))                
                    [statusCopyToTemp,~,~]=copyfile( strcat(char(ncFileList(iiFile)),'.gz'),char(tempPath));
                    
                    if statusCopyToTemp
                        delete( strcat(char(ncFileList(iiFile)),'.gz'));%we keep the files zipped in an archived folder in case the DF deletes suddenly everything. Files can be deleted here at any time by the user.
                    end
                    
                    fprintf('%s - SUCCESS: file "%s" has been copied to the Data Fabric\n',datestr(now),char(ncFileList(iiFile)))
                elseif statusCopyToDF ==0
                    fprintf('%s - ERROR: file "%s" has not been copied to the Data Fabric\n',datestr(now),char(ncFileList(iiFile)))
                end
                
%                 if status ==1
%                     %we keep a tar.gz archive locally
%                     mkpath(char(strcat(AGGREGATED_DATA_FOLDER,filesep,'temp_archive',filesep, filepath{iiFile}(length([AGGREGATED_DATA_FOLDER filesep 'DATA_FOLDER/'])+1:end))))
%                     commandStr=['gzip -c '  char(ncFileList{iiFile}) ' > ' strcat(AGGREGATED_DATA_FOLDER,filesep,'temp_archive',filesep, filepath{iiFile}(length([AGGREGATED_DATA_FOLDER filesep 'DATA_FOLDER/'])+1:end),filesep,char(filename{iiFile}),char(ext(iiFile)),'.gz') ];
%                     
%                     statusUnix=system(commandStr) ;
%                     if ~statusUnix
%                         delete(char(ncFileList{iiFile}));%we keep the files zipped in an archived folder in case the DF deletes suddenly everything. Files can be deleted here at any time by the user.
%                     end
%                     
%                     fprintf('%s - SUCCESS: file "%s" has been copied to the Data Fabric\n',datestr(now),char(ncFileList{iiFile}))
%                 elseif status ==0
%                     fprintf('%s - ERROR: file "%s" has not been copied to the Data Fabric\n',datestr(now),char(ncFileList{iiFile}))
%                 end
            end
        end
    else
        fprintf('%s - WARNING: Data Fabric is NOT connected\n',datestr(now))
    end
    
end
