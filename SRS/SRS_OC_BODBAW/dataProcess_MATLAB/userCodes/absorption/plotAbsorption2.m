function plotAbsorption2(profileData)
%% plotAbsorption
% This plots profileData previously created by getAbsorptionData.m
% 
%
% Syntax: plotAbsorption1(profileData)
%
% Inputs: profileData   - structure of data created by getAbsorptionData.m
%          
% Outputs: 
%
%
% Example:
%   plotAbsorption1(profileData)
%
% Other m-files
% required:
% Other files required:
% Subfunctions: mkpath
% MAT-files required: none
%
% See also:
%  getAbsorptionInfo,plotAbsorption1,getAbsorptionData
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2011; Last revision: 28-Nov-2012
%
% Copyright 2012 IMOS
% The script is distributed under the terms of the GNU General Public License 

if ~isstruct(profileData),       error('profileData must be a structure');        end


[nWavelength,nDepth]=size(profileData.mainVar);
fh=figure;
set(fh, 'Position',  [1 500 900 500 ], 'Color',[1 1 1]);
% plot(profileData.wavelength,profileData.mainVar,'x')
% unitsMainVar=char(profileData.mainVarAtt.units);
% ylabel( strrep(strcat(profileData.mainVarAtt.varname, ' in: ', unitsMainVar),'_', ' '))
% xlabel( 'wavelength in nm')
% 
% title({strrep(profileData.mainVarAtt.long_name,'_',' '),...
%     strcat('in units:',profileData.mainVarAtt.units),...
%     strcat('station :',profileData.stationName,...
%     '- location',num2str(profileData.latitude,'%2.3f'),'/',num2str(profileData.longitude,'%3.2f') ),...
%     strcat('time :',datestr(profileData.time))
%     })
% 
% for iiDepth=1:nDepth
%     legendDepthString{iiDepth}=strcat('Depth:',num2str(-profileData.depth(iiDepth)),'m');
% end
% legend(legendDepthString)
for iiLambda=1:nWavelength
    legendDepthString{iiLambda}=strcat('Wavelenth:',num2str(profileData.wavelength(iiLambda)),'nm');
    RGB = Wavelength_to_RGB(profileData.wavelength(iiLambda));
    plot(profileData.mainVar(iiLambda,:)',-profileData.depth,'Color',RGB/255)
    hold on
end

legend(legendDepthString,'Location','NorthEastOutside')
unitsMainVar=char(profileData.mainVarAtt.units);
ylabel('depth (m)' )
xlabel( [strrep(profileData.mainVarAtt.varname,'_',' ') ' in ' unitsMainVar])
title({strrep(profileData.mainVarAtt.varname,'_',' '),strrep(profileData.mainVarAtt.long_name,'_',' '),...
    strcat('in units:',profileData.mainVarAtt.units),...
    strcat('station :',profileData.stationName,...
    '- location',num2str(profileData.latitude,'%2.3f'),'/',num2str(profileData.longitude,'%3.2f') ),...
    strcat('time :',datestr(profileData.time))
    })
end