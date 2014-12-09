function speciesName = getSpeciesName (pttCode)

australianTagsFile = readConfig('australianTags.filepath', 'config.txt','=');

%% read CSV file created by Xavier
aatamssattagmetadata = importAustralianTagCSV(australianTagsFile);

indexPTT   = str2double([aatamssattagmetadata.ptt]) == pttCode;
speciesName = char(aatamssattagmetadata.species(indexPTT));

end
