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

% Input Status is added. If it exists (any number or string), a warning
% message about ADC overload will be displayed
% A. Gavrilov, CMST, Curtin University, Jan-2013

if nargin < 2
    Status = 0;
else
    Status = 1;
end
   
NHeader         = 5;	% Number of header lines
NMarker         = 6;    % Number of marker lines
MarkerLength    = 14;	% Number of characters in footer
    
HeaderLine      = 1;                % stores user input information
ScheduleLine    = HeaderLine + 1;	% line number of the header containing schedule information
RateLine        = ScheduleLine + 1;	% line number of the header containing sample rate and duration
Filter0Line     = RateLine + 1;     % line number of the header containg filter 0 parameters
Filter1Line     = Filter0Line + 1;	% line number of the header containg filter 1 parameters

SchStart    = 10; % character number of start of schedule information
RateStart   = 13; % character number of start of sample rate info

NextRateStr = 'Duration';  % string that follows sample rate

PChStart    = 13; % character number of start of Primary channel enabled info
SChStart    = 18; % character number of start of Secondary channel enabled info
    
Fid = fopen(FileName, 'r', 'b');

Header = textscan(Fid, '%s', NHeader, 'Delimiter', '', 'EndOfLine', '\r\n');
fseek(Fid, +1, 'cof'); % textscan behaves slightly differently from fgetl and a +1 offset is needed
Header = Header{1};

ScheduleStr = Header{ScheduleLine};
RateStr     = Header{RateLine};
Filter0Str  = Header{Filter0Line};
Filter1Str  = Header{Filter1Line};
    
% Extract the sampling frequency
EndInd = strfind(RateStr, NextRateStr);

FSample = str2double(RateStr(RateStart : EndInd-1));

%Extract the sample length
zLength = strfind(RateStr, 'Duration');
SLength = str2double(RateStr(zLength+9 : end));	

%Extract Filter 0 information
Ch1Enable = str2double(Filter0Str(PChStart:PChStart));
Ch2Enable = str2double(Filter0Str(SChStart:SChStart));
    
%Extract Filter 1 information
Ch3Enable = str2double(Filter1Str(PChStart:PChStart));
Ch4Enable = str2double(Filter1Str(SChStart:SChStart));
    
NumActiveCh = Ch1Enable + Ch2Enable + Ch3Enable + Ch4Enable;
FSample = FSample/NumActiveCh;
NumSamples = ceil(SLength*FSample);

% read data
Volts = fread(Fid, [NumSamples, NumActiveCh], 'uint16');	%not actually volts at this stage

%Convert to Volts
%Modified Franks method
Fullscale = 5;	%0 to 5 V
%Multiply by this factor to convert A/D counts to volts 0-5
CountsToVolts = Fullscale/65536; 

overload = [0,0];
%need to correct each column
for i = 1:NumActiveCh
    if max(Volts(:,i)) > 6e4
        overload(i) = 1;
        if Status
            warndlg(['Logger was overloaded (channel ', num2str(i), ') - signal is truncated'],'modal'); 
        end
    end
    Volts(:,i) = (CountsToVolts.*Volts(:,i)) - mean(Volts(:,i).*CountsToVolts);
end

Footer = textscan(Fid, '%s', 'Delimiter', '', 'EndOfLine', '\r\n');
fclose(Fid);

Footer = Footer{1};
nStartFooter = find(strcmp(Footer, 'Record Marker'));
if isempty(nStartFooter)
    disp(['Warning: first attempt to find Record Marker in ' FileName ' failed.']);
    Fid = fopen(FileName, 'r', 'b');
    Footer = textscan(Fid, '%s', 'Delimiter', '', 'EndOfLine', '\r\n');
    fclose(Fid);
    Footer = Footer{1};
    nStartFooter = find(strcmp(Footer, 'Record Marker'));
end
Footer = Footer(nStartFooter:end);

%read ASCII lines from Footer into Header
Header = [Header; Footer];

% Calculate exact UTC time of the first sample in the recording based on Footer data:
Rec_start_timeStr       = Header{7};
Rec_start_time_localStr = Rec_start_timeStr(12:30);
Rec_start_time_zoneStr  = Rec_start_timeStr(34:38);

Rec_start_time_local    = datenum(Rec_start_time_localStr, 'yyyy/mm/dd HH:MM:SS');
Rec_start_time_zone     = str2double(Rec_start_time_zoneStr)/2^16/24/3600;
Rec_start_time          = Rec_start_time_local + Rec_start_time_zone;
