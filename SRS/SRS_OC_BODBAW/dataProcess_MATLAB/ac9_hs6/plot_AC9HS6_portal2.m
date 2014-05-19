function plot_AC9HS6_portal2(ncFile,filenameCSV)
%% Example to plot a SRS BioOptical plot_AC9HS6_portal dataset
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  https://github.com/aodn/imos_user_code_library
% May 2013; Last revision: 20-May-2013
%
% Copyright 2013 IMOS
% The script is distributed under the terms of the GNU General Public License

srs_DATA = ncParse(ncFile) ;
 
nProfiles = length (srs_DATA.dimensions.profile.data);% number of profiles 
 
% we choose the first profile
ProfileToPlot = 1; % this is arbitrary. We can plot all profiles from 1 to nProfiles
nObsProfile = srs_DATA.variables.rowSize.data(ProfileToPlot);  %number of observations for ProfileToPlot
timeProfile = srs_DATA.variables.TIME.data(ProfileToPlot);
latProfile = srs_DATA.variables.LATITUDE.data(ProfileToPlot);
lonProfile = srs_DATA.variables.LONGITUDE.data(ProfileToPlot);
 
% we look for the observations indexes related to the chosen profile
indexObservationStart = sum( srs_DATA.variables.rowSize.data(1:ProfileToPlot)) - srs_DATA.variables.rowSize.data(ProfileToPlot) +1;
indexObservationEnd = sum( srs_DATA.variables.rowSize.data(1:ProfileToPlot));
indexObservation =  indexObservationStart:indexObservationEnd ;
 
% we chose arbitrary to plot SPM but there are many more variables
% available
allVar = fieldnames(srs_DATA.variables);
mainVarStr = {'bb_corr','ac9_a_corr'};
indexMainVar = ismember(mainVarStr,allVar);
  
mainVarData = srs_DATA.variables.(mainVarStr{indexMainVar}).data;  %for ProfileToPlot
depthData = srs_DATA.variables.DEPTH.data;
wavelengthData =  srs_DATA.dimensions.wavelength.data;

%% plot many depth in same graph
[nWavelength,~]=size(wavelengthData);
fh=figure('visible','off');
set(fh, 'Position',  [1 500 900 500 ], 'Color',[1 1 1]);

for iiLambda=1:nWavelength
    legendDepthString{iiLambda}=strcat('Wavelength:',num2str(wavelengthData(iiLambda)),'nm');
    RGB = Wavelength_to_RGB(wavelengthData(iiLambda));
    plot(mainVarData(:,iiLambda)',-depthData,'Color',RGB/255)
    hold on
end
% we try to find the minimum depth used ! where there is no nan

nonNanIndex = ~isnan(mainVarData);
[rowF,colF] = find ( nonNanIndex,1,'first');
[rowL,colL] = find ( nonNanIndex,1,'last');
maxDepthUsed = -depthData(rowF);
minDepthUsed =  -depthData(rowL);

if minDepthUsed ~= maxDepthUsed
    ylim([ minDepthUsed maxDepthUsed ])
end
legend(legendDepthString,'Location','NorthEastOutside')
unitsMainVar=char(srs_DATA.variables.(mainVarStr{indexMainVar}).units);
stationNameProfile = srs_DATA.variables.station_name.data(ProfileToPlot,:);

ylabel([strrep(srs_DATA.variables.DEPTH.long_name,'_', ' ') ' in ' srs_DATA.variables.DEPTH.units ';positive ' srs_DATA.variables.DEPTH.positive ])
xlabel( [strrep(srs_DATA.variables.(mainVarStr{indexMainVar}).long_name,'_',' ') ' in ' unitsMainVar])
title({srs_DATA.metadata.source,...
    strrep(srs_DATA.variables.(mainVarStr{indexMainVar}).long_name,'_',' '),...
    strcat('in units:',unitsMainVar),...
    strcat('station :',stationNameProfile,...
    '- location',num2str(latProfile,'%2.3f'),'/',num2str(lonProfile,'%3.2f') ),...
    strcat('time :',datestr(timeProfile))
    })


[folder,~]=fileparts(ncFile);

mkpath([ strrep(folder,'/NetCDF/', '/exportedPlots/') ])
exportFilename=[ strrep(folder,'/NetCDF/', '/exportedPlots/') filesep filenameCSV(1:end-4) '.png'];
% export_fig (exportFilename)
fig_print(fh,exportFilename) 

close(fh)
