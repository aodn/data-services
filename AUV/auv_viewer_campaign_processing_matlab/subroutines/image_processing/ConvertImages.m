function ConvertImages(Campaign,Dive)
%ConvertImages convert images never converted before from an AUV campaign into small thumbnails
%readable for the AUV web tool. Each image is reduced by 10% of its
%original size and reshaped as well to increase details. This function runs
%a bash script under linux and need the imagemagick linux package to be already
%installed on the machine
%   http://www.imagemagick.org/script/convert.php.
%
% Inputs:
%   processedDataOutputPath - str pointing to the folder where the user wants to
%                 save the data
%   releasedCampaignPath  - str pointing to the main AUV folder address ( could be
%                 local
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

configFile = dir('config*.txt');
processedDataOutputPath       = readConfig('processedDataOutput.path',configFile(1).name,'=');
releasedCampaignPath          = readConfig('releasedCampaign.path',configFile(1).name,'=');
auvViewerThumbnails_prodDivePath    = [readConfig('auvViewerThumbnails.path', configFile(1).name,'=') filesep Campaign filesep Dive filesep 'i2jpg'];


divePath = (strcat(releasedCampaignPath,filesep,Campaign,filesep,Dive));
TIFF_dir = dir([divePath filesep 'i2*gtif']);
tiffPath = [divePath filesep TIFF_dir.name];
list_images_tiff = dir([tiffPath filesep '*LC16.tif']);

auvViewerThumbnails_WIPDivePath = strcat(processedDataOutputPath,filesep,Campaign,filesep,Dive,filesep,'i2jpg');
mkdir(auvViewerThumbnails_WIPDivePath);

list_imagesNames = cell(length(list_images_tiff),1);
for iListImages = 1 : length(list_images_tiff)
    list_imagesNames{iListImages}  = list_images_tiff(iListImages).name(1:end-4);
end


% list names of images already converted
list_imagesAlreadyProcessed = dir([auvViewerThumbnails_prodDivePath filesep '*LC16.jpg']);
list_imagesAlreadyProcessedNames =  cell(length(list_imagesAlreadyProcessed),1);
for iList_imagesAlreadyProcessed = 1 : length(list_imagesAlreadyProcessed)
    list_imagesAlreadyProcessedNames{iList_imagesAlreadyProcessed}  = list_imagesAlreadyProcessed(iList_imagesAlreadyProcessed).name(1:end-4);
end

% Create a list names of images to convert
ListImageToProcess = setdiff(list_imagesNames,list_imagesAlreadyProcessedNames);
ListImageToProcessPath = cell(length(ListImageToProcess),1);
for iListImageToProcess = 1 :length(ListImageToProcess)
    ListImageToProcessPath{iListImageToProcess} = [tiffPath filesep ListImageToProcess{iListImageToProcess}  '.tif'];
end


reverseStr = ''; % string to show status in printf
if ~isempty(ListImageToProcessPath)
    fprintf('%s - Creating thumbnails for %s\n',datestr(now), [Campaign '-' Dive]);
    
    for t = 1 : length(ListImageToProcessPath)
        % Display the progress
        msg = sprintf('%s - image converted :%d / %d \n',datestr(now),t,length(ListImageToProcessPath)); %Don't forget this semicolon
        fprintf([reverseStr, msg]);
        reverseStr = repmat(sprintf('\b'), 1, length(msg));
        
        systemCmd = sprintf('convert -resize 453x341 -quality 85 -unsharp 1.5×1.0+1.5+0.02 %s %s/%s.jpg ;', ListImageToProcessPath{t}  ,  auvViewerThumbnails_WIPDivePath,ListImageToProcess{t});
        [~,~]=system(systemCmd) ;
    end
else
    fprintf('%s - WARNING: No images to process for %s. Thumbnails not created\n',datestr(now), [Campaign '-' Dive]);
    
end
end
