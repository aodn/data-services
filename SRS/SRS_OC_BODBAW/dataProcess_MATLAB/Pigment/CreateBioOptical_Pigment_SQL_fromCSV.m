function CreateBioOptical_Pigment_SQL_fromCSV(DATA,METADATA,FileNameCSV,FileNameNC,folderHierarchy)
%% CreateBioOptical_Pigment_SQL_fromCSV
% this function creates the SQL script to load to the IMOS database in oder to
% populate the table used by geoserver
% Syntax:  [FileNameCSV,FileNameNC,folderHierarchy]=createPigmentFilename(DATA,METADATA)
%
% Inputs: DATA - structure created by Pigment_CSV_reader
%         METADATA - structure created by Pigment_CSV_reader
%         FileNameCSV   - filename for the CSV file
%         FileNameNC    - filename for the NetCDF file
%         folderHierarchy - folder structure hierarchy created by createPigmentFilename
%
% Outputs:
%        BioOptical_Deployments.sql in  'DataFileFolder'
%
% Example: 
%    [FileNameCSV,FileNameNC,folderHierarchy]=createPigmentFilename(DATA,METADATA)
%
% Other m-files
% required:
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also: Pigment_CSV_reader,CreateBioOptical_Pigment_NetCDF
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2011; Last revision: 28-Nov-2012
DataFileFolder=readConfig('data_pigment.path', 'config.txt','=');

AttNames=[METADATA.gAttName{:}]';
PlotFile=strcat(FileNameCSV{1}(1:end-3),'png');

TimeZoneIdx= strcmpi(AttNames, 'local_time_zone');
TimeZoneValue=str2double(char(METADATA.gAttVal{TimeZoneIdx}));
if isnan(TimeZoneValue)
    TimeZoneValue = 0;
end
    

abstractIdx= strcmpi(AttNames, 'abstract');
ABSTRACT=char(METADATA.gAttVal{abstractIdx});

sourceIdx= strcmpi(AttNames, 'source');
SOURCE=char(METADATA.gAttVal{sourceIdx});

cruiseidIdx= strcmpi(AttNames, 'cruise_id');
CRUISEid=(char(METADATA.gAttVal{cruiseidIdx}));


%% values to put in the psql script
Abstract4SQL=strcat(SOURCE,'. ',ABSTRACT);
FilepathCSV=strcat('public/SRS/BioOptical/',folderHierarchy);
datatype='pigment';
OpenDAP_link=strcat('/SRS/BioOptical/',folderHierarchy,filesep,FileNameNC);

%% load variables 
VariableNames=[DATA.VarName{:}]';
VariableNames=strrep(VariableNames,' ','_');

TimeIdx= strcmpi(VariableNames, 'time');
LatIdx= strcmpi(VariableNames, 'latitude');
LonIdx= strcmpi(VariableNames, 'longitude');

VariableNames{TimeIdx}='TIME';%rename in upper case
VariableNames{LatIdx}='LATITUDE';%rename in upper case
VariableNames{LonIdx}='LONGITUDE';%rename in upper case

TIME=datenum({DATA.Values{:,TimeIdx}}','yyyy-mm-ddTHH:MM:SS');
LAT=str2double({DATA.Values{:,LatIdx}}');
LON=str2double({DATA.Values{:,LonIdx}}');

% when accross the 180th meridian. We need to create an algorythm when the
% the track accrosses the 180th meridian. But because of the 0 and +180
% -180 values, it is necessary first to work on values  from 0 to 360. But
% on the SQL script, values will be from -180 to 180
newLON = LON+180;


% [LAT,ndx,~]=unique_no_sort(LAT);
% LON=LON(ndx);

TimeCoverageStart=strcat(datestr(min(TIME),'yyyy-mm-dd HH:MM:SS'),'+',num2str(TimeZoneValue));
TimeCoverageEnd=strcat(datestr(max(TIME),'yyyy-mm-dd HH:MM:SS'),'+',num2str(TimeZoneValue));


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
    
%     for k=2:length(LON)
%         if (LON(k-1) >= 0 && LON(k) <= 0) && ( LON(k) <=0 && LON(k) >= -180) && ( LON(k-1)<=180 && LON(k-1) >=0 ) && ((LON(k) - LON(k-1)) <=0) % crossing 180th meridian eastward. we divide the segment in 2
%             fprintf(fid_DB,',( %3.7f  %2.7f , 180  %2.7f ),(-180 %2.7f,  %3.7f %2.7f )',...
%                 LON(k-1), LAT(k-1),...
%                 (LAT(k-1)+LAT(k))/2,...
%                 (LAT(k-1)+LAT(k))/2,...
%                 LON(k), LAT(k));
%         elseif (LON(k-1) <= 0 && LON(k)>=0) && ( LON(k-1) <=0 && LON(k) >= -180) && ( LON(k)<=180 && LON(k) >=0 )   && ((LON(k) - LON(k-1)) >=0) % crossing 180th meridian westward. we divide the segment in 2
%             fprintf(fid_DB,',( %3.7f  %2.7f , -180  %2.7f ),(+180 %2.7f,  %3.7f %2.7f )',...
%                 LON(k-1), LAT(k-1),...
%                 (LAT(k-1)+LAT(k))/2,...
%                 (LAT(k-1)+LAT(k))/2,...
%                 LON(k), LAT(k));
%         else %no problem
%             fprintf(fid_DB,',( %3.7f  %2.7f,%3.7f  %2.7f )',...
%                 LON(k-1), LAT(k-1),...
%                 LON(k), LAT(k));
%         end
%     end

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
    fprintf(fid_DB,'VALUES ( nextval(''bio_optical.deployments_pkid_seq''),''%s\'',''%s\'' , ''%s\'' , ''%s\'' , ''%s\'',''%s\'' , ''%s\'', ''%s\'' ,''%s\'' ,PointFromText(''POINT( ',datatype,CRUISEid,FilepathCSV,FileNameCSV,PlotFile,OpenDAP_link,TimeCoverageStart,TimeCoverageEnd,Abstract4SQL);
    fprintf(fid_DB,'  %3.7f %2.7f)'',4326)); \n',LON(end),LAT(end));
end
fprintf(fid_DB,'COMMIT;\n');
fclose(fid_DB);
end
