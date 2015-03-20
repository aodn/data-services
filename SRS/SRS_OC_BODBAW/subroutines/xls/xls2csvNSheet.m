function xls2csv_CATDOC_NSheet(filenameXLS,Nsheet)
% need catdoc  sudo apt-get install catdoc 
% appears to have some problems in 64bits environment

filenameCSV=strcat(filenameXLS(1:end-3),'csv');
filenameCSV2=strcat(filenameXLS(1:end-3),'csv2');
Directory=fileparts(filenameCSV);

%% convert file into CSV
WorksheetSeparator='-END_OF_SHEET-';
systemCmd = sprintf('xls2csv -x "%s"  -c''|'' -d UTF-8 -b "%s" > "%s"  ;',filenameXLS,WorksheetSeparator,filenameCSV);
[~,~]=system(systemCmd) ;


%% remove last line because of bas character
systemCmd = sprintf('sed ''$d'' < "%s" > "%s" ; mv "%s" "%s";',filenameCSV,filenameCSV2,filenameCSV2,filenameCSV);
[~,~]=system(systemCmd,'-echo') ;
%% convert double "" from conversion into ####
systemCmd = sprintf('sed ''s/""/####/g'' < "%s" > "%s" ; mv "%s" "%s";',filenameCSV,filenameCSV2,filenameCSV2,filenameCSV);
[~,~]=system(systemCmd,'-echo') ;

%% convert # from convertion into nothing
systemCmd = sprintf('sed ''s/"//g'' < "%s" > "%s" ; mv "%s" "%s";',filenameCSV,filenameCSV2,filenameCSV2,filenameCSV);
[~,~]=system(systemCmd,'-echo') ;

%% reconvert #### into "
systemCmd = sprintf('sed ''s/####/"/g'' < "%s" > "%s" ; mv "%s" "%s";',filenameCSV,filenameCSV2,filenameCSV2,filenameCSV);
[~,~]=system(systemCmd,'-echo') ;

if Nsheet>1
    
    fid= fopen(filenameCSV);
    
    %% first sheet
    tline = fgetl(fid);
    fid1 = fopen(fullfile(Directory,'1.csv'),'w');
    while isempty(strfind(tline,WorksheetSeparator)) && ischar(tline)
        fprintf(fid1, '%s\n',tline);
        tline = fgetl(fid);
    end
    fclose(fid1);
    
    for ii=2:Nsheet
        fid2 = fopen(fullfile(Directory,strcat(num2str(ii),'.csv')),'w');
        fprintf(fid1, '%s\n',tline(length(WorksheetSeparator)+1:end));
        tline = fgetl(fid);
        
        while isempty(strfind(tline,WorksheetSeparator)) && ischar(tline)
            fprintf(fid2, '%s\n',tline);
            tline = fgetl(fid);
        end
        fclose(fid2);
    end
    
    % %% second sheet
    % fid2 = fopen(fullfile(Directory,'2.csv'),'w');
    % fprintf(fid1, '%s\n',tline(length(WorksheetSeparator)+1:end));
    % tline = fgetl(fid);
    %
    % while isempty(strfind(tline,WorksheetSeparator)) && ischar(tline)
    % fprintf(fid2, '%s\n',tline);
    % tline = fgetl(fid);
    % end
    % fclose(fid2);
    %
    % %% third sheet
    % fid3 = fopen(fullfile(Directory,'3.csv'),'w');
    % fprintf(fid1, '%s\n',tline(length(WorksheetSeparator)+1:end));
    % tline = fgetl(fid);
    %
    % while isempty(strfind(tline,WorksheetSeparator)) && ischar(tline)
    % fprintf(fid3, '%s\n',tline);
    % tline = fgetl(fid);
    % end
    % fclose(fid3);
    
    fclose(fid);
    
    delete(filenameCSV)
end

end

