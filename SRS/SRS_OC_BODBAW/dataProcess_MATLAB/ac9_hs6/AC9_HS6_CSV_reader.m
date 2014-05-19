function [DATA,METADATA]=AC9_HS6_CSV_reader(FileToConvert)
% FileToConvert ='/home/lbesnard/IMOS/BioOpticalData/MatlabScript/ToConvert/LC_IMOS_SRS-BioOptical_B_FR1097_ag.csv'
% FileToConvert='/home/lbesnard/IMOS/BioOpticalData/TEST_BIO_pigment.csv';
% FileToConvert='/home/lbesnard/IMOS/BioOpticalData/IMOS_FR101997 attribute V2.csv';
% the CSV file is suppose to have three different blocks :'GLOBAL
% ATTRIBUTES', 'TABLE COLUMNS' and 'DATA' .
%
% field delimiter : ,
% Text delimiter : nothing

fid = fopen(FileToConvert);

%% Beginning of 'Global Attributes' Block
tline = fgetl(fid);
while isempty(strfind(tline,'GLOBAL ATTRIBUTES'))
    tline = fgetl(fid);
end

delimiter=','; %csv delimiter


%% Metadata
ii=1;
if ~isempty(strfind(tline,'GLOBAL ATTRIBUTES'))
    tline = fgetl(fid);
    
    while isempty(strfind(tline,'TABLE ROWS')) && length(strfind(tline,'|'))~=length(tline) % Condition for the next block
        %                 disp(tline)
        C = textscan(tline, '%s','Delimiter',delimiter) ;
        AttName{ii}={C{1,1}{1,1}};
        
        % in case there is no attribute name, the cell would have a size
        % equal to 1 only
        if size(C{1},1)>1
            AttVal{ii}={C{1,1}{2,1}};
        else
            AttVal{ii}=[];
        end
        
        ii=ii+1;
        tline = fgetl(fid);
    end
    %     fclose(fid);
else
    disp('bad file format')
    return
end


%% add legacy filename to the attributes.
[~, legacyFilename, ~] = fileparts(FileToConvert) ;
AttName{end+1} = {'Legacy_file'};
AttVal{end+1} = {legacyFilename};

METADATA=struct;
METADATA.gAttName=AttName;
METADATA.gAttVal=AttVal;

DATA=struct;

%% Beginning of 'TABLE ROWS' Block
while isempty(strfind(tline,'TABLE ROWS'))
    tline = fgetl(fid);
end

%% Variables Attributes
ii=1;
tline = fgetl(fid);
if ~isempty(strfind(tline,strcat('Row name',delimiter,'CF standard_name',delimiter,'IMOS long_name',delimiter,'Units',delimiter,'Fill value',delimiter,'Comments')))
    tline = fgetl(fid);
    
    while isempty(strfind(tline,'TABLE COLUMNS'))   && length(strfind(tline,delimiter))~=length(tline) % Condition for the next block
        %                 disp(tline)
        C = textscan(tline, '%s','Delimiter',delimiter) ;
        VarName_Row{ii}={C{1,1}{1,1}};
        VarStandard_Name_Row{ii}={C{1,1}{2,1}};
        VarLong_Name_Row{ii}={C{1,1}{3,1}};
        VarUnits_Row{ii}={C{1,1}{4,1}};
        VarFillValue_Row{ii}={C{1,1}{5,1}};
        
        if size(C{1},1)>5
            VarComments_Row{ii}={C{1,1}{6,1}};
        else
            VarComments_Row{ii}=[];
        end
        
        
        ii=ii+1;
        tline = fgetl(fid);
    end
    %     fclose(fid);
else
    disp('bad file format')
    return
end


DATA.VarName_Row=VarName_Row;
DATA.Standard_Name_Row=VarStandard_Name_Row;
DATA.Long_Name_Row=VarLong_Name_Row;
DATA.Units_Row=VarUnits_Row;
DATA.FillValue_Row=VarFillValue_Row;
DATA.Comments_Row=VarComments_Row;

%% Beginning of 'TABLE COLUMNS' Block
while isempty(strfind(tline,'TABLE COLUMNS'))
    tline = fgetl(fid);
end

%% Variables Attributes
ii=1;
tline = fgetl(fid);
if ~isempty(strfind(tline,strcat('Column name',delimiter,'CF standard_name',delimiter,'IMOS long_name',delimiter,'Units',delimiter,'Fill value',delimiter,'Comments')))
    tline = fgetl(fid);
    
    while isempty(strfind(tline,'DATA'))   && length(strfind(tline,delimiter))~=length(tline) % Condition for the next block
        %         disp(tline)
        C = textscan(tline, '%s','Delimiter',delimiter) ;
        VarName_Column{ii}={C{1,1}{1,1}};
        VarStandard_Name_Column{ii}={C{1,1}{2,1}};
        VarLong_Name_Column{ii}={C{1,1}{3,1}};
        VarUnits_Column{ii}={C{1,1}{4,1}};
        VarFillValue_Column{ii}={C{1,1}{5,1}};
        
        if size(C{1},1)>5
            VarComments_Column{ii}={C{1,1}{6,1}};
        else
            VarComments_Column{ii}=[];
        end
        
        ii=ii+1;
        tline = fgetl(fid);
    end
    %     fclose(fid);
