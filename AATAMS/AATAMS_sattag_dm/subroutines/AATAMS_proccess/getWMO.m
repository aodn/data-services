function WMO_NUMBER = getWMO (pttCode)

australianTagsFile = readConfig('australianTags.filepath', 'config.txt','=');

%% read CSV file created by Xavier
aatamssattagmetadata = importAustralianTagCSV(australianTagsFile);

indexPTT   = str2double([aatamssattagmetadata.ptt]) == pttCode;
WMO_NUMBER = char(aatamssattagmetadata.device_wmo_ref(indexPTT));

end
