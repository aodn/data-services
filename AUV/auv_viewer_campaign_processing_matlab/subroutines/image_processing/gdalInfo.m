function gdalOutput=gdalInfo(imageName)
%gdalOutput - gdalinfo Ouput of a geotiff image
%
% Syntax:  gdalOutput=gdalInfo(imageName)
%
% Inputs:
%    imageName - location of a geotiff image
%
% Outputs:
%    gdalOutput - structure
%
% Example:
%   gdalOutput=gdalInfo(imageName)
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
% Oct 2012; Last revision: 31-Oct-2012

setenv('LD_LIBRARY_PATH', '') ; % unsetting LD_LIBRARY_PATH within MATLAB so we can call gdalinfo
cmd=sprintf('/bin/bash --login -c ''echo "$profilevar"; gdalinfo %s''',imageName);
[~,geodalinfoOutput_str]=system(cmd);

UL_Str_idx=strfind(geodalinfoOutput_str,'Upper Left');
LL_Str_idx=strfind(geodalinfoOutput_str,'Lower Left');
UR_Str_idx=strfind(geodalinfoOutput_str,'Upper Right');
LR_Str_idx=strfind(geodalinfoOutput_str,'Lower Right');
Center_Str_idx=strfind(geodalinfoOutput_str,'Center ');

gdalOutput=struct;
if ~isempty(UL_Str_idx)
    %the header_data works with the k index since it avoids to have an empty header_data index to occur if the image is corrupted
    
    
    % string recognition
    %  (  547467.532, 6998631.483) (153d28'44.39"E, 27d 8' 2.43"S)
    % 153.28 + 44.39 / 60  ::::: 27.8 + 2.43/60
    
    % nums =regexp(substrToProcess,'(\d*)d(\d*)[^0-9]*(\d*\.\d*)[^0-9]*(\d*)[^0-9]*(\d*)[^0-9]*(\d*\.\d*)','tokens')%old
    % does not work if there is a space after 'd' like 114d 1'....
    
    %upLeft
    substrToProcess=geodalinfoOutput_str(UL_Str_idx+length('Upper Left'):LL_Str_idx-1);
    nums = regexp(substrToProcess,'(\d*)d[^0-9]*(\d*)[^0-9]*(\d*\.\d*)[^0-9]*(\d*)d[^0-9]*(\d*)[^0-9]*(\d*\.\d*)','tokens');
    gdalOutput.upLlon=str2double(nums{1}{1} )+ str2double(nums{1}{2})/60 + str2double(nums{1}{3})/3600;
    gdalOutput.upLlat=str2double(nums{1}{4} )+ str2double(nums{1}{5})/60 + str2double(nums{1}{6})/3600;
    if ~isempty(strfind(substrToProcess,'S'))
        gdalOutput.upLlat= -gdalOutput.upLlat;
    end
    
    %upRight
    substrToProcess=geodalinfoOutput_str(UR_Str_idx+length('Upper Right'):LR_Str_idx-1);
    nums = regexp(substrToProcess,'(\d*)d[^0-9]*(\d*)[^0-9]*(\d*\.\d*)[^0-9]*(\d*)d[^0-9]*(\d*)[^0-9]*(\d*\.\d*)','tokens');
    gdalOutput.upRlon=str2double(nums{1}{1} )+ str2double(nums{1}{2})/60 + str2double(nums{1}{3})/3600;
    gdalOutput.upRlat=str2double(nums{1}{4} )+ str2double(nums{1}{5})/60 + str2double(nums{1}{6})/3600;
    if ~isempty(strfind(substrToProcess,'S'))
        gdalOutput.upRlat= -gdalOutput.upRlat;
    end
    
    %lowR
    substrToProcess=geodalinfoOutput_str(LR_Str_idx+length('Lower Right'):Center_Str_idx-1);
    nums = regexp(substrToProcess,'(\d*)d[^0-9]*(\d*)[^0-9]*(\d*\.\d*)[^0-9]*(\d*)d[^0-9]*(\d*)[^0-9]*(\d*\.\d*)','tokens');
    gdalOutput.lowRlon=str2double(nums{1}{1} )+ str2double(nums{1}{2})/60 + str2double(nums{1}{3})/3600;
    gdalOutput.lowRlat=str2double(nums{1}{4} )+ str2double(nums{1}{5})/60 + str2double(nums{1}{6})/3600;
    if ~isempty(strfind(substrToProcess,'S'))
        gdalOutput.lowRlat= - gdalOutput.lowRlat;
    end
    
    
    %lowL
    substrToProcess=geodalinfoOutput_str(LL_Str_idx+length('Lower Left'):UR_Str_idx-1);
    nums = regexp(substrToProcess,'(\d*)d[^0-9]*(\d*)[^0-9]*(\d*\.\d*)[^0-9]*(\d*)d[^0-9]*(\d*)[^0-9]*(\d*\.\d*)','tokens');
    gdalOutput.lowLlon=str2double(nums{1}{1} )+ str2double(nums{1}{2})/60 + str2double(nums{1}{3})/3600;
    gdalOutput.lowLlat=str2double(nums{1}{4} )+ str2double(nums{1}{5})/60 + str2double(nums{1}{6})/3600;
    if ~isempty(strfind(substrToProcess,'S'))
        gdalOutput.lowLlat= - gdalOutput.lowLlat;
    end
    
    %center
    gdalOutput.lon_center=(gdalOutput.upLlon + gdalOutput.upRlon + gdalOutput.lowRlon + gdalOutput.lowLlon)/4;
    gdalOutput.lat_center=(gdalOutput.upLlat + gdalOutput.upRlat + gdalOutput.lowRlat + gdalOutput.lowLlat)/4;
    
    
    sizeImage = regexp(geodalinfoOutput_str,'[^0-9]*Size is (\d*)[^0-9]*(\d*)','tokens');
    idxG1 = strfind(geodalinfoOutput_str,'PROJCS[');
    idxG2 = strfind(geodalinfoOutput_str,'GEOGCS');
    
    projection=geodalinfoOutput_str(idxG1+length('PROJCS[')+1:idxG2-length('GEOGCS')-3);
    
    gdalOutput.Width= str2double(sizeImage{1}{1});
    gdalOutput.Heigh= str2double(sizeImage{1}{2});
    gdalOutput.Projection=projection;
    gdalOutput.GCS='unknown';
    [~, Image_name, Image_ext]=fileparts(imageName);
    gdalOutput.image=[Image_name Image_ext];
    
    %         catch ME%if the image is corrupted, it is listed
else
fprintf('%s - WARNING; image %s is corrupted\n',datestr(now),imageName)
end
end

