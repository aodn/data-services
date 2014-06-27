function [START,STOP,Last2Delete]= ListFileDate (PreviousDateDownloaded,DateAvailable)
% ListFileDate creates a list of monthly files to download for each channel
%
%
% Inputs:
%   PreviousDateDownloaded  -last downloaded date
%   DateAvailable           -last available date
%
% Outputs:
%   START        - Cell array of the first date to download of one month
%   STOP         - Cell array of the last date to download of the same
%                  month
%   Last2Deletel - boolean to know if we need to delete the last downloaded
%                  NetCDF file
%
%
% See also:downloadChannelFAIMMS,FAIMMS_processLevel
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 01-Oct-2012


[yPrevious, mPrevious, dPrevious, hhPrevious]=datevec(PreviousDateDownloaded,'yyyy-mm-ddTHH:MM:SS');
[yNow, mNow, dNow , hhnow,mmnow,ssnow]=datevec(DateAvailable,'yyyy-mm-ddTHH:MM:SS');

START=[];
STOP=[];
i=1;
Last2Delete=0;

%% If the last downloaded file has the same year that the new available one
if yNow==yPrevious
    if mNow==mPrevious
        if dNow>dPrevious
            START{i}=strcat(datestr(datenum([ yNow mNow 01]), 'yyyy-mm-dd'),'T00:00:00Z');
            STOP{i}=strcat(datestr(datenum([ yNow mNow dNow hhnow mmnow ssnow ]), 'yyyy-mm-ddTHH:MM:SS'),'Z');
            
            %             Last2Delete=1;
            i=i+1;
            
        elseif dNow==dPrevious && hhnow> hhPrevious
            START{i}=strcat(datestr(datenum([ yNow mNow 01]), 'yyyy-mm-dd'),'T00:00:00Z');
            STOP{i}=strcat(datestr(datenum([ yNow mNow dNow hhnow mmnow ssnow ]), 'yyyy-mm-ddTHH:MM:SS'),'Z');
            
            %             Last2Delete=1;
            i=i+1;
        end
        
    elseif mNow>mPrevious
        while mPrevious < mNow
            START{i}=strcat(datestr(datenum([ yNow mPrevious 01]), 'yyyy-mm-dd'),'T00:00:00Z');
            STOP{i}=strcat(datestr(datenum([ yNow mPrevious+1 01]), 'yyyy-mm-dd'),'T00:00:00Z');
            mPrevious=mPrevious+1;
            i=i+1;
        end
        
        START{i}=strcat(datestr(datenum([ yNow mNow 01]), 'yyyy-mm-dd'),'T00:00:00Z');
        STOP{i}=strcat(datestr(datenum([ yNow mNow dNow hhnow mmnow ssnow ]), 'yyyy-mm-ddTHH:MM:SS'),'Z');
        
        i=i+1;
    end
    
    
    %% If the last downloaded file has not the same year that the new available one
elseif yNow > yPrevious
    while yNow>yPrevious
        if mPrevious < 12
            while mPrevious<12
                START{i}=strcat(datestr(datenum([ yPrevious mPrevious 01]), 'yyyy-mm-dd'),'T00:00:00Z');
                STOP{i}=strcat(datestr(datenum([ yPrevious mPrevious+1 01]), 'yyyy-mm-dd'),'T00:00:00Z');
                mPrevious=mPrevious+1;
                i=i+1;
            end
            
        elseif mPrevious == 12
            START{i}=strcat(datestr(datenum([ yPrevious mPrevious 01]), 'yyyy-mm-dd'),'T00:00:00Z');
            STOP{i}=strcat(datestr(datenum([ yPrevious+1 01 01]), 'yyyy-mm-dd'),'T00:00:00Z');
            i=i+1;
            yPrevious=yPrevious+1;
            mPrevious=1;
            dPrevious=1;
        end
    end
    
    % COPY AND PASTE FROM THE UPPER CODE
    if mNow==mPrevious
        if dNow>dPrevious
            START{i}=strcat(datestr(datenum([ yNow mNow 01]), 'yyyy-mm-dd'),'T00:00:00Z');
            STOP{i}=strcat(datestr(datenum([ yNow mNow dNow hhnow mmnow ssnow ]), 'yyyy-mm-ddTHH:MM:SS'),'Z');
            i=i+1;
            
        elseif dNow==dPrevious && hhnow> hhPrevious
            START{i}=strcat(datestr(datenum([ yNow mNow 01]), 'yyyy-mm-dd'),'T00:00:00Z');
            STOP{i}=strcat(datestr(datenum([ yNow mNow dNow hhnow mmnow ssnow ]), 'yyyy-mm-ddTHH:MM:SS'),'Z');
            
            i=i+1;
        end
        
    elseif mNow>mPrevious
        while mPrevious < mNow
            START{i}=strcat(datestr(datenum([ yNow mPrevious 01]), 'yyyy-mm-dd'),'T00:00:00Z');
            STOP{i}=strcat(datestr(datenum([ yNow mPrevious+1 01]), 'yyyy-mm-dd'),'T00:00:00Z');
            mPrevious=mPrevious+1;
            i=i+1;
        end
        
        START{i}=strcat(datestr(datenum([ yNow mNow 01]), 'yyyy-mm-dd'),'T00:00:00Z');
        STOP{i}=strcat(datestr(datenum([ yNow mNow dNow hhnow mmnow ssnow ]), 'yyyy-mm-ddTHH:MM:SS'),'Z');
        
        i=i+1;
    end
    
end

if ~isempty(START) && ~isempty(STOP)
    if (datenum(START{1},'yyyy-mm-ddTHH:MM:SS') < datenum(PreviousDateDownloaded,'yyyy-mm-ddTHH:MM:SS')) && (datenum(PreviousDateDownloaded,'yyyy-mm-ddTHH:MM:SS') < datenum(STOP{1},'yyyy-mm-ddTHH:MM:SS'))
        Last2Delete=1;
    else
        Last2Delete=0;
    end
end