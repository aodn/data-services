function ConvertImages(AUV_Folder,Save_Folder,Campaign,Dive)
%ConvertImages convert images from an AUV campaign into small thumbnails
%readable for the AUV web tool. Each image is reduced by 10% of its
%original size and reshaped as well to increase details. This function runs
%a bash script under linux and need the imagemagick linux package to be already
%installed on the machine
%   http://www.imagemagick.org/script/convert.php.
%
% Inputs:
%   Save_Folder - str pointing to the folder where the user wants to
%                 save the SQL file.
%   AUV_Folder  - str pointing to the main AUV folder address ( could be
%                 local or on the DF -slow- through a mount.davfs
%   Campaign    - str containing the Campaign name.
%   Dive        - str containing the Dive name.
%
% Outputs:
%
% Author: Laurent Besnard <laurent.besnard@utas,edu,au>
%
%
% Copyright (c) 2010, eMarine Information Infrastructure (eMII) and Integrated
% Marine Observing System (IMOS).
% All rights reserved.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
%
%     * Redistributions of source code must retain the above copyright notice,
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in the
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the eMII/IMOS nor the names of its contributors
%       may be used to endorse or promote products derived from this software
%       without specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.
%
% cd (strcat(AUV_Folder,filesep,Campaign,filesep,Dive))
% TIFF_dir=dir('i2*gtif');
% cd (TIFF_dir.name);

divePath= (strcat(AUV_Folder,filesep,Campaign,filesep,Dive));
TIFF_dir=dir([divePath filesep 'i2*gtif']);
tiffPath=[divePath filesep TIFF_dir.name];

list_images=dir([tiffPath filesep '*LC16.tif']);

JPG=strcat(Save_Folder,filesep,Campaign,filesep,Dive,filesep,'i2jpg');
mkdir(JPG);

if ~isempty(list_images)
    fprintf('%s - Creating thumbnails for %s\n',datestr(now), [Campaign '-' Dive]);
    
    for t=1:length(list_images)
        
        systemCmd = sprintf('convert -resize 453x341 -quality 85 -unsharp 1.5×1.0+1.5+0.02 %s %s/%sjpg ;',[tiffPath filesep list_images(t,1).name],JPG,list_images(t,1).name(1:end-3));
        [~,~]=system(systemCmd) ;
    end
else
    fprintf('%s - WARNING: No images to process for %s. Thumbnails not created\n',datestr(now), [Campaign '-' Dive]);
    %     fprintf('%s - EXIT FUNCTION\n',datestr(now));
    
end
end