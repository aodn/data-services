function createUUID(campaign,dive)
%createUUID - creates if needed the metadata uuid for each dive
%the function creates a text file in which each dive is associated to a
%metadata record. In the case a dive is reprocessed, the function does not
%recreate a uuid because it already exists in the text file.
%
% Syntax:  createUUID(campaign,dive)
%
% Inputs:
%    METATADA - structure of metadata
%
% Outputs:
%    metadataUUID.file in config.txt
%
% Example:
%   campaign='PS201012';dive='r20101215_194708_fingal_03_broadgrid';
%   createUUID(campaign,dive)
%
% Subfunctions: none
% Other m-files required: none
% MAT-files required: none
% Other files required: 
%
% See also: 
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Oct 2012; Last revision: 13-Aug-2012


DATA_FOLDER=readConfig('proccessedDataOutput.path', 'config.txt','=');
filetext=fullfile(DATA_FOLDER,filesep,readConfig('metadataUUID.file', 'config.txt','='));

delimiter=',';

if exist(filetext,'file')==2
    % read the text file
    fid = fopen(filetext);
    tline = fgetl(fid);
    ii=1;
    while ischar(tline)
        if ~isempty(tline)
            if tline(1)=='#' %comment line starts with #
                %             disp(tline);
                tline = fgetl(fid);
            else
                C = textscan(tline, '%s %s','Delimiter',delimiter) ;
                campaignDive_csv(ii)=strrep(C{1,1},' ','');
                %             allPtt(ii)= strrep(C{1,2},' ','');
                %             allUuid(ii)= strrep(C{1,2},' ','');
                
                ii=ii+1;
                tline = fgetl(fid);
            end
        else
            tline = fgetl(fid);
        end
    end
    fclose(fid);    
    
end



if exist('campaignDive_csv','var')
    %     indexAlreadyExist=(ismember(campaignDive_csv',ref_database));
    [~,indexNewDive]=setdiff([campaign filesep dive],campaignDive_csv');
    if ~isempty(indexNewDive)
        fid = fopen(filetext, 'a+'); 
        metadata_uuid= char(java.util.UUID.randomUUID);
        fprintf(fid,'%s,%s\n',[campaign filesep dive],metadata_uuid);
        fclose(fid);
    end
else
    
    fid = fopen(filetext, 'a+');
    fprintf(fid, '# [campaign/dive],[metadataUUID]\n');
    
    metadata_uuid= char(java.util.UUID.randomUUID);
    fprintf(fid,'%s,%s\n',[campaign filesep dive],metadata_uuid);
    
    fclose(fid);
end
