function processAC9_HS6(DataFileFolder,csvFile)
%% processAC9_HS6
% this processes a XLS ac9_hs6 file (csvFile) to CSV and NetCDF files. 
% 2 folders are created, 
% -CSV : the content of this folder has to be copied to the public folder
% of the IMOS cloud storage, at this location SRS/BioOptical
% -NetCDF : the content of this folder has to be copied to the opendap folder
% of the IMOS cloud storage, at this location SRS/BioOptical
% 
% A SQL script is also created to load to the IMOS database in oder to
% populate the table used by geoserver. This script has to be loaded
% manually afterwards.
% Finally, the original XLS file stays at the same location.
%
% Syntax: processAC9_HS6(DataFileFolder,csvFile)
%
% Inputs: DATA - structure created by Absorption_CSV_reader
%         METADATA - structure created by Absorption_CSV_reader
%         FileName - filename created by createAbsorptionFilename
%         folderHierarchy - folder structure hierarchy created by createAbsorptionFilename
% Outputs: logfile
%
%
% Example:
%    processAC9_HS6('/this/is/the/folder','absorptionfile.xls')
%
% Other m-files
% required:
% Other files required:config.txt
% Subfunctions: mkpath
% MAT-files required: none
%
% See also:
% Absorption_CSV_reader,createAbsorptionFilename,processAC9_HS6,CreateBioOptical_Absorption_SQL_fromCSV,CreateBioOptical_Absorption_NetCDF
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2011; Last revision: 28-Nov-2012
% Nsheet=str2double(readConfig('xls.ac9_hs6.Nsheet', 'config.txt','='));       %number of working sheet in the xls file

CSVfolder=fullfile(DataFileFolder,'CSV');


%% create the NetCDF file
FilesCSV=dir (strcat(DataFileFolder,filesep,csvFile));
for ii=1:length(FilesCSV)
    filename=fullfile(DataFileFolder,char(FilesCSV(ii).name));
    try
        fprintf('%s +++ Process file %s\n',datestr(now),char(FilesCSV(ii).name))
        
        [DATA,METADATA]=AC9_HS6_CSV_reader(filename);
        [FileNameCSV,FileNameNC,folderHierarchy]=createAC9_HS6Filename(DATA,METADATA);
        
        % H.2.2. Incomplete multidimensional array representation of time series
        % http://cf-pcmdi.llnl.gov/documents/cf-conventions/1.6/aphs02.html
        %         [NCfileName,folderHierarchy]=CreateBioOptical_Absorption_NetCDF(DATA,METADATA);
        CreateBioOptical_AC9_HS6_NetCDF(DATA,METADATA,FileNameNC,folderHierarchy)
        
        %% change csv filename and move to good folder
        mkpath(fullfile(CSVfolder,folderHierarchy))
        copyfile(filename,fullfile(CSVfolder,folderHierarchy,char(FileNameCSV)))
        % here we re-write the CSV so the coma is the default
        % delimiter,because some people don't know how do deal with the
        % |'s one .
%         csvChangeDelimiter(fullfile(CSVfolder,folderHierarchy,char(FileNameCSV)))
        plot_AC9HS6_portal2(fullfile(DataFileFolder,filesep,'NetCDF',filesep,folderHierarchy,filesep,char(FileNameNC)),char(FileNameCSV))
        
    catch
        fprintf('%s - ERROR file %s - REQUIRES DEBUG\n',datestr(now),char(FilesCSV(ii).name))
    end
end


end