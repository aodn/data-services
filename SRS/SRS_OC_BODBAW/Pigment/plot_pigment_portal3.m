function plot_pigment_portal3(ncFile,filenameCSV)
%% Example to plot a SRS BioOptical Pigment dataset
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  https://github.com/aodn/imos_user_code_library
% May 2013; Last revision: 3-June-2013
%
% Copyright 2013 IMOS
% The script is distributed under the terms of the GNU General Public License
srs_DATA = ncParse(ncFile) ;

nProfiles = length (srs_DATA.dimensions.profile.data);% number of profiles
stationName = srs_DATA.variables.station_name.data;
stationIndex = srs_DATA.variables.station_index.data;

alldepthProf= unique(srs_DATA.variables.DEPTH.data);
alldepthProf= alldepthProf(~isnan(alldepthProf)); % remove nan values of depth
nDepth = length(alldepthProf);

cphl_aData = nan(nProfiles,nDepth);
depth_aData= nan(nProfiles,nDepth);
for ProfileToPlot = 1 : nProfiles
    
    % we look for the observations indexes related to the chosen profile
    indexObservationStart = sum( srs_DATA.variables.rowSize.data(1:ProfileToPlot)) - srs_DATA.variables.rowSize.data(ProfileToPlot) +1;
    indexObservationEnd = sum( srs_DATA.variables.rowSize.data(1:ProfileToPlot));
    indexObservation =  indexObservationStart:indexObservationEnd ;
    
    %only take non NAN values of depth for plotting
    indexObservation=indexObservation(~isnan(srs_DATA.variables.DEPTH.data(indexObservation)));
    
     if ~(length(indexObservation) == 1)
        if ~(length(ismember(alldepthProf,srs_DATA.variables.DEPTH.data(indexObservation))) == length(indexObservation))
            % we re in the case where at the same depth/time/station we can
            % have multiple measurements. in that case, we take only the first
            % observation
            indexObservation =  indexObservationStart ;
        end
    end
    %creation of a cphl_a and depth matrix
    cphl_aData(ProfileToPlot, ismember(alldepthProf,srs_DATA.variables.DEPTH.data(indexObservation))) =    srs_DATA.variables.CPHL_a.data(indexObservation);
    depth_aData(ProfileToPlot, ismember(alldepthProf,srs_DATA.variables.DEPTH.data(indexObservation))) =    srs_DATA.variables.DEPTH.data(indexObservation);
    
    %get the name of the station which matches the profile
    stationNamePerObs{ProfileToPlot} = stationName(stationIndex,:);
end

fh = figure('visible','off');set(fh,'Color',[1 1 1]);%please resize the window manually
set(fh, 'Position', [0 0 700 850])
plot(cphl_aData,'x')

for iiDepth=1:nDepth
    legendDepthString{iiDepth}=strcat('Depth:',num2str(alldepthProf(iiDepth)),'m');
end
legend(legendDepthString)

% legend
set(gca,'XTickLabel',stationNamePerObs,...
    'XTick',[ 1 : nProfiles])

title({srs_DATA.metadata.source ,...
    ['cruise : ' srs_DATA.metadata.cruise_id],...
    ['between:' srs_DATA.metadata.time_coverage_start ' and ' srs_DATA.metadata.time_coverage_end ],...
    'All the profiles from different stations are plotted'})
xlabel([strrep(srs_DATA.variables.station_name.long_name,'_', ' ') ])
ylabel([strrep(srs_DATA.variables.CPHL_a.long_name,'_', ' ') ' in ' srs_DATA.variables.CPHL_a.units ])
rotateXLabels( gca, 30) % rotation of xlabels

[folder,~]=fileparts(ncFile);

mkpath([ strrep(folder,'/NetCDF/', '/exportedPlots/') ])
exportFilename=[ strrep(folder,'/NetCDF/', '/exportedPlots/') filesep filenameCSV(1:end-4) '.png'];
% export_fig (exportFilename)
fig_print(fh,exportFilename) 

close(fh)
