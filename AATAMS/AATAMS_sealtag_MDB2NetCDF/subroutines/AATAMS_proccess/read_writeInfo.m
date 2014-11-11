function read_writeInfo(METADATA)
%read_writeInfo - find the WMO code according to a PTT code. This is a matchup
%The function reads creates, appends a csv file with uuid ppt and ref_database info.
%
% Syntax:  [WMOnumber]=read_writeInfo(pttCode)
%
% Inputs:
%    METATADA - structure of metadata
%
% Outputs:
%    ptt_ref_uuid_INFO.csv
%
% Example:
%    read_writeInfo(METATADA)
%
% Subfunctions: none
% Other m-files required: none
% MAT-files required: none
% Other files required: ptt_ref_uuid_INFO.csv
%
% See also: createAATAMS_1profile_netcdf, aatams_sealtags_main,findUUID
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 13-Aug-2012

global DATA_FOLDER;

delimiter=',';
filetext=fullfile(DATA_FOLDER,filesep,readConfig('matchupREF_PTT_UUID.name', 'config.txt','='));

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
                C = textscan(tline, '%s %s %s','Delimiter',delimiter) ;
                ref_csv(ii)=strrep(C{1,1},' ','');
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


ref_database={METADATA.ref}';
ptt={METADATA.PTT}';

if exist('ref_csv','var')
    %     indexAlreadyExist=(ismember(ref_csv',ref_database));
    [~,indexNewTags]=setdiff(ref_database,ref_csv');
    if ~isempty(indexNewTags)
        fid = fopen(filetext, 'a+');
        fprintf(fid, '# [ref_unique],[ptt],[uuid],append new tags %s\n',datestr(now));
        for nnChannel=indexNewTags'
            %             if indexAlreadyExist(nnChannel)==0
            metadata_uuid= char(java.util.UUID.randomUUID);
            fprintf(fid,'%s,%s,%s\n',ref_database{nnChannel},ptt{nnChannel},metadata_uuid);
            %             end
        end
        fclose(fid);
    end
else
    
    fid = fopen(filetext, 'a+');
    fprintf(fid, '# [ref_unique],[ptt],[uuid]\n');
    for nnChannel=1:length(ref_database)
        metadata_uuid= char(java.util.UUID.randomUUID);
        fprintf(fid,'%s,%s,%s\n',ref_database{nnChannel},ptt{nnChannel},metadata_uuid);        
    end
    fclose(fid);    
end
