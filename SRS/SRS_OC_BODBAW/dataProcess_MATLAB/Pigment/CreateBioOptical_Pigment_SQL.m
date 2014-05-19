function CreateBioOptical_Pigment_SQL(NCfile)
global DataFileFolder

[NCpath,NCfileName]=fileparts(NCfile);
IndexCreation=strfind(NCfileName,'_C-');
fileNameXLS=strcat(NCfileName(1:IndexCreation-1),'.csv');
% PlotFile=strcat(NCfileName(1:IndexCreation-1),'.png');
PlotFile=strcat(NCfileName,'.png');
NCfileName=strcat(NCfileName,'.nc');

nc = netcdf.open(NCfile,'NC_NOWRITE');

TimeZoneValue= num2str( netcdf.getAtt(nc,netcdf.getConstant('NC_GLOBAL'),'local_time_zone'));

[allVarnames,~]=listVarNC(nc);
LAT=getVarNC('latitude',allVarnames,nc);
LON=getVarNC('longitude',allVarnames,nc);
TIME=getVarNC('time',allVarnames,nc);

[numOffset,~,~,~]= getTimeOffsetNC(nc,allVarnames);
TIME=double(numOffset+TIME);

TimeCoverageStart=strcat(datestr(min(TIME),'yyyy-mm-dd HH:MM:SS'),'+',TimeZoneValue);
TimeCoverageEnd=strcat(datestr(max(TIME),'yyyy-mm-dd HH:MM:SS'),'+',TimeZoneValue);

%% values to put in the psql script
ABSTRACT=netcdf.getAtt(nc,netcdf.getConstant('NC_GLOBAL'),'abstract');
SOURCE=netcdf.getAtt(nc,netcdf.getConstant('NC_GLOBAL'),'source');
CRUISEid=netcdf.getAtt(nc,netcdf.getConstant('NC_GLOBAL'),'cruise_id');
Abstract4SQL=strcat(SOURCE,'. ',ABSTRACT);
folderHierachy=NCpath(strfind(NCpath,'/NetCDF/'):end);
FilepathCSV=strcat('public/SRS/BioOptical',folderHierachy);
datatype='pigment';
OpenDAP_link=strcat('/SRS/BioOptical',folderHierachy,filesep,NCfileName);

%% writting values
Filename_DB=fullfile(DataFileFolder,'BioOptical_Deployments.sql');
fid_DB = fopen(Filename_DB, 'a+');

% fprintf(fid_DB,'BEGIN;\n');
fprintf(fid_DB,'INSERT INTO bio_optical.deployments (pkid,data_type,deployment_id,filepath,filename,plot,opendap_url,time_coverage_start,time_coverage_end,abstract,geom)\n');
if length(LAT)>1 % LineFromText
    fprintf(fid_DB,'VALUES ( nextval(''bio_optical.deployments_pkid_seq''),''%s\'',''%s\'' , ''%s\'' , ''%s\'' , ''%s\'',''%s\'' , ''%s\'', ''%s\'' ,''%s\'' ,LineFromText(''LINESTRING( ',datatype,CRUISEid,FilepathCSV,fileNameXLS,PlotFile,OpenDAP_link,TimeCoverageStart,TimeCoverageEnd,Abstract4SQL);
    %geom
    for k=1:length(LAT)-1
        fprintf(fid_DB,'  %3.7f %2.7f ,',LON(k),LAT(k));
    end
    fprintf(fid_DB,'  %3.7f %2.7f)'',4326)); \n',LON(end),LAT(end));
    
else %PointFromText
    fprintf(fid_DB,'VALUES ( nextval(''bio_optical.deployments_pkid_seq''),''%s\'',''%s\'' , ''%s\'' , ''%s\'' , ''%s\'',''%s\'' , ''%s\'', ''%s\'' ,''%s\'' ,PointFromText(''POINT( ',datatype,CRUISEid,FilepathCSV,fileNameXLS,PlotFile,OpenDAP_link,TimeCoverageStart,TimeCoverageEnd,Abstract4SQL);
    fprintf(fid_DB,'  %3.7f %2.7f)'',4326)); \n',LON(end),LAT(end));
end
% fprintf(fid_DB,'COMMIT;\n');
fclose(fid_DB);

end
