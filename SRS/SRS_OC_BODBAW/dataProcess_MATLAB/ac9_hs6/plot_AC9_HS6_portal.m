function plot_AC9_HS6_portal(ncFile,filenameCSV)
% ncFile
[~,variableInfo,~]=getPigmentInfo(ncFile);

%% choose variable and station. In our example we choose the first variable of sub_array_of_variables, and the first station (stationIndex)
fieldnamesVariable=fieldnames(variableInfo);
array_of_all_variables=1:length(fieldnamesVariable);
indexWavelength=strcmpi('wavelength',fieldnamesVariable);
sub_array_of_variables=array_of_all_variables(setdiff(1:length(array_of_all_variables),[array_of_all_variables(indexWavelength)]));

variable= getfield(variableInfo,char(fieldnamesVariable(sub_array_of_variables(1))));
profileIndex=1;
profileData=getAbsorptionData(ncFile,variable,profileIndex);

%% plot many depth in same graph
[nWavelength,~]=size(profileData.mainVar);
fh=figure;
set(fh, 'Position',  [1 500 900 500 ], 'Color',[1 1 1]);

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
% change axis to get rid of NaN for the Depth
% axis ([ min(min(profileData.mainVar(:,:))) ...
%     max(max(profileData.mainVar(:,:))) ...
%     min(-profileData.depth((~isnan(profileData.mainVar(iiLambda,:) )))) ...
%     max(-profileData.depth((~isnan(profileData.mainVar(iiLambda,:) )))) ])
[folder,~]=fileparts(ncFile);

mkpath([ strrep(folder,'/NetCDF/', '/exportedPlots/') ])
exportFilename=[ strrep(folder,'/NetCDF/', '/exportedPlots/') filesep filenameCSV(1:end-4) '.png'];
export_fig (exportFilename)
close(fh)