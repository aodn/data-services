function UPDATE_qaqc_noqaqc_boolean_DB_FAIMMS(channelInfo,levelQC)
global dataWIP;
global DATE_PROGRAM_LAUNCHED

channelId=sort(str2double(channelInfo.channelId));

Filename_DB=fullfile(dataWIP,strcat('DB_Update_FAIMMS_TABLE',DATE_PROGRAM_LAUNCHED,'.sql')); %%SQL COMMANDS to paste on PGadmin
fid_DB = fopen(Filename_DB, 'a+');

fprintf(fid_DB,'BEGIN;\n');
Number_channels_available=size(channelId,1);
if levelQC == 0
    for j=1:Number_channels_available
        fprintf(fid_DB,'UPDATE faimms.faimms_parameters set no_qaqc_boolean=1 where channelid=%d;\n',channelId(j));
    end
    
elseif levelQC== 1
    for j=1:Number_channels_available
        fprintf(fid_DB,'UPDATE faimms.faimms_parameters set qaqc_boolean=1 where channelid=%d;\n',channelId(j));
    end
end

fprintf(fid_DB,'COMMIT;\n');
fclose(fid_DB);

end