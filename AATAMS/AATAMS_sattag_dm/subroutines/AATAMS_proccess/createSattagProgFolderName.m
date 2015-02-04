function sattag_folderName   = createSattagProgFolderName (CTD_DATA, METADATA)

australianTagsFile           = readConfig('australianTags.filepath', 'config.txt','=');

%% read CSV file created by Xavier
aatamssattagmetadata         = importAustralianTagCSV(australianTagsFile);

indexesSattagProgr           = find(ismember(aatamssattagmetadata.sattag_program,char(unique(METADATA.GREF)) ) );

% read unique values for a tag
uniqueSattag                 = unique(aatamssattagmetadata.sattag_program(indexesSattagProgr)) ;
uniqueSattag                 = uniqueSattag(~cellfun('isempty',uniqueSattag))  ;

uniqueState                  = unique(aatamssattagmetadata.state_country(indexesSattagProgr) );
uniqueState                  = uniqueState(~cellfun('isempty',uniqueState))  ;

if size(uniqueState,1) >1
    newStr                       = uniqueState{1};
    for ii                       = 2 : length (uniqueState)
        
        newStr                       = strcat(newStr,'_',uniqueState{ii});
    end
    uniqueState                  = newStr;
end

if ~isempty(uniqueState)
    uniqueReleaseSite            = unique(aatamssattagmetadata.release_site(indexesSattagProgr)) ;
    uniqueReleaseSite            = uniqueReleaseSite(~cellfun('isempty',uniqueReleaseSite))  ;
    
    if size(uniqueReleaseSite,1) == 1
        sattag_folderName            = strrep(strcat(uniqueSattag, '_' ,uniqueState, '_' ,uniqueReleaseSite ),' ','-');
    else
        sattag_folderName            = strrep(strcat(uniqueSattag, '_' ,uniqueState ),' ','-');
    end
else
    sattag_folderName            = strrep(uniqueSattag,' ','-');
end

% add year in the front of the folder name
[yearStart,~,~,~,~,~]        = datevec(min([CTD_DATA.END_DATE]));
sattag_folderName            = char(strcat(num2str(yearStart),'_',sattag_folderName));

end
