function bodyNumber = getbodyNumber (pttCode)

australianTagsFile = readConfig('australianTags.filepath', 'config.txt','=');

%% read CSV file created by Xavier
aatamssattagmetadata = importAustralianTagCSV(australianTagsFile);

indexPTT   = str2double([aatamssattagmetadata.ptt]) == pttCode;
bodyNumber = char(aatamssattagmetadata.body(indexPTT));

end
