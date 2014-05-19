function plot_pigment_portal2(ncFile,filenameCSV)
%% Example to plot a SRS BioOptical Pigment dataset
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  https://github.com/aodn/imos_user_code_library
% May 2013; Last revision: 20-May-2013
%
% Copyright 2013 IMOS
% The script is distributed under the terms of the GNU General Public License

srs_DATA = ncParse(ncFile) ;

% nProfiles = length (srs_DATA.dimensions.profile.data);% number of profiles
% % we choose the first profile
% ProfileToPlot = 1; % this is arbitrary. We can plot all profiles from 1 to nProfiles
% nObsProfile = srs_DATA.variables.rowSize.data(ProfileToPlot);  %number of observations for ProfileToPlot
% timeProfile = srs_DATA.variables.TIME.data(ProfileToPlot);
% latProfile = srs_DATA.variables.LATITUDE.data(ProfileToPlot);
% lonProfile = srs_DATA.variables.LONGITUDE.data(ProfileToPlot);
%
% % we look for the observations indexes related to the chosen profile
% indexObservationStart = sum( srs_DATA.variables.rowSize.data(1:ProfileToPlot)) - srs_DATA.variables.rowSize.data(ProfileToPlot) +1;
% indexObservationEnd = sum( srs_DATA.variables.rowSize.data(1:ProfileToPlot));
% indexObservation =  indexObservationStart:indexObservationEnd ;
%
% % we chose arbitrary to plot CPHL_a but there are many more variables
% % available
% cphl_aData = srs_DATA.variables.CPHL_a.data(indexObservation);  %for ProfileToPlot
% depthData = srs_DATA.variables.DEPTH.data(indexObservation);
%
%
%
% fh = figure;set(fh,'Color',[1 1 1]);%please resize the window manually
% plot (cphl_aData,depthData,'x')
% title({srs_DATA.metadata.source ,...
%     datestr(timeProfile),...
%     ['location:lat=' num2str(latProfile) '; lon=' num2str(lonProfile) ]})
% xlabel([strrep(srs_DATA.variables.CPHL_a.long_name,'_', ' ') ' in ' srs_DATA.variables.CPHL_a.units])
% ylabel([strrep(srs_DATA.variables.DEPTH.long_name,'_', ' ') ' in ' srs_DATA.variables.DEPTH.units ';positive ' srs_DATA.variables.DEPTH.positive ])

nProfiles = length (srs_DATA.dimensions.profile.data);% number of profiles

stationName = srs_DATA.variables.station_name.data;
stationIndex = srs_DATA.variables.station_index.data;

fh = figure;set(fh,'Color',[1 1 1]);%please resize the window manually
set(fh, 'Position', [0 0 700 800])
for ProfileToPlot = 1 : nProfiles
    
    % we look for the observations indexes related to the chosen profile
    indexObservationStart = sum( srs_DATA.variables.rowSize.data(1:ProfileToPlot)) - srs_DATA.variables.rowSize.data(ProfileToPlot) +1;
    indexObservationEnd = sum( srs_DATA.variables.rowSize.data(1:ProfileToPlot));
    indexObservation =  indexObservationStart:indexObservationEnd ;
    
    % we chose arbitrary to plot CPHL_a but there are many more variables
    % available
    cphl_aData = srs_DATA.variables.CPHL_a.data(indexObservation);  %for ProfileToPlot
    
    plot (ProfileToPlot,cphl_aData,'x')
    stationNamePerObs{ProfileToPlot} = stationName(stationIndex,:);
    
    hold all    
end



set(gca,'XTickLabel',stationNamePerObs,...
    'XTick',[ 1 : nProfiles])
rotateXLabels( gca, 30) % rotation of xlabels
title({srs_DATA.metadata.source ,...
    ['from the cruise : ' srs_DATA.metadata.cruise_id],...
    ['between:' srs_DATA.metadata.time_coverage_start ' and ' srs_DATA.metadata.time_coverage_end ],...
    'All the profiles from different stations are plotted/Depth values are not represented'})
xlabel([strrep(srs_DATA.variables.station_name.long_name,'_', ' ') ])
ylabel([strrep(srs_DATA.variables.CPHL_a.long_name,'_', ' ') ' in ' srs_DATA.variables.CPHL_a.units ])

[folder,~]=fileparts(ncFile);

mkpath([ strrep(folder,'/NetCDF/', '/exportedPlots/') ])
exportFilename=[ strrep(folder,'/NetCDF/', '/exportedPlots/') filesep filenameCSV(1:end-4) '.png'];
export_fig (exportFilename)
close(fh)
