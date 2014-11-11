function writeSQL_inserts
%writeSQL_inserts - populates the tables for visualisation on geoserver
%
% Syntax:  writeSQL_inserts
%
% Inputs:
%
%
% Outputs:DB_Insert_AATAMS_TABLE.sql
%
% Example:
%    writeSQL_inserts
%
% Other files required: none
% Other m-files required:
% Subfunctions: none
% MAT-files required: none
%
% See also: aatams_sealtags_main
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 16-Aug-2012
global DATA_FOLDER;

Filename_DB=fullfile(DATA_FOLDER,readConfig('insertAATAMS.psql', 'config.txt','=')); %%SQL COMMANDS to paste on PGadmin
fid_DB = fopen(Filename_DB, 'w+');
fprintf(fid_DB,'BEGIN;\n');

[~,~,ncFileList]=DIRR(strcat(DATA_FOLDER,filesep,'NETCDF',filesep,'*END*.nc'),'name');
ncFileList=ncFileList';

nNCFILE=length(ncFileList);
for iiFile=1:nNCFILE
    ncid=netcdf.open(ncFileList{iiFile},'NC_NOWRITE');
    [gattname,gattval]=getGlobAttNC(ncid);
    
    idxGlobAtt_WMO= strcmpi(gattname,'platform_code')==1;
    if sum(idxGlobAtt_WMO)~=0
        GlobAtt_WMO=gattval{idxGlobAtt_WMO};
    else
        GlobAtt_WMO='NULL';
    end
    if isempty(GlobAtt_WMO)
        GlobAtt_WMO='NULL';
    end
    idxGlobAtt_unique_reference_code= strcmpi(gattname,'unique_reference_code')==1;
    GlobAtt_unique_reference_code=gattval{idxGlobAtt_unique_reference_code};
    
    idxGlobAtt_UUID= strcmpi(gattname,'metadata_uuid')==1;
    GlobAtt_UUID=gattval{idxGlobAtt_UUID};
    
    idxGlobAtt_body_code= strcmpi(gattname,'body_code')==1;
    GlobAtt_body_code=gattval{idxGlobAtt_body_code};
    
    idxGlobAtt_ptt_code= strcmpi(gattname,'ptt_code')==1;
    GlobAtt_ptt_code=gattval{idxGlobAtt_ptt_code};
    
    idxGlobAtt_species_name= strcmpi(gattname,'species_name')==1;
    GlobAtt_species_name=gattval{idxGlobAtt_species_name};
    
    idxGlobAtt_release_site= strcmpi(gattname,'release_site')==1;
    GlobAtt_release_site=gattval{idxGlobAtt_release_site};
    
    idxGlobAtt_sattag_program= strcmpi(gattname,'sattag_program')==1;
    GlobAtt_sattag_program=gattval{idxGlobAtt_sattag_program};
    
    idxGlobAtt_abstract= strcmpi(gattname,'abstract')==1;
    GlobAtt_abstract=gattval{idxGlobAtt_abstract};
    
    tagType='SMRU CTD tag';
    
    [filepath,~,~]=fileparts(ncFileList{iiFile});
    opendapLink=['http://opendap-vpac.arcs.org.au/thredds/catalog/IMOS/AATAMS/marine_mammal_ctd-tag/' filepath(length(strcat(DATA_FOLDER,filesep,'NETCDF',filesep))+1:end) '/'];
    
    
%     fprintf(fid_DB,'INSERT INTO aatams_sattag.ctd_device_mdb_workflow (pkid,device_id,ptt,body,device_wmo_ref,metadata,sattag_program,abstract,tag_type,common_name,release_site,opendap_url)\n');
%     fprintf(fid_DB,'VALUES ((SELECT count(pkid) FROM aatams_sattag.ctd_device_mdb_workflow) + 1, ''%s\'', ''%s\'', ''%s\'', ''%s\'', ''%s\'', ''%s\'', ''%s\'', ''%s\'', ''%s\'', ''%s\'',''%s\'');\n',...
%         GlobAtt_unique_reference_code,GlobAtt_ptt_code, GlobAtt_body_code,GlobAtt_WMO, GlobAtt_UUID,GlobAtt_sattag_program,GlobAtt_abstract,tagType,GlobAtt_species_name,GlobAtt_release_site,opendapLink);
fprintf(fid_DB,'INSERT INTO aatams_sattag.ctd_device_mdb_workflow (device_id,ptt,body,device_wmo_ref,metadata,sattag_program,abstract,tag_type,common_name,release_site,opendap_url)\n');
    fprintf(fid_DB,'VALUES (''%s\'', ''%s\'', ''%s\'', ''%s\'', ''%s\'', ''%s\'', ''%s\'', ''%s\'', ''%s\'', ''%s\'',''%s\'');\n',...
        GlobAtt_unique_reference_code,GlobAtt_ptt_code, GlobAtt_body_code,GlobAtt_WMO, GlobAtt_UUID,GlobAtt_sattag_program,GlobAtt_abstract,tagType,GlobAtt_species_name,GlobAtt_release_site,opendapLink);

    %     (SELECT max(pkid) FROM aatams_sattag.ctd_device_mdb_workflow) + 1,
    
    netcdf.close(ncid)