else
    disp('bad file format')
    return
end
clear C

DATA.VarName_Column=VarName_Column;
DATA.Standard_Name_Column=VarStandard_Name_Column;
DATA.Long_Name_Column=VarLong_Name_Column;
DATA.Units_Column=VarUnits_Column;
DATA.FillValue_Column=VarFillValue_Column;
DATA.Comments_Column=VarComments_Column;



%% Beginning of 'DATA' Block
while isempty(strfind(tline,'DATA'))
    tline = fgetl(fid);
end

%% Var column DATA
VariableNames_Column=[DATA.VarName_Column{:}]';
VariableNames_Column=strrep(VariableNames_Column,' ','_');

% 
% if sum(strcmpi(VariableNames_Column, 'ac9_a_corr'))==1
%     IndexMainVariable= strcmpi(VariableNames_Column, 'ac9_a_corr');
% elseif sum(strcmpi(VariableNames_Column, 'ac9_c_corr'))==1
%     IndexMainVariable= strcmpi(VariableNames_Column, 'ac9_c_corr');
% elseif sum(strcmpi(VariableNames_Column, 'bb_corr'))==1
%     IndexMainVariable= strcmpi(VariableNames_Column, 'bb_corr');
% elseif sum(strcmpi(VariableNames_Column, 'bb_uncorr'))==1
%     IndexMainVariable= strcmpi(VariableNames_Column, 'bb_uncorr');
% end

%% Var Row DATA

VariableNames_Row=[DATA.VarName_Row{:}]';
VariableNames_Row=strrep(VariableNames_Row,' ','_');
IndexWavelengthVariable= strcmpi(VariableNames_Row, 'Wavelength');


tline = fgetl(fid);
% NumberMainVariable=length(strfind(tline,char(DATA.VarName_Column{IndexMainVariable})));
% NumberWavelengthVariable=length(strfind(tline,char(DATA.VarName_Row{IndexWavelengthVariable})));


%% Check the number of Variables we have on the line
% A=regexp(tline,'\w','end');
% nDelimiter=length(strfind(tline(1:A(end)),delimiter));
% if tline(1)==delimiter && tline(A(end))~=delimiter
%     nVarLine=nDelimiter;
% elseif tline(1)==delimiter && tline(A(end))==delimiter
%     nVarLine=nDelimiter-1;
% elseif tline(1)~=delimiter && tline(A(end))==delimiter
%     nVarLine=nDelimiter;
% elseif tline(1)~=delimiter && tline(A(end))~=delimiter
%     nVarLine=1;
% end
% 
% if sum(NumberWavelengthVariable+NumberMainVariable)==nVarLine
    
 C = textscan(tline, '%s','Delimiter',delimiter) ;
        varnameLine_Row{1}={C{1,1}{7:end,1}};% 7:end because the variable name start at the 7th column
        varnameLine_Row{1}=varnameLine_Row{1}(~cellfun('isempty',varnameLine_Row{1}));
        clear C
 tline = fgetl(fid);
        
        C = textscan(tline, '%s','Delimiter',delimiter) ;
        varnameLine_Row{2}={C{1,1}{3:end,1}};% 3:end because the values start at the 3rd column
        varnameLine_Row{2}=varnameLine_Row{2}(~cellfun('isempty',varnameLine_Row{2}));
%     for tt=1:length(DATA.VarName_Row)
%         tline = fgetl(fid);
%         
%         C = textscan(tline, '%s','Delimiter',delimiter) ;
%         DataValues_Row{tt}={C{1,1}{3:end,1}};% 3:end because the values start at the 3rd column
%         DataValues_Row{tt}=DataValues_Row{tt}(~cellfun('isempty',DataValues_Row{tt}));
%     end
%     tline = fgetl(fid);
% else
%     disp('bad file format, the Variable line does not match the with the variable list from the upper block')
%     return
% end

DATA.Values_Row=varnameLine_Row;

% DATA.Values_Row=DataValues_Row;

%% Var Column DATA
 tline = fgetl(fid);
ii=1;
while ischar(tline) && ~isempty(regexp(tline,'\d', 'once')) && length(strfind(tline,'|'))~=length(tline)% last block
    %         disp(tline)
    C = textscan(tline, '%s','Delimiter',delimiter) ;
    DataValues_Column{ii}={C{1,1}{2:end,1}};% 2:end because the values start at the 2nd column
    ii=ii+1;
    tline = fgetl(fid);
end
fclose(fid);

NumberWavelengthVariable=length(varnameLine_Row{1});

NumberMainVariable=5;%Time Station_Code Latitude Longitude Depth

NVar_Column=NumberWavelengthVariable+NumberMainVariable;
NlinesData_Column=length(DataValues_Column);
VAL_Column=cell(NVar_Column,NlinesData_Column);
%don't know how to vectorize this
for ii=1:NVar_Column
    for jj=1:NlinesData_Column
        VAL_Column{ii,jj}=DataValues_Column{:,jj}{ii};
    end
end
VAL_Column=VAL_Column';

DATA.Values_Column=VAL_Column;


clearvars -except DATA METADATA










