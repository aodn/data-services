function performAggregationFromList(fileList,acornStation)
%% performAggregationFromList
% Create an aggregated file from fileList. a java application to call
% toolsui.jar has been coded
% the aggregated file is copied in :
% [table_name]/aggregated/[callsign]/[year]
% or
% [table_name]/aggregated/[OpenDAP_subfolders]/[year]
% if the aggregation succeed, a mat file alreadyAggregated.mat is updated
% in order to know which file/dataset has already been used. Then all the
% files used (NCML and NetCDF) are deleted from the working directory.
% we call checkVariableName(fileList) to check all the variables have the
% same name on all the NetCDF files
%
% Syntax:  performAggregationFromList
%
% Inputs:   fileList    :list of files to aggregate together
%           acornStation: station to aggregate
%
% Outputs:
%
%
% Example:
%    performAggregationFromList
%
%
% Other m-files required:readConfig
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also:
% checkVariableName,Aggregate_ACORN,readConfig,aggregateFiles,checkVariableName
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% June 2012; Last revision: 24-Aug-2012

global TEMPORARY_FOLDER;
global CREATION_DATE;
global SCRIPT_FOLDER;

aggregationType=readConfig('aggregationType', 'config.txt','=');


format long

if exist(fullfile(TEMPORARY_FOLDER,'alreadyAggregated.mat'),'file')
    load (fullfile(TEMPORARY_FOLDER,'alreadyAggregated.mat'));
else
    fileAlreadyUsed=cell(1,1);
end

fileList=fileList(~cellfun('isempty',fileList));% we empty the list of empty entries
[fileList]=checkVariableName(fileList);
fileList=fileList(~cellfun('isempty',fileList));% we empty the list of empty entries

%% read first NC file
nc = netcdf.open(fileList{1},'NC_NOWRITE');

%% list all the Variables from it
[allVarnames,~]=listVarNC(nc);

%% we grab the date dimension
[~,strOffset,~,~]= getTimeOffsetNC(nc,allVarnames);

%% temporary filenames
inputNCML='inputNCML.ncml';
outputNETCDF='output.nc';

%% check TIME varname
idxTIME= strcmpi(allVarnames,'TIME')==1;
TimeVarName=allVarnames{idxTIME};

%% write NCML file
% change some attributes
titleNetCDF=readConfig(strcat('gAttTitle.',acornStation,'.',aggregationType), 'config.txt','=');
abstractNetCDF=readConfig(strcat('gAttAbstract.',acornStation,'.',aggregationType),'config.txt','=');


ncmlFile=fullfile(TEMPORARY_FOLDER,inputNCML);
ncmlFile_fid = fopen(ncmlFile, 'w+');
fprintf(ncmlFile_fid,'<netcdf xmlns="http://www.unidata.ucar.edu/namespaces/netcdf/ncml-2.2">\n');
% change time attribute because the letter T should not be present.No CF
% and bugs some softwares
fprintf(ncmlFile_fid,strcat(' <variable name="',TimeVarName,'" shape="',TimeVarName,'" type="double"> \n'));
fprintf(ncmlFile_fid,'    <attribute name="units" value="%s" /> \n',strOffset);
fprintf(ncmlFile_fid,' </variable> \n');

%% change QC var into Bytes and not double !!
idxQC= ~cellfun('isempty',(regexp(allVarnames,'_quality_control')));
qcVarName=allVarnames(idxQC);
nQCVAR=length(qcVarName);
for jqcVar=1:nQCVAR
    fprintf(ncmlFile_fid,strcat(' <variable name="',qcVarName{jqcVar},'" type="byte"> \n'));
    fprintf(ncmlFile_fid,strcat('		<attribute name="quality_control_set" type="byte"/>\n'));
    fprintf(ncmlFile_fid,strcat('		<attribute name="_FillValue" type="byte" value="-128" />\n'));
    fprintf(ncmlFile_fid,strcat('		<attribute name="valid_min" type="byte" value="0" />\n'));
    fprintf(ncmlFile_fid,strcat('		<attribute name="valid_max" type="byte" value="9" />\n'));
    fprintf(ncmlFile_fid,strcat('		<attribute name="flag_values" type="byte" value="0 1 2 3 4 5 6 7 8 9" />\n'));
    fprintf(ncmlFile_fid,' </variable> \n');
end


fprintf(ncmlFile_fid,strcat(' <aggregation dimName="',TimeVarName,'" type="joinExisting"> \n'));


