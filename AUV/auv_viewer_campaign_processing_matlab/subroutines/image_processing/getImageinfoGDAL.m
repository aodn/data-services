function [header_data, errorID] = getImageinfoGDAL(AUV_Folder,Campaign,Dive)
%getImageinfo harvests the metadata of a folder containing GeoTIFF images
% it requires to have gdalinfo and gdal-bin package
%
% Inputs:
%   AUV_Folder  - str pointing to the main AUV folder address ( could be
%                 local or on the DF -slow- through a mount.davfs
%   Campaign    - str containing the Campaign name.
%   Dive        - str containing the Dive name.
%
% Outputs:
%   header_data       - Structure containing images metadata.
%   errorID           - Cell array containing a list of corrupted image names.
%
% Author: Laurent Besnard <laurent.besnard@utas,edu,au>

format long
warning('off','MATLAB:dispatcher:InexactCaseMatch')


divePath= (strcat(AUV_Folder,filesep,Campaign,filesep,Dive));
TIFF_dir=dir([divePath filesep 'i2*gtif']);
tiffPath=[divePath filesep TIFF_dir.name];

list_images=dir([tiffPath filesep '*LC16.tif']);

errorID=[];
if ~isempty(list_images)
    fprintf('%s - Processing images for %s\n',datestr(now), [Campaign '-' Dive]);
    header_data(length(list_images),1)=struct('upLlat',[],'upLlon',[],'upRlat',[],'upRlon',[],...
        'lowRlat',[],'lowRlon',[],'lowLlat',[],'lowLlon',[],'lon_center',[],'lat_center',[]);
    k=0;
    eID=0; %errorID index
    for j=1:length(list_images)
        
        image_name_location= strcat(strcat(AUV_Folder,filesep,Campaign,filesep,Dive,filesep,TIFF_dir.name,filesep,list_images(j,1).name));
        %         try   %try catch if the image is corrupted
        
        
        cmd=sprintf('/bin/bash --login -c ''echo "$profilevar"; gdalinfo %s''',image_name_location);
        [~,geodalinfoOutput_str]=system(cmd);
        
        UL_Str_idx=strfind(geodalinfoOutput_str,'Upper Left');
        LL_Str_idx=strfind(geodalinfoOutput_str,'Lower Left');
        UR_Str_idx=strfind(geodalinfoOutput_str,'Upper Right');
        LR_Str_idx=strfind(geodalinfoOutput_str,'Lower Right');
        Center_Str_idx=strfind(geodalinfoOutput_str,'Center ');
        
        if ~isempty(UL_Str_idx)
            k=k+1;  %the header_data works with the k index since it avoids to have an empty header_data index to occur if the image is corrupted
            
            
            % string recognition
            %  (  547467.532, 6998631.483) (153d28'44.39"E, 27d 8' 2.43"S)
            % 153.28 + 44.39 / 60  ::::: 27.8 + 2.43/60
            
            % nums =regexp(substrToProcess,'(\d*)d(\d*)[^0-9]*(\d*\.\d*)[^0-9]*(\d*)[^0-9]*(\d*)[^0-9]*(\d*\.\d*)','tokens')%old
            % does not work if there is a space after 'd' like 114d 1'....
            
            %upLeft
            substrToProcess=geodalinfoOutput_str(UL_Str_idx+length('Upper Left'):LL_Str_idx-1);
            nums = regexp(substrToProcess,'(\d*)d[^0-9]*(\d*)[^0-9]*(\d*\.\d*)[^0-9]*(\d*)d[^0-9]*(\d*)[^0-9]*(\d*\.\d*)','tokens');
            header_data(k,1).upLlon=str2double(nums{1}{1} )+ str2double(nums{1}{2})/60 + str2double(nums{1}{3})/3600;
            header_data(k,1).upLlat=str2double(nums{1}{4} )+ str2double(nums{1}{5})/60 + str2double(nums{1}{6})/3600;
            if ~isempty(strfind(substrToProcess,'S'))
                header_data(k,1).upLlat= -header_data(k,1).upLlat;
            end
            
            %upRight
            substrToProcess=geodalinfoOutput_str(UR_Str_idx+length('Upper Right'):LR_Str_idx-1);
            nums = regexp(substrToProcess,'(\d*)d[^0-9]*(\d*)[^0-9]*(\d*\.\d*)[^0-9]*(\d*)d[^0-9]*(\d*)[^0-9]*(\d*\.\d*)','tokens');
            header_data(k,1).upRlon=str2double(nums{1}{1} )+ str2double(nums{1}{2})/60 + str2double(nums{1}{3})/3600;
            header_data(k,1).upRlat=str2double(nums{1}{4} )+ str2double(nums{1}{5})/60 + str2double(nums{1}{6})/3600;
            if ~isempty(strfind(substrToProcess,'S'))
                header_data(k,1).upRlat= -header_data(k,1).upRlat;
            end
            
            %lowR
            substrToProcess=geodalinfoOutput_str(LR_Str_idx+length('Lower Right'):Center_Str_idx-1);
            nums = regexp(substrToProcess,'(\d*)d[^0-9]*(\d*)[^0-9]*(\d*\.\d*)[^0-9]*(\d*)d[^0-9]*(\d*)[^0-9]*(\d*\.\d*)','tokens');
            header_data(k,1).lowRlon=str2double(nums{1}{1} )+ str2double(nums{1}{2})/60 + str2double(nums{1}{3})/3600;
            header_data(k,1).lowRlat=str2double(nums{1}{4} )+ str2double(nums{1}{5})/60 + str2double(nums{1}{6})/3600;
            if ~isempty(strfind(substrToProcess,'S'))
                header_data(k,1).lowRlat= - header_data(k,1).lowRlat;
            end
            
            
            %lowL
            substrToProcess=geodalinfoOutput_str(LL_Str_idx+length('Lower Left'):UR_Str_idx-1);
            nums = regexp(substrToProcess,'(\d*)d[^0-9]*(\d*)[^0-9]*(\d*\.\d*)[^0-9]*(\d*)d[^0-9]*(\d*)[^0-9]*(\d*\.\d*)','tokens');
            header_data(k,1).lowLlon=str2double(nums{1}{1} )+ str2double(nums{1}{2})/60 + str2double(nums{1}{3})/3600;
            header_data(k,1).lowLlat=str2double(nums{1}{4} )+ str2double(nums{1}{5})/60 + str2double(nums{1}{6})/3600;
            if ~isempty(strfind(substrToProcess,'S'))
                header_data(k,1).lowLlat= - header_data(k,1).lowLlat;
            end
            
            %center
            header_data(k,1).lon_center=(header_data(k,1).upLlon + header_data(k,1).upRlon + header_data(k,1).lowRlon + header_data(k,1).lowLlon)/4;
            header_data(k,1).lat_center=(header_data(k,1).upLlat + header_data(k,1).upRlat + header_data(k,1).lowRlat + header_data(k,1).lowLlat)/4;
            
            
            sizeImage = regexp(geodalinfoOutput_str,'[^0-9]*Size is (\d*)[^0-9]*(\d*)','tokens');
            idxG1 = strfind(geodalinfoOutput_str,'PROJCS[');
            idxG2 = strfind(geodalinfoOutput_str,'GEOGCS');
            
            projection=geodalinfoOutput_str(idxG1+length('PROJCS[')+1:idxG2-length('GEOGCS')-3);
            
            header_data(k,1).Width= str2double(sizeImage{1}{1});
            header_data(k,1).Heigh= str2double(sizeImage{1}{2});
            header_data(k,1).Projection=projection;
            header_data(k,1).GCS='unknown';
            header_data(k,1).image=list_images(j).name;
            
            %         catch ME%if the image is corrupted, it is listed
        else
            eID=eID+1;
            errorID{eID}=list_images(j).name;
        end
        
    end
else
    fprintf('%s - WARNING: No images to process for %s\n',datestr(now), [Campaign '-' Dive]);
    %     fprintf('%s - EXIT FUNCTION\n',datestr(now));
    
    
    header_data=struct;
end

end
