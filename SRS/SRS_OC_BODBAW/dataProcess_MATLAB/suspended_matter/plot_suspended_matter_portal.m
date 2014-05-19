function plot_suspended_matter_portal(ncFile,filenameCSV)
%% Example to plot a SRS BioOptical suspended matter dataset
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
 
stationName = srs_DATA.variables.station_name.data;
stationIndex = srs_DATA.variables.station_index.data;

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
SPM_Data = srs_DATA.variables.SPM.data(indexObservation);  %for ProfileToPlot
depthData = srs_DATA.variables.DEPTH.data(indexObservation);
 


fh = figure;set(fh,'Color',[1 1 1]);%please resize the window manually 
plot (SPM_Data,depthData,'x')
title({srs_DATA.metadata.source ,...
    datestr(timeProfile),...
    ['location:lat=' num2str(latProfile) '; lon=' num2str(lonProfile) ]})
xlabel([strrep(srs_DATA.variables.SPM.long_name,'_', ' ') ' in ' srs_DATA.variables.SPM.units])
ylabel([strrep(srs_DATA.variables.DEPTH.long_name,'_', ' ') ' in ' srs_DATA.variables.DEPTH.units ';positive ' srs_DATA.variables.DEPTH.positive ])

[folder,~]=fileparts(ncFile);

mkpath([ strrep(folder,'/NetCDF/', '/exportedPlots/') ])
exportFilename=[ strrep(folder,'/NetCDF/', '/exportedPlots/') filesep filenameCSV(1:end-4) '.png'];
export_fig (exportFilename)
close(fh)