end

fprintf(fid_DB,'COMMIT;\n');

[~,~,ncFileListALL]=DIRR(strcat(DATA_FOLDER,filesep,'NETCDF',filesep,'*.nc'),'name');
ncFileListALL=ncFileListALL';

nNCFILE=length(ncFileListALL);
fprintf(fid_DB,'BEGIN;\n');

for iiFile=1:nNCFILE
    
    if isempty(strfind(ncFileListALL{iiFile},'END'))
        ncid=netcdf.open(ncFileListALL{iiFile},'NC_NOWRITE');
        [gattname,gattval]=getGlobAttNC(ncid);
        
        idxGlobAtt_WMO= strcmpi(gattname,'wmo_identifier')==1;
        if sum(idxGlobAtt_WMO)~=0
            GlobAtt_WMO=gattval{idxGlobAtt_WMO};
        else
            GlobAtt_WMO='NULL';
        end
        if isempty(GlobAtt_WMO)
            GlobAtt_WMO='NULL';
        end
        
        idxGlobAtt_unique_reference_code= strcmpi(gattname,'unique_reference_code')==1;
        GlobAtt_unique_reference_code=gattval{idxGlobAtt_unique_reference_code};
        
        [filepath,filename,ext]=fileparts(ncFileListALL{iiFile});
        filename=[filepath(length(strcat(DATA_FOLDER,filesep,'NETCDF',filesep))+1:end) '/'  filename,ext];
        
        
        [allVarnames,~]=listVarNC(ncid);
        LATITUDE=getVarNC('LATITUDE',allVarnames,ncid);
        LONGITUDE=getVarNC('LONGITUDE',allVarnames,ncid);
        TIME= getTimeData(ncid,allVarnames);
        
        if ~(isnan(LATITUDE) | isnan(LONGITUDE))
            %                 fprintf(fid_DB,'INSERT INTO aatams_sattag.ctd_profile_mdb_workflow (profile_id,device_id,device_wmo_ref,timestamp,lon,lat,filename)\n');
            %                 fprintf(fid_DB,'VALUES (nextval(''aatams_sattag.ctd_profile_serial_mdb_workflow''),''%s\'', ''%s\'', ''%s\'', ''%3.5f\'', ''%2.5f\'', ''%s\'');\n',...
            %                     GlobAtt_unique_reference_code,GlobAtt_WMO,datestr(TIME,'yyyy-mm-dd HH:MM:SS'),LONGITUDE,LATITUDE,filename);
            %         fprintf(fid_DB,'INSERT INTO aatams_sattag.ctd_profile_mdb_workflow (pkid,device_id,device_wmo_ref,timestamp,lon,lat,filename,geom)\n');
            %         fprintf(fid_DB,'VALUES ((SELECT count(pkid) FROM aatams_sattag.ctd_profile_mdb_workflow) + 1,''%s\'',''%s\'',''%s\'',''%3.7f\'',''%2.7f\'',''%s\'',PointFromText(\''POINT(%3.7f  %2.7f)\'' ,4326));\n',...
            %             GlobAtt_unique_reference_code,GlobAtt_WMO,datestr(TIME,'yyyy-mm-dd HH:MM:SS'),LONGITUDE,LATITUDE,filename,LONGITUDE,LATITUDE);
            
            value_pkid=strcat('(Select pkid from aatams_sattag.ctd_device_mdb_workflow where device_id = '' ', GlobAtt_unique_reference_code,''') ' );

            fprintf(fid_DB,'INSERT INTO aatams_sattag.ctd_profile_mdb_workflow (ctd_device_mdb_workflow_fk,device_wmo_ref,timestamp,lon,lat,filename)\n');
            fprintf(fid_DB,'VALUES (%s, ''%s\'', ''%s\'', ''%3.5f\'', ''%2.5f\'', ''%s\'');\n',...
                value_pkid,GlobAtt_WMO,datestr(TIME,'yyyy-mm-dd HH:MM:SS'),LONGITUDE,LATITUDE,filename);
        else
            Filename_badLocation=fullfile(DATA_FOLDER,strcat('corruptedLocationList.csv')); %%SQL COMMANDS to paste on PGadmin
            fid_corrupted = fopen(Filename_badLocation, 'a+');
            fprintf(fid_corrupted,'%s - NO LOCATION FOR PROFILE %s\n',datestr(now),filename);
            fclose(fid_corrupted);
        end
        netcdf.close(ncid)
        clear filename
    end
end
fprintf(fid_DB,'COMMIT;\n');

fprintf(fid_DB,'BEGIN;\n');
fprintf(fid_DB,'UPDATE aatams_sattag.ctd_profile_mdb_workflow SET geom = PointFromText(''POINT('' || lon || '' '' || lat || '')'',4326);');
fprintf(fid_DB,'COMMIT;\n');

fclose('all');

end

