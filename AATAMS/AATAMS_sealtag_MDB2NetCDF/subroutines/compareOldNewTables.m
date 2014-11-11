function compareOldNewTables


    
database_informationMDB=struct;
database_informationMDB.server='db.emii.org.au';
database_informationMDB.dbName='maplayers';
database_informationMDB.port='5432';
database_informationMDB.user='gis_writer';
database_informationMDB.schema_name='aatams_sattag';

device_wmo_ref_MDB=getFieldDATA_psql(database_informationMDB,'ctd_device_mdb_workflow','device_wmo_ref');
device_wmo_ref_MDB=strtrim({device_wmo_ref_MDB.device_wmo_ref}');

nProfilePerDeviceMDB=getFieldDATA_psql(database_informationMDB,'ctd_profile_mdb_workflow','device_wmo_ref');
nProfilePerDeviceMDB=strtrim({nProfilePerDeviceMDB.device_wmo_ref}');

uniqueProfMDB=unique_no_sort(nProfilePerDeviceMDB);
for ii=1:length(uniqueProf)
A=strfind(nProfilePerDeviceMDB,uniqueProf{ii});
A=~cellfun('isempty',A);
nProfileMDB(ii)=sum(A);
end
nProfileMDB=nProfileMDB';

%--------------
database_information=struct;
database_information.server='db.emii.org.au';
database_information.dbName='maplayers';
database_information.port='5432';
database_information.user='gis_writer';
database_information.schema_name='aatams_sattag';
    
device_wmo_ref_old=getFieldDATA_psql(database_information,'ctd_device','device_wmo_ref');
device_wmo_ref_old=strtrim({device_wmo_ref_old.device_wmo_ref}');

[isOldMemberFromnew,~]=ismember(device_wmo_ref_old,device_wmo_ref_MDB);

nProfilePerDevice=getFieldDATA_psql(database_information,'ctd_profile','device_wmo_ref');
nProfilePerDevice=strtrim({nProfilePerDevice.device_wmo_ref}');

uniqueProf=unique_no_sort(nProfilePerDevice);
clear nProfile
for ii=1:length(uniqueProf)
A=strfind(nProfilePerDevice,uniqueProf{ii});
A=~cellfun('isempty',A);
nProfile(ii)=sum(A);
end
nProfile=nProfile';

[~,loc]=ismember(unique_no_sort(nProfilePerDevice),(nProfilePerDeviceMDB))

%only do on similar wmo
% uniqueProfMDB=unique(nProfilePerDeviceMDB);
clear nProfileMDB uniqueProfMDB
uniqueProfMDB=nProfilePerDeviceMDB(loc)
for ii=1:length(uniqueProf)
A=strfind(nProfilePerDeviceMDB,uniqueProf{ii});
A=~cellfun('isempty',A);
nProfileMDB(ii)=sum(A);
end
nProfileMDB=nProfileMDB';

%copy and past on spreadsheet to compare quickly