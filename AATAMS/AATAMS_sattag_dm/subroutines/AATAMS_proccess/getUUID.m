function metadataUUID = getUUID (pttCode)

australianTagsFile = readConfig('australianTags.filepath', 'config.txt','=');

%% read CSV file created by Xavier
aatamssattagmetadata = importAustralianTagCSV(australianTagsFile);

indexPTT   = str2double([aatamssattagmetadata.ptt]) == pttCode;
metadataUUID = char(aatamssattagmetadata.metadata(indexPTT));

end
