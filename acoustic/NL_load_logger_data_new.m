function [Header, Volts, FSample, Rec_start_time, overload] = NL_load_logger_data_new(FileName, Status)

% NL_load_logger_data_new.m reads noise logger raw (binary) data files 
% FileName is the file name
% Use: [Header, Volts, FSample, Rec_start_time, overload] = NL_load_logger_data(FileName, Status);
% Output:
% 1) Header is an ASCII header of the binary data file;
% 2) Volts is a vector of the signal amplitude in volts at ADC;
% 3) FSample is the sampling frequency in Hz;
% 4) Rec_start_time is the UTC time of the first sample in the recording in
% days re 00:00:00 01/01/0000;
% 5) overload(Channel No) = 1 if the recording channel was saturated (waveform
% truncated), otherwise overload(Cannel No) = 0;

% Modified version of Frank's routine to read binary data files recorded by
% CMST sea noise loggers.
% Calculation of the UTS time of the first sample, including fractions of a
% second, is added;
% A. Gavrilov, CMST, Curtin University, Nov-2012

% Inpit Status is added. If it exists (any number or string), a warning
% message about ADC overload will be displayed
% A. Gavrilov, CMST, Curtin University, Jan-2013

if nargin < 2
    Status = 0;
else
    Status = 1;
end
   
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
szVolts = size(Volts);
overload = [0,0];
for nch = 1:szVolts(2)
    if max(Volts(:,nch)) > 6e4
        overload(nch) = 1;
        if Status
            warndlg('Logger was overloaded - signal is truncated','modal'); 
        end
    end
end
%Convert to Volts
%Modified Franks method
Fullscale = 5;	%0 to 5 V
%Multiply by this factor to convert A/D counts to volts 0-5
CountsToVolts = Fullscale/65536; 
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
	tmp = fgetl(Fid);
    if tmp ~= -1
        Header = strvcat(Header,tmp);
    end
end

% Calculate exact UTC time of the first sample in the recording based on Footer data:
Rec_start_time = datenum(str2num(Header(7,12:15)),str2num(Header(7,17:18)),...
    str2num(Header(7,20:21)), str2num(Header(7,23:24)),str2num(Header(7,26:27)),...
    + str2num(Header(7,29:30))) + str2num(Header(7,34:38))/2^16/24/3600;

fclose(Fid);
