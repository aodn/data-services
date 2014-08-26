function [Header, Volts, FSample, Schedule] = NL_load_logger_data(FileName,timeS)

%Load_LogDataTime.m Loads a logger raw data file 
%[Header, Volts, FSample, Schedule] = Load_LoggerDataNEW(FileName,timeS);
%Volts is a vector of volts at AD convertor
%timeS is required length in s use [] as default to get full record
%FSample is the sampling frequency in Hz

%test
%FileName='d:\robm\otway\loggertest\WNSun_1.dat';
%FileName='c:\robm\ldata\wn130wed21nov.dat';
%timeS=10;
   
NHeader = 5;  %Number of header lines
NMarker = 5; %Number of marker lines
HeaderLength = 207; %Number of characters in header
MarkerLength = 121;  %Number of characters in footer
    
HeaderLine = 1;	%stores user input information
ScheduleLine = HeaderLine+1; %line number of header line containing schedule information
RateLine = ScheduleLine+1;  %Line number of header line containing sample rate and duration
Filter0Line = RateLine+1; %Line number of header line containg filter 0 parameters
Filter1Line = Filter0Line+1; %Line number of header line containg filter 1 parameters
SchStart = 24; % character number of start of schedule information
RateStart = 13; %Character number of start of sample rate info
NextRateStr = 'Duration';  %String that follows sample rate
PChStart = 13; %Character number of start of Primary channel enabled info
SChStart = 18; %Character number of start of Secondary channel enabled info
LFStart = 23; %Character number of start of low frequency cut off info
HFStart = 30; %Character number of start of high frequency cut off info
PGStart = 39; %Character number of start of pre filter gain info
GStart = 45; %Character number of start of post filter gain info
    
EndStr = 'Record Marker';  %String that denotes last record in file
    
Fid = fopen(FileName, 'r', 'b');
Header=[];
for ISub = 1:NHeader
       tmp=fgetl(Fid);
       Header = strvcat(Header,tmp);
end
     
ScheduleStr = Header(ScheduleLine,:);
RateStr = Header(RateLine,:);
Filter0Str = Header(Filter0Line,:);
Filter1Str = Header(Filter1Line,:);
    
%extract which schedule this is
Schedule = str2num(ScheduleStr(SchStart:SchStart));
    
%Extract the sample frequency
EndInd = findstr(NextRateStr, RateStr);
FSample = str2num(RateStr(RateStart:EndInd-1));

%Extract the sample length
zLength = findstr(RateStr,'Duration');
SLength=min([timeS str2num(RateStr(zLength+9:zLength+19))]);	
NumSamples=ceil(SLength*FSample);
    
%Extract Filter 0 information
Ch1Enable = str2num(Filter0Str(PChStart:PChStart));
Ch2Enable = str2num(Filter0Str(SChStart:SChStart));
Ch1Ch2lowFreq = str2num(Filter0Str(LFStart:LFStart+2));
Ch1Ch2highFreq = str2num(Filter0Str(HFStart:HFStart+4));
Ch1Ch2PreGain = str2num(Filter0Str(PGStart:PGStart+2));
Ch2PostGain = str2num(Filter0Str(GStart:GStart+2));
    
%Extract Filter 1 information
Ch3Enable = str2num(Filter1Str(PChStart:PChStart));
Ch4Enable = str2num(Filter1Str(SChStart:SChStart));
Ch3Ch4lowFreq = str2num(Filter1Str(LFStart:LFStart+2));
Ch3Ch4highFreq = str2num(Filter1Str(HFStart:HFStart+4));
Ch3Ch4PreGain = str2num(Filter1Str(PGStart:PGStart+2));
Ch4PostGain = str2num(Filter1Str(GStart:GStart+2));
    
NumActiveCh = Ch1Enable + Ch2Enable + Ch3Enable + Ch4Enable;
FSample = FSample/NumActiveCh;

%Extract the sample length
zLength = findstr(RateStr,'Duration');
SLength=min([timeS str2num(RateStr(zLength+9:zLength+19))]);	
NumSamples=ceil(SLength*FSample);

%read data
PointsToRead=NumActiveCh*NumSamples;
Volts = fread(Fid, [NumActiveCh,PointsToRead], 'uint16');	%not actually volts at this stage
Volts = Volts';

%limit to sample length (as reads text at file end and all samples are diff length)
%Volts=Volts(1:NumSamples,:);
    
%Convert to Volts
%Modified Franks method
Fullscale = 5;	%0 to 5 V
%Multiply by this factor to convert A/D counts to volts 0-5
CountsToVolts = Fullscale/65536; 
szVolts=size(Volts);
for i=1:szVolts(2);	%need to correct each column
	Volts(:,i) = (CountsToVolts.*Volts(:,i))-mean(Volts(:,i).*CountsToVolts);
end
   
%read last few lines into Header
fseek(Fid,-MarkerLength,'eof');    
for ISub = 1:NMarker
	tmp=fgetl(Fid);
	Header=strvcat(Header,tmp);
end

fclose(Fid);