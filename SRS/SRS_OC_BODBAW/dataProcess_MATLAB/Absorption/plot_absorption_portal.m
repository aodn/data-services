function plot_absorption_portal(ncFile,filenameCSV)
% ncFile
% [~,variableInfo,~]=getPigmentInfo(ncFile);

[~,variableInfo,~]=getAbsorptionInfo(ncFile);

%% choose variable and station. In our example we choose CPHL_c3, and the first station (stationIndex)
fieldnamesVariable=fieldnames(variableInfo);
array_of_all_variables=1:length(fieldnamesVariable);
indexWavelength=strcmpi('wavelength',fieldnamesVariable);
sub_array_of_variables=array_of_all_variables(setdiff(1:length(array_of_all_variables),[array_of_all_variables(indexWavelength)]));

variable= getfield(variableInfo,char(fieldnamesVariable(sub_array_of_variables)));
profileIndex=1;
profileData=getAbsorptionData(ncFile,variable,profileIndex);

%% plot many depth in same graph
[nWavelength,nDepth]=size(profileData.mainVar);
fh=figure('visible','off');
set(fh, 'Position',  [1 500 900 500 ], 'Color',[1 1 1]);
plot(profileData.wavelength,profileData.mainVar,'x')
unitsMainVar=char(profileData.mainVarAtt.units);
ylabel( strrep(strcat(profileData.mainVarAtt.varname, ' in: ', unitsMainVar),'_', ' '))
xlabel( 'wavelength in nm')

title({strrep(profileData.mainVarAtt.long_name,'_',' '),...
    strcat('in units:',profileData.mainVarAtt.units),...
    strcat('station :',profileData.stationName,...
    '- location',num2str(profileData.latitude,'%2.3f'),'/',num2str(profileData.longitude,'%3.2f') ),...
    strcat('time :',datestr(profileData.time))
    })

for iiDepth=1:nDepth
    legendDepthString{iiDepth}=strcat('Depth:',num2str(-profileData.depth(iiDepth)),'m');
end
legend(legendDepthString)

[folder,~]=fileparts(ncFile);

mkpath([ strrep(folder,'/NetCDF/', '/exportedPlots/') ])
exportFilename=[ strrep(folder,'/NetCDF/', '/exportedPlots/') filesep filenameCSV(1:end-4) '.png'];
% export_fig (exportFilename)
fig_print(fh,exportFilename) 

close(fh)