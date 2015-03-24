function releaseSite = getreleaseSite(pttCode)

australianTagsFile = getenv('australian_tags_filepath');

%% read CSV file created by Xavier
aatamssattagmetadata = importAustralianTagCSV(australianTagsFile);

indexPTT   = str2double([aatamssattagmetadata.ptt]) == pttCode;
releaseSite = char(aatamssattagmetadata.release_site(indexPTT));

end
