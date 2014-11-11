function writeSQL_updateWMO
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

Filename_DB=fullfile(DATA_FOLDER,strcat('DB_UPDATE_AATAMS_TABLE.sql')); %%SQL COMMANDS to paste on PGadmin
fid_DB = fopen(Filename_DB, 'w+');
fprintf(fid_DB,'BEGIN;\n');

[~,~,ncFileList]=DIRR(strcat(DATA_FOLDER,filesep,'*END*.nc'),'name');
ncFileList=ncFileList';

nNCFILE=length(ncFileList);
for iiFile=1:nNCFILE
    ncid=netcdf.open(ncFileList{iiFile},'NC_NOWRITE');
    [gattname,gattval]=getGlobAttNC(ncid);
    
    idxGlobAtt_WMO= strcmpi(gattname,'platform_code')==1;
    if sum(idxGlobAtt_WMO)~=0
        GlobAtt_WMO=gattval{idxGlobAtt_WMO};
        
        if ~isempty(GlobAtt_WMO)
            idxGlobAtt_unique_reference_code= strcmpi(gattname,'unique_reference_code')==1;
            GlobAtt_unique_reference_code=gattval{idxGlobAtt_unique_reference_code};
            
            
            fprintf(fid_DB,'UPDATE aatams_sattag.ctd_device_mdb_workflow SET device_wmo_ref = ''%s'' where device_id= ''%s'';\n',GlobAtt_WMO,GlobAtt_unique_reference_code);
            
        end
    end
    netcdf.close(ncid)
    
    
end

fprintf(fid_DB,'COMMIT;\n');



end

