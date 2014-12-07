function [uuid]=findUUID(ref)
%findUUID - find the uuid code according to a ref code. 
%
% Syntax:  [WMOnumber]=findWMO(ref)
%
% Inputs:
%    ref - string
%
% Outputs:
%    uuid - string
%
% Example: 
%    [uuid]=findUUID(ref)
%
% Subfunctions: none
% Other m-files required: none
% MAT-files required: none
% Other files required: matchupWMO_PTT.csv
%
% See also: createAATAMS_1profile_netcdf, aatams_sealtags_main,read_writeInfo
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 09-Aug-2012

dataWIP_Path  = readConfig('dataWIP.path', 'config.txt','=');
delimiter     = ',';
filetext      = fullfile(dataWIP_Path,filesep,'ptt_ref_uuid_INFO.csv');


if exist(filetext,'file')==2
    % read the text file
    fid   = fopen(filetext);
    tline = fgetl(fid);
    ii    = 1;
    while ischar(tline)
        if tline(1)=='#' %comment line starts with #
            %             disp(tline);
            tline = fgetl(fid);
        else
            C = textscan(tline, '%s %s %s','Delimiter',delimiter) ;
            allRef(ii)=C{1,1};
            allPtt(ii)= C{1,2};
            allUuid(ii)= C{1,3};
            
            ii=ii+1;
            tline = fgetl(fid);
        end
    end
    fclose(fid);
end

indexRef=(ismember(allRef',ref));      
uuid=allUuid(indexRef);


end
