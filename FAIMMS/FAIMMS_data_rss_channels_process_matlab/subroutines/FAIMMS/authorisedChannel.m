function [channelId_AuthorisedList,newChannelsUnauthorisedList]=authorisedChannel(channelId_FullList,levelQC)
%% authorisedChannel
% This function creates a text files for each levelQC of channels which are
% allowed to be processed. Each time a new channel appears in the RSS, it is
% recommended that the user downloads it manually, and check that
% everything is as required. When the user is happy with it, he has to
% change the respective text file authorisedChannelList_NoQAQC or
% authorisedChannelList_QAQC by replacing no to yes. On the next run, this
% channel will be downloaded. This has been written to avoid mistakes for
% AIMS
%
% Inputs: channelId_FullList        : List of Channels Identifier
%         levelQC                     : double 0 or 1 ( RAW, QAQC)
%   
%
% Outputs: channelId_AuthorisedList        : Array
%    
%
% Example: 
%    [channelId_AuthorisedList,newChannelsUnauthorisedList]=authorisedChannel(channelId_FullList,levelQC)
%
% Other m-files required:
% Other files required: 
% Subfunctions: none
% MAT-files required: none
%
% See also: FAIMMS_processLevel,FAIMMS_Launcher
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 01-Oct-2012
global dataWIP;

delimiter=':';
channelIdlistSorted=sort(str2double(channelId_FullList));
switch levelQC
    case 0
        authorisedChannelList_filetext=fullfile(dataWIP,'authorisedChannelList_NoQAQC.txt');
    case 1
        authorisedChannelList_filetext=fullfile(dataWIP,'authorisedChannelList_QAQC.txt');
end

if exist(authorisedChannelList_filetext,'file')==2
    % read the text file
    fid = fopen(authorisedChannelList_filetext);
    tline = fgetl(fid);
    ii=1;
    while ischar(tline)
        if tline(1)=='#' %comment line starts with #
            %disp(tline);
            tline = fgetl(fid);
        else
            C = textscan(tline, '%s','Delimiter',delimiter) ;
            channelIdListfromFile(ii)=str2double(C{1,1}{1});
            if strcmpi(C{1,1}{2},'yes')
                channelIdBoolean(ii)=1;
            elseif strcmpi(C{1,1}{2},'no')
                channelIdBoolean(ii)=0;
            else
                fprintf('%s - ERROR in authorisedChannelList.txt. Bad option filled manually for channel %d. Has to be change for yes/no only \n',datestr(now), channelIdListfromFile(ii))
            end
            ii=ii+1;
            tline = fgetl(fid);
        end
    end
    
    fclose(fid);
    
    % compare the file with what has been downloaded already
    if sum(channelIdBoolean)==length(channelIdlistSorted)
        
        fprintf('%s - No new channels  \n',datestr(now))
        channelId_AuthorisedList=channelId_FullList;
        newChannelsUnauthorisedList=cell(1,0);
        
    elseif sum(channelIdBoolean) > length(channelIdlistSorted)
        
        fprintf('%s - ERROR: some channels have disapeared from the RSS feed  \n',datestr(now))
        channelId_AuthorisedList=channelId_FullList;
        newChannelsUnauthorisedList=cell(1,0);
        
    elseif sum(channelIdBoolean) < length(channelIdlistSorted)
        
        fprintf('%s - there are new channels available to download. Require manual authorisation\n',datestr(now))
        newChannelsNotYetAccepted=channelIdlistSorted(ismember(channelIdlistSorted,channelIdListfromFile(channelIdBoolean==0)));
        newChannelsJustAppeared=channelIdlistSorted(~ismember(channelIdlistSorted,channelIdListfromFile));
        newChannels=[newChannelsNotYetAccepted;newChannelsJustAppeared];
        
        oldChannels=channelIdlistSorted(ismember(channelIdlistSorted,channelIdListfromFile(channelIdBoolean==1)));
        
        % write new file text
        fid = fopen(authorisedChannelList_filetext, 'w');
        fprintf(fid, '# Channel_Identifier : Authorised(YES/NO)\n');
        newChannelsUnauthorisedList=cell(1,length(newChannels));
        for nnChannel=1:length(newChannels)
            fprintf(fid, '%d : %s\n',newChannels(nnChannel),'no');
            fprintf('%s - channelID %d requires manual authorisation before being downloaded next time\n',datestr(now),newChannels(nnChannel))
            newChannelsUnauthorisedList(nnChannel)={num2str(newChannels(nnChannel))};
        end
        
        channelId_AuthorisedList=cell(1,length(oldChannels));
        for nnChannel=1:length(oldChannels)
            fprintf(fid, '%d : %s\n',oldChannels(nnChannel),'yes');
            channelId_AuthorisedList(nnChannel)={num2str(oldChannels(nnChannel))};
        end
        fclose(fid);
        
        channelId_AuthorisedList=channelId_AuthorisedList';
        newChannelsUnauthorisedList=newChannelsUnauthorisedList';
        
    end
    
else
    % for the first time we authorised all the channels otherwise nothing
    % would be downloaded by the main program
    fid = fopen(authorisedChannelList_filetext, 'w');
    fprintf(fid, '# Channel_Identifier : Authorised(YES/NO)\n');
    for nnChannel=1:length(channelIdlistSorted)
        fprintf(fid, '%d : %s\n',channelIdlistSorted(nnChannel),'yes');
    end
    fclose(fid);
    channelId_AuthorisedList=channelId_FullList;
    newChannelsUnauthorisedList=cell(1,0);
end
end