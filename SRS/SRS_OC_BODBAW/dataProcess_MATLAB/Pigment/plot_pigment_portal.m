function plot_pigment_portal(ncFile,filenameCSV)
%only first profile
[~,variableInfo,~]=getPigmentInfo(ncFile);


%% choose variable and station. In our example we choose CPHL_c3, and the first station (stationIndex)
fieldnamesVariable=fieldnames(variableInfo);
variable= getfield(variableInfo,char(fieldnamesVariable(1)));
profileIndex=1;

profileData=getPigmentData(ncFile,variable,profileIndex);

%% plot many depth in same graph
fh=figure;
set(fh, 'Position',  [1 500 900 500 ], 'Color',[1 1 1]);
plot(profileData.mainVar,-profileData.depth,'x')
unitsMainVar=char(profileData.mainVarAtt.units);
xlabel( strrep(strcat(profileData.mainVarname, ' in: ', unitsMainVar),'_', ' '))
ylabel( 'Depth in m')

title({strrep(profileData.mainVarAtt.long_name,'_',' '),...
    strcat('in units:',profileData.mainVarAtt.units),...
    strcat('station :',profileData.stationName,...
    '- location',num2str(profileData.latitude,'%2.3f'),'/',num2str(profileData.longitude,'%3.2f') ),...
    strcat('time :',datestr(profileData.time))
    })

[folder,~]=fileparts(ncFile);

mkpath([ strrep(folder,'/NetCDF/', '/exportedPlots/') ])
exportFilename=[ strrep(folder,'/NetCDF/', '/exportedPlots/') filesep filenameCSV(1:end-4) '.png'];
export_fig (exportFilename)
close(fh)