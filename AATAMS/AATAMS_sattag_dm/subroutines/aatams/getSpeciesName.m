function speciesName = getSpeciesName (pttCode)

australianTagsFile = getenv('australian_tags_filepath');

%% read CSV file created by Xavier
aatamssattagmetadata = importAustralianTagCSV(australianTagsFile);

indexPTT   = str2double([aatamssattagmetadata.ptt]) == pttCode;
speciesName = char(aatamssattagmetadata.species(indexPTT));

end
