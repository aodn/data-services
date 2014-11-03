function [] = regrid_ANMN_deploy(node,site,deployment,variable_Long)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% devVersion of routine to grid Temperature data from ANMN thermistor measurements
% Create an 30min average aggregated product of ANMN temperature logger
% list of all the NetCDF file in the current directory
% INPUT: 	- Node       : node name 
%			- site       : site code 
%			- deployment :deployment code
%			- frequency  : time step for averaging in minutes
%			- parameter  : variable name to be aggregated
%
%
% 
% BPasquer August 2013
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Set path to files to be process
% get rid of potential space,trailing blank  words
deployment= deblank(deployment); 
node(isspace(node)) = []; site(isspace(site)) = [];

PathToFiles = fullfile('/mnt/opendap/1/IMOS/opendap/ANMN/',node,site,variable_Long);
fListIn = dir(fullfile(PathToFiles,['IMOS_ANMN-',node,'*',site,'-',deployment,'*.nc']));

if isempty(fListIn)
    error([node,'-',site,'-',deployment,' doesn''t exist'])
end

if strcmp(variable_Long,'Temperature'),variable ='TEMP';end

% Generate the regridded product
[Tstamp,Zgrid,IallP,Lat,Lon,freq,nValStep] = agregANMN_v_ave_RegularGrid(PathToFiles,fListIn,variable);

% Time string for outpout file name
Tstart = datestr(Tstamp(1),'yyyymmddTHHMMSSZ');
Tend = datestr(Tstamp(end),'yyyymmddTHHMMSSZ');
Tcreat = local_time_to_utc(now,30);

% Output file Name
fileOut =fullfile(pwd,['IMOS_ANMN-',node,'_',variable_Long,'_',Tstart,'_',site,'_FV02_',site,'-',deployment,'-regridded_END-',Tend,'_C-',Tcreat,'.nc']);
% function to create a netCDF file for a regridded product. 
create_netcdf_deploy_v4nc(PathToFiles,fListIn,fileOut,variable,IallP,Tstamp,Zgrid,node,site,deployment,Lat,Lon,freq,nValStep)

