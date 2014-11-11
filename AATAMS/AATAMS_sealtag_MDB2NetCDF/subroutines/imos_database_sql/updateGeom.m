function updateGeom
%updateGeom - access to the maplayers database (connected to geoserver) to
%load the data, get the order of the profiles for each tag, and create the
%geometry for each profile. The geometry is actually a segment between the
%two last profiles in order to see the track of each seal. The way the
%function is built might not be the fastest since it requires to load the
%data from the database, but at least it is the safest and does not require
%an access to the files, since the datafabric could be potentially slow
%
% Syntax:  [updateGeom
%
% Inputs:
%
%
% Outputs:
%
%
% Example:
%    updateGeom
%
% Subfunctions: none
% Other m-files required: none
% MAT-files required: none
% Other files required: none
%
% See also: aatams_sealtags_main
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 13-Aug-2012

DATA_FOLDER=readConfig('dataAATAMS.path', 'config.txt','=');

[maplayers_ctd_profile_mdb_workflow_DATA]=get_maplayers_ctd_profile_mdb_workflow_DATA;
[~,indexTime]=sort(datenum({maplayers_ctd_profile_mdb_workflow_DATA.timestamp}','yyyy-mm-dd HH:MM:SS'));
lat_timeOrdered={maplayers_ctd_profile_mdb_workflow_DATA(indexTime).lat}';
lon_timeOrdered={maplayers_ctd_profile_mdb_workflow_DATA(indexTime).lon}';
pkid_timeOrdered={maplayers_ctd_profile_mdb_workflow_DATA(indexTime).pkid}';

A=str2double({maplayers_ctd_profile_mdb_workflow_DATA.ctd_device_mdb_workflow_fk}');
A=A(indexTime);

[ctd_device_mdb_fk_Unique, ~, ~] =unique_no_sort(A);

Filename_DB=fullfile(DATA_FOLDER,readConfig('updateGEOM.psql', 'config.txt','=')); %%SQL COMMANDS to paste on PGadmin
fid_DB = fopen(Filename_DB, 'w+');

nTag=length(ctd_device_mdb_fk_Unique);
for iTag=1:nTag
    clear indexes lat_Tag lon_Tag pkid_Tag
    indexes=(A==ctd_device_mdb_fk_Unique(iTag));
    lat_Tag=str2double(lat_timeOrdered(indexes));
    lon_Tag=str2double(lon_timeOrdered(indexes));
    pkid_Tag=str2double(pkid_timeOrdered(indexes));
    %     plot(lon_Tag,lat_Tag)
    
    fprintf(fid_DB,'BEGIN;\n');

    k=1;epsilon=0.00000001;
    fprintf(fid_DB,'UPDATE aatams_sattag.ctd_profile_mdb_workflow SET geom = GeomFromText(''MULTILINESTRING(( %3.7f  %2.7f,%3.7f  %2.7f ))'',4326) where pkid=%d;\n',...
        lon_Tag(k), lat_Tag(k),...
        lon_Tag(k), lat_Tag(k)+epsilon,...
        pkid_Tag(k));
    
    for k=2:length(lat_Tag)
        if (lon_Tag(k-1) >= 0 && lon_Tag(k) <= 0) % crossing 180th meridian eastward. we divide the segment in 2
            fprintf(fid_DB,'UPDATE aatams_sattag.ctd_profile_mdb_workflow SET geom = GeomFromText(''MULTILINESTRING(( %3.7f  %2.7f , 180  %2.7f ),(-180 %2.7f,  %3.7f %2.7f ))'',4326) where pkid=%d;\n',...
                lon_Tag(k-1), lat_Tag(k-1),...
                (lat_Tag(k-1)+lat_Tag(k))/2,...
                (lat_Tag(k-1)+lat_Tag(k))/2,...
                lon_Tag(k), lat_Tag(k),...
                pkid_Tag(k));
            
        elseif  (lon_Tag(k-1) <= 0 && lon_Tag(k) >=0) % crossing 180th meridian westward. we divide the segment in 2           
            fprintf(fid_DB,'UPDATE aatams_sattag.ctd_profile_mdb_workflow SET geom = GeomFromText(''MULTILINESTRING(( %3.7f  %2.7f , -180  %2.7f ),(+180 %2.7f,  %3.7f %2.7f ))'',4326) where pkid=%d;\n',...
                lon_Tag(k-1), lat_Tag(k-1),...
                (lat_Tag(k-1)+lat_Tag(k))/2,...
                (lat_Tag(k-1)+lat_Tag(k))/2,...
                lon_Tag(k), lat_Tag(k),...
                pkid_Tag(k));
                       
        else
            fprintf(fid_DB,'UPDATE aatams_sattag.ctd_profile_mdb_workflow SET geom = GeomFromText(''MULTILINESTRING(( %3.7f  %2.7f,%3.7f  %2.7f ))'',4326) where pkid=%d;\n',...
                lon_Tag(k-1), lat_Tag(k-1),...
                lon_Tag(k), lat_Tag(k),...
                pkid_Tag(k));
        end
    end
    fprintf(fid_DB,'COMMIT;\n');
    
end
fclose(fid_DB);

end




function [maplayers_ctd_profile_mdb_workflow_DATA]=get_maplayers_ctd_profile_mdb_workflow_DATA
maplayers_information=struct;
maplayers_information.server     =readConfig('postGISserver.address', 'config.txt','=');
maplayers_information.dbName     =readConfig('postGISserver.database', 'config.txt','=');
maplayers_information.port       =readConfig('postGISserver.port', 'config.txt','=');
maplayers_information.user       =readConfig('postGISserver.user', 'config.txt','=');
maplayers_information.schema_name=readConfig('postGISserver.schema', 'config.txt','=');

[queryResult]=getSchemaInfo_psql(maplayers_information);
tableNames=unique({queryResult.tableName}');
% fieldNames=unique({queryResult.fieldName}');

if ismember('ctd_profile_mdb_workflow',tableNames)
    [result1]=getFieldDATA_psql(maplayers_information,'ctd_profile_mdb_workflow','timestamp');
    [result2]=getFieldDATA_psql(maplayers_information,'ctd_profile_mdb_workflow','pkid');
    [result3]=getFieldDATA_psql(maplayers_information,'ctd_profile_mdb_workflow','ctd_device_mdb_workflow_fk');
    [result4]=getFieldDATA_psql(maplayers_information,'ctd_profile_mdb_workflow','lon');
    [result5]=getFieldDATA_psql(maplayers_information,'ctd_profile_mdb_workflow','lat');
    
    maplayers_ctd_profile_mdb_workflow_DATA = catstruct(result1,result2,result3,result4,result5);
else
    maplayers_ctd_profile_mdb_workflow_DATA=srtuct;
    return
end
end