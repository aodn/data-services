function releaseSite = getreleaseSite(pttCode)

australianTagsFile = readConfig('australianTags.filepath', 'config.txt','=');

%% read CSV file created by Xavier
aatamssattagmetadata = importAustralianTagCSV(australianTagsFile);

indexPTT   = str2double([aatamssattagmetadata.ptt]) == pttCode;
releaseSite = char(aatamssattagmetadata.release_site(indexPTT));

end
