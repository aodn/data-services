function [CTD_DATA, METADATA] =loadCTD_datafromDB(database_information)
%loadCTD_datafromDB - load data and metadata from postgres database.
%
% Syntax:  createAATAMS_1profile_netcdf(CTD_DATA, METADATA)
%
% Inputs:
%    database_information - structure of information about user,server,port
%
% Outputs:
%    CTD_DATA - structure of data
%    METADATA - structure of metadata
%
% Example:
%    createAATAMS_1profile_netcdf(CTD_DATA, METADATA)
%
% Other files required: none
% Other m-files required: getFieldDATA_psql,catstruct
% Subfunctions: none
% MAT-files required: none
%
% See also: aatams_sealtags_main,getFieldDATA_psql
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 10-Aug-2012

[queryResult]=getSchemaInfo_psql(database_information);
tableNames=unique({queryResult.tableName}');
fieldNames=unique({queryResult.fieldName}');

if ismember('ctd',tableNames)
    [result1]=getFieldDATA_psql(database_information,'ctd','SAL_DBAR');
    [result2]=getFieldDATA_psql(database_information,'ctd','SAL_VALS');
    [result3]=getFieldDATA_psql(database_information,'ctd','N_SAL');
    
    [result4]=getFieldDATA_psql(database_information,'ctd','TEMP_DBAR');
    [result5]=getFieldDATA_psql(database_information,'ctd','TEMP_VALS');
    [result6]=getFieldDATA_psql(database_information,'ctd','N_TEMP');
    
    [result7]=getFieldDATA_psql(database_information,'ctd','COND_DBAR');
    [result8]=getFieldDATA_psql(database_information,'ctd','COND_VALS');
    [result9]=getFieldDATA_psql(database_information,'ctd','N_COND');
    
    [result10]=getFieldDATA_psql(database_information,'ctd','ref');
    [result100]=getFieldDATA_psql(database_information,'ctd','PTT');

    
    [result11]=getFieldDATA_psql(database_information,'ctd','END_DATE');
    [result12]=getFieldDATA_psql(database_information,'ctd','LAT');
    [result13]=getFieldDATA_psql(database_information,'ctd','LON');
    
    % [result14]=getFieldDATA_psql(database_information,'ctd','FLUORO_DBAR');
    % [result15]=getFieldDATA_psql(database_information,'ctd','FLUORO_VALS');
    % [result16]=getFieldDATA_psql(database_information,'ctd','N_FLUORO');
    
    % [result17]=getFieldDATA_psql(database_information,'ctd','OXY_DBAR');
    % [result18]=getFieldDATA_psql(database_information,'ctd','OXY_VALS');
    % [result19]=getFieldDATA_psql(database_information,'ctd','N_OXY');
    
    % [result20]=getFieldDATA_psql(database_information,'ctd','QC_TEMP');
    % [result21]=getFieldDATA_psql(database_information,'ctd','QC_SAL');
    % [result22]=getFieldDATA_psql(database_information,'ctd','SAL_CORRECTED_VALS');
    
    % CTD_DATA = catstruct(result1,result2,result3,result4,result5,result6,result7,result8,result9,result10,result100,result11,result12,result13,result14,result15,result16,result17,result18,result19,result20,result21,result22);
    CTD_DATA = catstruct(result1,result2,result3,result4,result5,result6,result7,result8,result9,result10,result100,result11,result12,result13);
else
    fprintf('%s - WARNING, table "ctd" is not present in Microsoft Access Database,Contact SMRU\n',datestr(now))
    CTD_DATA=struct;
end
clear result*

if ismember('deployments',tableNames)
    
    [result1]=getFieldDATA_psql(database_information,'deployments','ref');
    if ismember('WMO',fieldNames)
        [result2]=getFieldDATA_psql(database_information,'deployments','WMO');
    else
        wmoCell=cell(1,length(result1));%result1 is a reference
        result2=cell2struct(wmoCell,'WMO',length(result1));
        fprintf('%s - WARNING, field "WMO" is not present in Microsoft Access Database. Database has a different format.Contact SMRU\n',datestr(now))
    end
    [result3]=getFieldDATA_psql(database_information,'deployments','COMMENTS');
    [result4]=getFieldDATA_psql(database_information,'deployments','SPECIES');
    [result5]=getFieldDATA_psql(database_information,'deployments','LOCATION');
    [result6]=getFieldDATA_psql(database_information,'deployments','PTT');
    [result7]=getFieldDATA_psql(database_information,'deployments','YEAR');
    [result8]=getFieldDATA_psql(database_information,'deployments','HOME_LAT');
    [result9]=getFieldDATA_psql(database_information,'deployments','HOME_LON');
    [result10]=getFieldDATA_psql(database_information,'deployments','BODY');
    [result11]=getFieldDATA_psql(database_information,'deployments','GREF');


    METADATA = catstruct(result1,result2,result3,result4,result5,result6,result7,result8,result9,result10,result11);
else
    fprintf('%s - WARNING, table "deployments" is not present in Microsoft Access Database,contact smru\n',datestr(now))
    METADATA=struct;
end

end
