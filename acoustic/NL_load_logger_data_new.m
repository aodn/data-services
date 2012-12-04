function [Header, Volts, FSample, Rec_start_time] = NL_load_logger_data_new(FileName)

% NL_load_logger_data.m reads noise logger raw (binary) data file 
% FileName is the file name
% Use: [Header, Volts, FSample, Schedule] = NL_load_logger_data(FileName);
% Output:
% Volts is a vector of the signal amplitude in volts at ADC;
% FSample is the sampling frequency in Hz;
% Header is a ASCII header of the binary data file;
% Rec_start_time it the UTC time of the first sample in the recording in
% hours re 00:00:00 01/01/0000;

% Modified version of Frank's routine to read binary data files recorded by
% CMST sea noise loggers.
% Calculation of the UTS time of the first sample, including fractions of a
% second, is added;

% A. Gavrilov, CMST, Curtin University, Nov-2012
   
NHeader = 5;  % Number of header lines
NMarker = 6; % Number of marker lines
MarkerLength = 14;  % Number of characters in footer
    
HeaderLine = 1;	% stores user input information
ScheduleLine = HeaderLine+1; % line number of the header containing schedule information
RateLine = ScheduleLine+1;  % line number of the header containing sample rate and duration
Filter0Line = RateLine+1; % line number of the header containg filter 0 parameters
Filter1Line = Filter0Line+1; % line number of the header containg filter 1 parameters
SchStart = 10; % character number of start of schedule information
RateStart = 13; % character number of start of sample rate info
NextRateStr = 'Duration';  % string that follows sample rate
PChStart = 13; % character number of start of Primary channel enabled info
SChStart = 18; % character number of start of Secondary channel enabled info
    
Fid = fopen(FileName, 'r', 'b');
Header=[];
for ISub = 1:NHeader
       tmp = fgetl(Fid);
       Header = strvcat(Header,tmp);
end
     
ScheduleStr = Header(ScheduleLine,:);
RateStr = Header(RateLine,:);
Filter0Str = Header(Filter0Line,:);
Filter1Str = Header(Filter1Line,:);
    
% Extract the sampling frequency
EndInd = findstr(NextRateStr,RateStr);
FSample = str2num(RateStr(RateStart : EndInd-1));

%Extract the sample length
zLength = findstr(RateStr,'Duration');
SLength = str2num(RateStr(zLength+9 : end));	

%Extract Filter 0 information
Ch1Enable = str2num(Filter0Str(PChStart:PChStart));
Ch2Enable = str2num(Filter0Str(SChStart:SChStart));
    
%Extract Filter 1 information
Ch3Enable = str2num(Filter1Str(PChStart:PChStart));
Ch4Enable = str2num(Filter1Str(SChStart:SChStart));
    
NumActiveCh = Ch1Enable + Ch2Enable + Ch3Enable + Ch4Enable;
FSample = FSample/NumActiveCh;
NumSamples = ceil(SLength*FSample);

% read data
Volts = fread(Fid, [NumActiveCh,NumSamples], 'uint16');	%not actually volts at this stage
Volts = Volts';

%Convert to Volts
%Modified Franks method
Fullscale = 5;	%0 to 5 V
%Multiply by this factor to convert A/D counts to volts 0-5
CountsToVolts = Fullscale/65536; 
szVolts = size(Volts);
for i=1:szVolts(2);	%need to correct each column
	Volts(:,i) = (CountsToVolts.*Volts(:,i))-mean(Volts(:,i).*CountsToVolts);
end
tmp = fgetl(Fid);
if ~strcmp(tmp,'Record Marker')
    while ~strcmp(tmp,'Record Marker')
        tmp=fgetl(Fid);
    end
end
%read ASCII lines from Footer into Header
fseek(Fid,-MarkerLength,'cof');    
for ISub = 1:NMarker
	tmp=fgetl(Fid);
	Header = strvcat(Header,tmp);
end

% Calculate exact UTC time of the first sample in the recording based on Footer data:
Rec_start_time = datenum(str2num(Header(7,12:15)),str2num(Header(7,17:18)),...
    str2num(Header(7,20:21)), str2num(Header(7,23:24)),str2num(Header(7,26:27)),...
    + str2num(Header(7,29:30))) + str2num(Header(7,34:38))/2^16/24/3600;

fclose(Fid);