% if we want to scan a folder
% fprintf(ncmlFile_fid,'<scan location="/home/lbesnard/Desktop/AggregationProject/temporary/9HA2479/2010/" suffix=".nc" subdirs="true"/>\n');

nFilelist=length(fileList);
for jjFiles=1:nFilelist
    fprintf(ncmlFile_fid,'  <netcdf location="file:%s" /> \n',fileList{jjFiles}); %add all the nc files from the list
end
fprintf(ncmlFile_fid,' </aggregation> \n');

% change some attributes
fprintf(ncmlFile_fid,' <attribute name="institution" value="%s" />\n',readConfig('gAttVal.institution','config.txt','='));
fprintf(ncmlFile_fid,' <attribute name="title" value="%s" />\n',titleNetCDF);
fprintf(ncmlFile_fid,' <attribute name="abstract" value="%s" />\n',abstractNetCDF);
fprintf(ncmlFile_fid,' <attribute name="data_center" value="%s" />\n',readConfig('gAttVal.data_center','config.txt','='));
fprintf(ncmlFile_fid,' <attribute name="author" value="%s" />\n',readConfig('gAttVal.author_name','config.txt','='));
fprintf(ncmlFile_fid,' <attribute name="author_email" value="%s" />\n',readConfig('gAttVal.author_email','config.txt','='));
fprintf(ncmlFile_fid,'</netcdf> \n');
fclose(ncmlFile_fid);

%% write NetCDF from NCML, java code
write_NC_Command=sprintf('%s -classpath ".:%s/myJavaClasses/toolsUI-4.2.jar"  AggregateNcML %s %s',readConfig('java.path', 'config.txt','='),SCRIPT_FOLDER,ncmlFile,fullfile(TEMPORARY_FOLDER,outputNETCDF));
% [~,~] = unix(write_NC_Command,'-echo');%displays the results in the Command Window as it executes

[status,result] = unix(write_NC_Command);


