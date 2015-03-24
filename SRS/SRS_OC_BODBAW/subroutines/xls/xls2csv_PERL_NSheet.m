function xls2csv_PERL_NSheet(filenameXLS,Nsheet)
%% xls2csv_PERL_NSheet
% this function convert a XLS file to a CSV file using a PERL package. See
% README for help on installation
% Syntax:  xls2csv_PERL_NSheet(filenameXLS,Nsheet)
%
% Inputs: Nsheet     : the number of sheet in the XLS file to convert
%         filenameXLS: the location of the XLS file
%   
%
% Outputs:
%
% Example: 
%    xls2csv_PERL_NSheet(filenameXLS,Nsheet)
%
% Other m-files
% required:
% Other files required: 
% Subfunctions: none
% MAT-files required: none
%
% See also: 
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2011; Last revision: 28-Nov-2012
% PERL CPAN package

%% convert file into CSV
for iFile=1:Nsheet
    % WINDOWS-1253 for greek http://en.wikipedia.org/wiki/Character_encoding
    filenameCSV=strcat(filenameXLS(1:end-4),'_',num2str(iFile),'out.csv');
    systemCmd = sprintf('xls2csv_bodbaw -x "%s" -f -b WINDOWS-1253 -a UTF-8 -n %d -c "%s"  ;',filenameXLS,iFile,filenameCSV);
    [~,~]=system(systemCmd) ;
    
    filenameCSV2=strcat(filenameXLS(1:end-4),'_',num2str(iFile),'out.csv2');
    
    %% convert double "" from conversion into ####
%     systemCmd = sprintf('sed ''s/"//g'' < "%s" > "%s" ; mv "%s" "%s";',filenameCSV,filenameCSV2,filenameCSV2,filenameCSV);
%     [~,~]=system(systemCmd,'-echo') ;

 %% convert double "" from conversion into ####
systemCmd = sprintf('sed ''s/""/####/g'' < "%s" > "%s" ; mv "%s" "%s";',filenameCSV,filenameCSV2,filenameCSV2,filenameCSV);
[~,~]=system(systemCmd,'-echo') ;

%% convert # from convertion into nothing
systemCmd = sprintf('sed ''s/"//g'' < "%s" > "%s" ; mv "%s" "%s";',filenameCSV,filenameCSV2,filenameCSV2,filenameCSV);
[~,~]=system(systemCmd,'-echo') ;

%% reconvert #### into "
systemCmd = sprintf('sed ''s/####/"/g'' < "%s" > "%s" ; mv "%s" "%s";',filenameCSV,filenameCSV2,filenameCSV2,filenameCSV);
[~,~]=system(systemCmd,'-echo') ;   

end

end

