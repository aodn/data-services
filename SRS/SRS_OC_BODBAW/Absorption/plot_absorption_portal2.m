function plot_absorption_portal2(ncFile,filenameCSV)
%% plot a SRS BioOptical Absorption dataset
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
nObsProfile =1;

stationName = srs_DATA.variables.station_name.data;
stationIndex = srs_DATA.variables.station_index.data;

% if there is only one observation per profile, then there is no point to
% create a 2d plot. so we look for another profile which has more than 1
% observation
while ~(nObsProfile > 1) & ProfileToPlot < nProfiles
    ProfileToPlot = ProfileToPlot +1;
    nObsProfile = srs_DATA.variables.rowSize.data(ProfileToPlot);  %number of observations for ProfileToPlot
end

%if a profile does not have more than one observation, we do another type
%of plot
allVar = fieldnames(srs_DATA.variables);
mainVarAbsortptionStr = {'aph','ag','ad','ap'};
indexMainVarAbs = ismember(mainVarAbsortptionStr,allVar);


if nObsProfile ~=1
    timeProfile = srs_DATA.variables.TIME.data(ProfileToPlot);
    
    % lat and lon depend of station index. while time depends of profile
    latProfile = srs_DATA.variables.LATITUDE.data(stationIndex(ProfileToPlot));
    lonProfile = srs_DATA.variables.LONGITUDE.data(stationIndex(ProfileToPlot));
    
    % we look for the observations indexes related to the chosen profile
    indexObservationStart = sum( srs_DATA.variables.rowSize.data(1:ProfileToPlot)) - srs_DATA.variables.rowSize.data(ProfileToPlot) +1;
    indexObservationEnd = sum( srs_DATA.variables.rowSize.data(1:ProfileToPlot));
    indexObservation =  indexObservationStart:indexObservationEnd ;
    
    % we are looking for the  absorption variable
   
    
    mainVar = double(srs_DATA.variables.(mainVarAbsortptionStr{indexMainVarAbs}).data(indexObservation,:));
    wavelengthData = double(srs_DATA.dimensions.wavelength.data);
    depthData = double(srs_DATA.variables.DEPTH.data(indexObservation));
    
    nDepth = length(depthData);
    fh = figure('visible','off');set(fh,'Color',[1 1 1]);%please resize the window manually
    plot(wavelengthData,mainVar,'x')
    unitsMainVar=char(srs_DATA.variables.(mainVarAbsortptionStr{indexMainVarAbs}).units);
    ylabel( strrep([srs_DATA.variables.(mainVarAbsortptionStr{indexMainVarAbs}).long_name ' in: ', srs_DATA.variables.(mainVarAbsortptionStr{indexMainVarAbs}).units],'_', ' '))
    xlabel( strrep([srs_DATA.dimensions.wavelength.long_name ' in: ', srs_DATA.dimensions.wavelength.units],'_', ' '))
    
    title({strrep(srs_DATA.variables.(mainVarAbsortptionStr{indexMainVarAbs}).long_name,'_',' '),...
        strcat('in units:',srs_DATA.variables.(mainVarAbsortptionStr{indexMainVarAbs}).units),...
        ['cruise :' srs_DATA.metadata.cruise_id],...
        strcat('station :',char(srs_DATA.variables.station_name.data(ProfileToPlot,:)),...
        '- location',num2str(latProfile,'%2.3f'),'/',num2str(lonProfile,'%3.2f') ),...
        strcat('time :',datestr(timeProfile))
        })
    
    for iiDepth=1:nDepth
        legendDepthString{iiDepth}=strcat('Depth:',num2str(depthData(iiDepth)),'m');
    end
    legend(legendDepthString)
else
    % we kind of assume all the depth are the same
    %     ProfileToPlot = 1 : nProfiles;
    
  
    
    
    mainVar = double(srs_DATA.variables.(mainVarAbsortptionStr{indexMainVarAbs}).data);
    wavelengthData = double(srs_DATA.dimensions.wavelength.data);
    depthData = double(srs_DATA.variables.DEPTH.data);
    
    allUniqueDepth = unique(depthData);
    if length(unique(depthData)) == 1
        dephtUsed = allUniqueDepth;
    else
        dephtUsed = allUniqueDepth(1);% we plot only the profiles with depthUsed
    end
    mainVar( depthData ~= dephtUsed ,:) = NaN ;% we only keep data to for depthUsed
    
    
    fh = figure('visible','off');set(fh,'Color',[1 1 1]);%please resize the window manually
    set(fh, 'Position', [0 0 700 850])
    
    plot(wavelengthData,mainVar,'x')
    unitsMainVar=char(srs_DATA.variables.(mainVarAbsortptionStr{indexMainVarAbs}).units);
    ylabel( strrep([srs_DATA.variables.(mainVarAbsortptionStr{indexMainVarAbs}).long_name ' in: ', srs_DATA.variables.(mainVarAbsortptionStr{indexMainVarAbs}).units],'_', ' '))
    xlabel( strrep([srs_DATA.dimensions.wavelength.long_name ' in: ', srs_DATA.dimensions.wavelength.units],'_', ' '))
    
    title({strrep(srs_DATA.variables.(mainVarAbsortptionStr{indexMainVarAbs}).long_name,'_',' '),...
        strcat('in units:',srs_DATA.variables.(mainVarAbsortptionStr{indexMainVarAbs}).units),...
        ['cruise :' srs_DATA.metadata.cruise_id],...
        [ 'Only profiles at depth=' num2str(dephtUsed) 'm are plotted']})
    
    stationName = srs_DATA.variables.station_name.data;
    stationIndex = srs_DATA.variables.station_index.data;
    for ProfileToPlot = 1 : nProfiles
        stationNamePerObs{ProfileToPlot} = strrep(stationName(stationIndex(ProfileToPlot),:),' ','');
    end
    
    for iiStation=1:nProfiles
        legendStationString{iiStation}=strcat('station:' , stationNamePerObs{iiStation});
    end
    legend(legendStationString,'location','EastOutside')
end

[folder,~]=fileparts(ncFile);

mkpath([ strrep(folder,'/NetCDF/', '/exportedPlots/') ])
exportFilename=[ strrep(folder,'/NetCDF/', '/exportedPlots/') filesep filenameCSV(1:end-4) '.png'];
% export_fig (exportFilename)
fig_print(fh,exportFilename) 

close(fh)