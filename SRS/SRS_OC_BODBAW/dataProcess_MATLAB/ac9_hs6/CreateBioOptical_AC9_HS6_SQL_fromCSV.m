function CreateBioOptical_AC9_HS6_SQL_fromCSV(DATA,METADATA,FileNameCSV,FileNameNC,folderHierarchy)
%% CreateBioOptical_AC9_HS6_SQL_fromCSV
% this function creates the SQL script to load to the IMOS database in oder to
% populate the table used by geoserver
% Syntax:  [FileNameCSV,FileNameNC,folderHierarchy]=createAC9_HS6Filename(DATA,METADATA)
%
% Inputs: DATA - structure created by AC9_HS6_CSV_reader
%         METADATA - structure created by AC9_HS6_CSV_reader
%         FileNameCSV   - filename for the CSV file
%         FileNameNC    - filename for the NetCDF file
%         folderHierarchy - folder structure hierarchy created by createAC9_HS6Filename
%
% Outputs:
%        BioOptical_Deployments.sql in  'DataFileFolder'
%
% Example: 
%    [FileNameCSV,FileNameNC,folderHierarchy]=createAC9_HS6Filename(DATA,METADATA)
%
% Other m-files
% required:
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also: AC9_HS6_CSV_reader,CreateBioOptical_AC9_HS6_NetCDF
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2011; Last revision: 28-Nov-2012
DataFileFolder=readConfig('data_ac9_hs6.path', 'config.txt','=');
% [FileNameCSV,FileNameNC,folderHierarchy]=createAC9_HS6Filename(DATA,METADATA);
AttNames=[METADATA.gAttName{:}]';

% [CSVpath,CSVfileName]=fileparts(CSVFile);
% IndexCreation=strfind(CSVfileName,'_C-');
% fileNameXLS=strcat(CSVfileName(1:IndexCreation-1),'.csv');
PlotFile=strcat(FileNameCSV{1}(1:end-3),'png');
% PlotFile=strcat(FileNameCSV,'.png');
% CSVfileName=strcat(CSVfileName,'.nc');

% nc = netcdf.open(CSVfile,'CSV_NOWRITE');

% TimeZoneValue= num2str( netcdf.getAtt(nc,netcdf.getConstant('CSV_GLOBAL'),'local_time_zone'));
TimeZoneIdx= strcmpi(AttNames, 'local_time_zone');
TimeZoneValue=str2double(char(METADATA.gAttVal{TimeZoneIdx}));

abstractIdx= strcmpi(AttNames, 'abstract');
ABSTRACT=char(METADATA.gAttVal{abstractIdx});

sourceIdx= strcmpi(AttNames, 'source');
SOURCE=char(METADATA.gAttVal{sourceIdx});

cruiseidIdx= strcmpi(AttNames, 'cruise_id');
CRUISEid=(char(METADATA.gAttVal{cruiseidIdx}));


%% values to put in the psql script
% ABSTRACT=netcdf.getAtt(nc,netcdf.getConstant('CSV_GLOBAL'),'abstract');
% SOURCE=netcdf.getAtt(nc,netcdf.getConstant('CSV_GLOBAL'),'source');
% CRUISEid=netcdf.getAtt(nc,netcdf.getConstant('CSV_GLOBAL'),'cruise_id');
Abstract4SQL=strcat(SOURCE,'. ',ABSTRACT);
% folderHierachy=CSVpath(strfind(CSVpath,'/NetCDF/'):end);
FilepathCSV=strcat('public/SRS/BioOptical/',folderHierarchy);
datatype='AC9_HS6';
OpenDAP_link=strcat('/SRS/BioOptical/',folderHierarchy,filesep,FileNameNC);

%% load variables _Column
VariableNames_Column=[DATA.VarName_Column{:}]';
VariableNames_Column=strrep(VariableNames_Column,' ','_');

TimeIdx= strcmpi(VariableNames_Column, 'time');
LatIdx= strcmpi(VariableNames_Column, 'latitude');
LonIdx= strcmpi(VariableNames_Column, 'longitude');

VariableNames_Column{TimeIdx}='TIME';%rename in upper case
VariableNames_Column{LatIdx}='LATITUDE';%rename in upper case
VariableNames_Column{LonIdx}='LONGITUDE';%rename in upper case

TIME=datenum({DATA.Values_Column{:,TimeIdx}},'yyyy-mm-ddTHH:MM:SS');
LAT=str2double({DATA.Values_Column{:,LatIdx}});
LON=str2double({DATA.Values_Column{:,LonIdx}});
% [LAT,ndx,~]=unique_no_sort(LAT);
% LON=LON(ndx);
% when accross the 180th meridian. We need to create an algorythm when the
% the track accrosses the 180th meridian. But because of the 0 and +180
% -180 values, it is necessary first to work on values  from 0 to 360. But
% on the SQL script, values will be from -180 to 180
newLON = LON+180;

