function configplot = read_ConfigPlot(file)
%readConfigPlot returns a structure containing a series of configuration values 
%for plotting function from the given file. 
%
%Inputs:
%   file  - Optional. Name of the config file. Must be specified relative 
%           to the current folder. Defaults to 'config.txt'.
%
if ~exist('file',  'var'), file  = 'configPLOT.txt'; end
%
propFilePath = pwd;
% read in all the deployments
fid = fopen([propFilePath filesep file], 'rt');
if fid == -1, error(['could not open ' file]); end
%
configList = textscan(fid,'%s %s %s %f %s %f %s %f %s %f %s %f','delimiter',',','CommentStyle', '#');
%
if ~isempty(configList)
configplot.deployid = configList{1};
configplot.standard =  configList{2};
for i=1:10
configplot.vp1 =  [configList{3} configList{4}] ;
configplot.vp2 =  [configList{5} configList{6}] ;
configplot.vp3 =  [configList{7} configList{8}] ;
configplot.vp4 =  [configList{9} configList{10}] ;
configplot.vp5 =  [configList{11} configList{12}] ;
end
else 
%NO PARAMETER SET FOR DEPLOYMENT, STANDARD VAL ASSIGNED
configplot.deployid = [];
configplot.standard = TRUE;
end





