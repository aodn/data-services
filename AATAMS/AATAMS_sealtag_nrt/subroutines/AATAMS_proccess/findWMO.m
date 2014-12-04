function [WMOnumber]=findWMO(pttCode)
%FINDWMO - find the WMO code according to a PTT code. This is a matchup
%when the information is not stored in the MDB AATAMS database
%The function reads a csv file create manually to retrieve the information.
%
% Syntax:  [WMOnumber]=findWMO(pttCode)
%
% Inputs:
%    pttCode - integer
%
% Outputs:
%    WMOnumber - integer
%
% Example: 
%    [WMOnumber]=findWMO(52472)
%
% Subfunctions: none
% Other m-files required: none
% MAT-files required: none
% Other files required: matchupWMO_PTT.csv
%
% See also: createAATAMS_1profile_netcdf, aatams_sealtags_main
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 09-Aug-2012

dataWIP_Path  = readConfig('dataWIP.path', 'config.txt','=');

delimiter=',';
filetext=fullfile(dataWIP_Path,filesep,readConfig('matchupWMO_PTT.name', 'config.txt','='));


if exist(filetext,'file')==2
    % read the text file
    fid = fopen(filetext);
    tline = fgetl(fid);
    ii=1;
    while ischar(tline)
        if tline(1)=='#' %comment line starts with #
            %             disp(tline);
            tline = fgetl(fid);
        else
            C = textscan(tline, '%d %d','Delimiter',delimiter) ;
            allPTT(ii)=C{1,1};
            if  ~isempty(C{1,2})
                allWMO(ii)= C{1,2};
            else
                allWMO(ii)=NaN;
            end
            
            ii=ii+1;
            tline = fgetl(fid);
        end
    end
    
    fclose(fid);
    
end


WMOnumber=allWMO(allPTT==pttCode);

if sum(isnan( WMOnumber))~=0 | (length(WMOnumber)>1)
    WMOnumber=[];
end

end