TimeCoverageStart=strcat(datestr(min(TIME),'yyyy-mm-dd HH:MM:SS'),'+',num2str(TimeZoneValue));
TimeCoverageEnd=strcat(datestr(max(TIME),'yyyy-mm-dd HH:MM:SS'),'+',num2str(TimeZoneValue));

%

%% writting values
Filename_DB=fullfile(DataFileFolder,filesep,'BioOptical_Deployments.sql');
fid_DB = fopen(Filename_DB, 'a+');

fprintf(fid_DB,'BEGIN;\n');
fprintf(fid_DB,'INSERT INTO bio_optical.deployments (pkid,data_type,deployment_id,filepath,filename,plot,opendap_url,time_coverage_start,time_coverage_end,abstract,geom)\n');
if length(LAT)>1 % LineFromText
%     fprintf(fid_DB,'VALUES ( nextval(''bio_optical.deployments_pkid_seq''),''%s\'',''%s\'' , ''%s\'' , ''%s\'' , ''%s\'',''%s\'' , ''%s\'', ''%s\'' ,''%s\'' ,LineFromText(''LINESTRING( ',datatype,CRUISEid,FilepathCSV,char(FileNameCSV),PlotFile,char(OpenDAP_link),TimeCoverageStart,TimeCoverageEnd,Abstract4SQL);
%     %geom
%     for k=1:length(LAT)-1
%         fprintf(fid_DB,'  %3.7f %2.7f ,',LON(k),LAT(k));
%     end
%     fprintf(fid_DB,'  %3.7f %2.7f)'',4326)); \n',LON(end),LAT(end));
%     

    fprintf(fid_DB,'VALUES ( nextval(''bio_optical.deployments_pkid_seq''),''%s\'',''%s\'' , ''%s\'' , ''%s\'' , ''%s\'',''%s\'' , ''%s\'', ''%s\'' ,''%s\'' ,GeomFromText(''MULTILINESTRING( ',datatype,CRUISEid,FilepathCSV,char(FileNameCSV),PlotFile,char(OpenDAP_link),TimeCoverageStart,TimeCoverageEnd,Abstract4SQL);
    k = 1;
    fprintf(fid_DB,'( %3.7f  %2.7f,%3.7f  %2.7f )',...
        LON(k), LAT(k),...
        LON(k+1), LAT(k+1));
    
    for k=2:length(LON)
        if (newLON(k) <= 180 && newLON(k-1) >= 180) && ( (newLON(k) - newLON(k-1)) <= 180) % crossing 180th meridian eastward. we divide the segment in 2
            fprintf(fid_DB,',( %3.7f  %2.7f , 180  %2.7f ),(-180 %2.7f,  %3.7f %2.7f )',...
                LON(k-1), LAT(k-1),...
                (LAT(k-1)+LAT(k))/2,...
                (LAT(k-1)+LAT(k))/2,...
                LON(k), LAT(k));
        elseif (newLON(k-1) <= 180 && newLON(k) >= 180) && ( (newLON(k) - newLON(k-1)) <= 0) % crossing 180th meridian westward. we divide the segment in 2
            fprintf(fid_DB,',( %3.7f  %2.7f , -180  %2.7f ),(+180 %2.7f,  %3.7f %2.7f )',...
                LON(k-1), LAT(k-1),...
                (LAT(k-1)+LAT(k))/2,...
                (LAT(k-1)+LAT(k))/2,...
                LON(k), LAT(k));
        else %no problem
            fprintf(fid_DB,',( %3.7f  %2.7f,%3.7f  %2.7f )',...
                LON(k-1), LAT(k-1),...
                LON(k), LAT(k));
        end
    end
    
    fprintf(fid_DB,')'',4326)); \n');


else %PointFromText
    fprintf(fid_DB,'VALUES ( nextval(''bio_optical.deployments_pkid_seq''),''%s\'',''%s\'' , ''%s\'' , ''%s\'' , ''%s\'',''%s\'' , ''%s\'', ''%s\'' ,''%s\'' ,PointFromText(''POINT( ',datatype,CRUISEid,FilepathCSV,char(FileNameCSV),PlotFile,char(OpenDAP_link),TimeCoverageStart,TimeCoverageEnd,Abstract4SQL);
    fprintf(fid_DB,'  %3.7f %2.7f)'',4326)); \n',LON(end),LAT(end));
end
fprintf(fid_DB,'COMMIT;\n');
fclose(fid_DB);
end
