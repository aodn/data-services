function SATTAG = getSATTAG(pttCode)

australianTagsFile = getenv('australian_tags_filepath');

%% read CSV file created by Xavier
aatamssattagmetadata = importAustralianTagCSV(australianTagsFile);

indexPTT   = str2double([aatamssattagmetadata.ptt]) == pttCode;
SATTAG = char(aatamssattagmetadata.sattag_program(indexPTT));

end