if status ==0 % 0 is success , 1 is not , pretty weird matlab standard
    %% modify attributes of the new created outputNETCDF file, change the filename
    ncAggregated = netcdf.open(fullfile(TEMPORARY_FOLDER,outputNETCDF),'NC_WRITE');
    [allVarnames,~]=listVarNC(ncAggregated);
    [gattnameOld,gattvalOld]=getGlobAttNC(ncAggregated);
    
    
    %% Create a NEW netCDF filename.
    [~,name]=fileparts(fileList{1}); % load the name of the first NC used.This should be a good reference
    
    FacilityPrefixe=name(1:regexp(name,'_[\d]{8}(?-i)T','start','once')-1);%locate the dateStart string
    % platform_code=gattvalOld{strcmpi(gattnameOld,'site_code')};
    platform_code=char(acornStation);
    switch aggregationType
        case 'month'
            IMOS_NAME_freePartCode=strcat(platform_code(1:3),'_FV00_monthly-1-hour-avg');
        case 'year'
            IMOS_NAME_freePartCode=strcat(platform_code(1:3),'_FV00_yearly-1-hour-avg');
    end
    
    [numOffset,~,FirstDate,LastDate]= getTimeOffsetNC(ncAggregated,allVarnames);
    
    
    FirstDatestr=datestr(FirstDate,'yyyymmddTHHMMSSZ');
    LastDatestr=datestr(LastDate,'yyyymmddTHHMMSSZ');
    
    modifiedFileName=strcat(FacilityPrefixe,'_',FirstDatestr,...
        '_',IMOS_NAME_freePartCode,'_',...
        'END-',LastDatestr,...
        '_C-',CREATION_DATE,'.nc');
    
    
    %% Get Data to fill global attributes
    LAT=getVarNC('latitude',allVarnames,ncAggregated);
    LON=getVarNC('longitude',allVarnames,ncAggregated);
    
    %% change these following attributes into numbers and not char
    %% Creation of global attributes
    gattname{1}='Conventions';
    gattval{1}=readConfig('gAttVal.conventions', 'config.txt','=');
    
    gattname{2}='date_created';
    gattval{2}=datestr(now,'yyyy-mm-ddTHH:MM:SSZ') ;
    
    gattname{3}='date_modified';
    gattval{3}=datestr(now,'yyyy-mm-ddTHH:MM:SSZ') ;
    
    gattname{4}='netcdf_version';
    gattval{4}=readConfig('gAttVal.netcdf_version', 'config.txt','=');
    
    gattname{5}='geospatial_lat_min';
    gattval{5}=min(LAT);
    
    gattname{6}='geospatial_lat_max';
    gattval{6}=max(LAT);
    
    gattname{7}='geospatial_lon_min';
    gattval{7}=min(LON);
    
    gattname{8}='geospatial_lon_max';
    gattval{8}=max(LON);
    
    gattname{9}='time_coverage_start';
    gattval{9}=datestr(FirstDate,'yyyy-mm-ddTHH:MM:SSZ') ;
    
    gattname{10}='time_coverage_end';
    gattval{10}=datestr(LastDate,'yyyy-mm-ddTHH:MM:SSZ') ;
    
    gattname{11}='featureType';
    gattval{11}=readConfig('gAttVal.featureType', 'config.txt','=');
    
    gattname{12}='author';
    gattval{12}=readConfig('gAttVal.author_name', 'config.txt','=');
    
    gattname{13}='author_email';
    gattval{13}=readConfig('gAttVal.author_email', 'config.txt','=');
    
    gattname{14}='naming_authority';
    gattval{14}=readConfig('gAttVal.naming_authority', 'config.txt','=');
    
    gattname{15}='data_center_email';
    gattval{15}=readConfig('gAttVal.data_center_email', 'config.txt','=');
    
    gattname{16}='naming_authority';
    gattval{16}=readConfig('gAttVal.naming_authority', 'config.txt','=');
    
    gattname{17}='distribution_statement';
    gattval{17}=readConfig('gAttVal.distribution_statement', 'config.txt','=');
    
    gattname{18}='citation';
    gattval{18}=readConfig('gAttVal.citation', 'config.txt','=');
    
    gattname{19}='acknowledgement';
    gattval{19}=readConfig('gAttVal.acknowledgement', 'config.txt','=');
    
    %% add global att in NC file
    netcdf.reDef(ncAggregated);
    for uu=1:length(gattname)
        netcdf.putAtt(ncAggregated,netcdf.getConstant('GLOBAL'),gattname{uu}, gattval{uu});
    end
    
    netcdf.close(ncAggregated);
    netcdf.close(nc);
    
    %% add modification to filename
    % C=regexp(fileList{1},strcat(filesep,platform_code,'.*?/.*?'),'once');
    % D=regexp(fileList{1},strcat(filesep,FacilityPrefixe),'once');
    % pathFile= fileList{1}(C+1:D-1);%locate the dateStart string
    
    
    aggregatedStationFolder=strcat(TEMPORARY_FOLDER,filesep,'aggregated_datasets');
    mkpath(aggregatedStationFolder)
    
    movefile(fullfile(TEMPORARY_FOLDER,outputNETCDF),fullfile(aggregatedStationFolder,filesep,modifiedFileName))
    delete(ncmlFile)
    
    %% save in a local mat file which files have already been used
    if ~cellfun('isempty',fileAlreadyUsed)
        nFilesAlreadyUsed=length(fileAlreadyUsed);
    else
        nFilesAlreadyUsed=0;
    end
    [filepath, name,ext]=cellfun(@fileparts, fileList, 'un',0);
    
    fileAlreadyUsed(nFilesAlreadyUsed+1:nFilesAlreadyUsed+length(fileList))=name;
    [b,~]=uunique(fileAlreadyUsed);
    clear fileAlreadyUsed
    fileAlreadyUsed=b;
    
    save(fullfile(TEMPORARY_FOLDER,'alreadyAggregated.mat'), '-regexp','fileAlreadyUsed','-v6') %v6 version suppose to be faster
    
    %% we delete the files from filelist
    warning off all;% if files don't exist, it's not a problem
    for iiFile=1:nFilelist
        %     if exist(char(fileList(iiFile)),'file')==2 % checking takes too much time
        delete(char(fileList(iiFile))); %ncml +nc
        %     end
        
        %     if exist(char(strcat(filepath(iiFile),filesep,name(iiFile),'.nc')),'file')==2 % checking takes too much time
        delete(char(strcat(filepath(iiFile),filesep,name(iiFile),'.nc'))); %duplicate nc
        %     end
    end
else
    fprintf('%s - ERROR: JAVA problem. Aggregation could not be performed on data set and similars: "%s".\n Java Message:\n %s\n',datestr(now),char(fileList(1)),result)
    
    
end

end

