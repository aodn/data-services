function report(level)
Tenhours=datenum(0,0,0,10,0,0);


global FAIMMS_DownloadFolder;
global DataFabricFolder;

DATE_PROGRAM_LAUNCHED=strrep(datestr(now,'yyyymmdd_HHAM'),' ','');%the code can be launch everyhour if we want

switch level
    case 0
        levelVersion='FV00';
    case 1
        levelVersion='FV01';
end

XML=strcat('http://data.aims.gov.au/gbroosdata/services/rss/netcdf/level',num2str(level),'/1') ;     %XML file downloaded from the FAIMMS RSS feed

if exist(fullfile(FAIMMS_DownloadFolder,'PreviousDownload.mat'),'file')
    load (fullfile(FAIMMS_DownloadFolder,'PreviousDownload.mat'))
end

%% Load the RSS feed into a structure
filenameXML=fullfile(FAIMMS_DownloadFolder,strcat('/FAIMMS_RSS_',DATE_PROGRAM_LAUNCHED,'_',num2str(level),'.xml'));
urlwrite(XML, filenameXML);
V = xml_parseany(fileread(filenameXML));                                    %Create the structure from the XML file
delete(filenameXML);
[~,b]=size(V.channel{1,1}.item);                                            %Number of channels available


%% initialise MaxChannelValue with b to find the highest value of the ChannelId
channelId=cell(b,1);
MaxChannelValue=b;
for i=1:b
    channelId{i}=V.channel{1,1}.item{1,i}.channelId{1,1}.CONTENT;
    if MaxChannelValue < str2double(channelId{i});
        MaxChannelValue = str2double(channelId{i});
    end
end


%% preallocation
fromDate=cell(MaxChannelValue,1);
thruDate=cell(MaxChannelValue,1);
metadata_uuid=cell(MaxChannelValue,1);


%% Create a list of Channel ID sync with the type of the sensor ( pole, buoy or weather station), lat, long, metadata_UUID...
for i=1:b
    k=str2double(channelId{i});
    metadata_uuid{k}=V.channel{1,1}.item{1,i}.metadataLink{1,1}.CONTENT;
end

FAIMMS_Data_Folder=strcat(DataFabricFolder,'opendap/FAIMMS/');
%% Create a list of dates to download for each channel
for i=1:length(channelId)
    k=str2double(channelId{i});
    [ate]=find(ismember(str2double(channelId), k)==1);
    
    %in case one channel is subdivised when a channel is off for
    %maintenance
    if size(ate,1)>1
        
        %         for j=1:size(ate,1)
        %             fromDate_bis{j}=V.channel{1,1}.item{1,ate(j)}.fromDate{1,1}.CONTENT;
        %             thruDate_bis{j}=V.channel{1,1}.item{1,ate(j)}.thruDate{1,1}.CONTENT;
        %         end
        %
        %         indexfirst=whichisfirst(fromDate_bis);
        %         fromDate{k}=V.channel{1,1}.item{1,ate(indexfirst)}.fromDate{1,1}.CONTENT;%% in UTC
        %
        %         indexlast=whichislast(thruDate_bis);
        %
        %         thruDate{k}=V.channel{1,1}.item{1,ate(indexlast)}.thruDate{1,1}.CONTENT;%% in UTC
        
        disp('RSS feed is corrupted, more than one entry per channel')
        
        break
    elseif isempty(ate)
        continue
        
    else
        k=str2double(channelId{ate(1)});
        fromDate{k}=V.channel{1,1}.item{1,i}.fromDate{1,1}.CONTENT;
        thruDate{k}=V.channel{1,1}.item{1,i}.thruDate{1,1}.CONTENT;
        parameterType{k}=V.channel{1,1}.item{1,i}.parameterType{1,1}.CONTENT;
        parameterType{k}=strrep(parameterType{k}, ' ', '_'); %remove blank character
    end
    
    
    
    if level==0
        try
            if isempty(PreviousDateDownloaded_lev0{k})
                PreviousDateDownloaded_lev0{k}=fromDate{k};
            end
        catch %#ok
            PreviousDateDownloaded_lev0{k}=fromDate{k};
            PreviousDownloadedFile_lev0{k}=[];
        end
    end
    
    if level==1
        try
            if isempty(PreviousDateDownloaded_lev1{k})
                PreviousDateDownloaded_lev1{k}=fromDate{k};
            end
        catch %#ok
            PreviousDateDownloaded_lev1{k}=fromDate{k};
            PreviousDownloadedFile_lev1{k}=[];
        end
    end
    
    clear ate fromDate_bis thruDate_bis
end


deployments= dir(strcat(DataFabricFolder,'opendap/FAIMMS/'));
for dd=3:length(deployments)
    indexi=0;
    % for dd=3
    
    sites = dir(strcat(FAIMMS_Data_Folder,deployments(dd).name));
    for ss=3:length(sites)
        indexi=indexi+1;
        
        [~,~,Names]=DIRR(strcat(FAIMMS_Data_Folder ...
            ,deployments(dd).name,filesep,sites(ss).name),'.nc','name','isdir','1');
        
        
        X=struct;
        Y1=struct;
        Y2=struct;
        metaLongname=struct;
        metaChannel=struct;
        for jj=1:length(Names)
            
            if strcmp(Names{jj}(end-2:end),'.nc') && ~isempty(strfind(Names{jj},levelVersion))
                nc = netcdf.open(Names{jj},'NC_NOWRITE');
                
                long_name = netcdf.getAtt(nc,0,'long_name');
                long_name=strrep(long_name, ' ', '_');
                channelId=netcdf.getAtt(nc,netcdf.getConstant('NC_GLOBAL'),'aims_channel_id');
                %         metadata_uuid=netcdf.getAtt(nc,netcdf.getConstant('GLOBAL'),'metadata_uuid');
                date_id=netcdf.inqDimID(nc,'TIME');
                [~, dimlen] = netcdf.inqDim(nc,date_id);
                % Date_nc=(netcdf.getVar(nc,netcdf.inqVarID(nc,'TIME')));
                
                if dimlen >0
                    NumOfSecFirst = netcdf.getVar(nc,netcdf.inqVarID(nc,'TIME'),0);
                    NumOfSecLast = netcdf.getVar(nc,netcdf.inqVarID(nc,'TIME'),dimlen-1);
                    
                    %read time offset from nc %
                    TimeZoneValue=netcdf.getAtt(nc,netcdf.getConstant('NC_GLOBAL'),'local_time_zone');
                    TimeOffset=netcdf.getAtt(nc,date_id,'units');
                    if ~isempty(strfind(TimeOffset,'days'))
                        Offset=datenum(TimeOffset(length('days since '):length('days since ')+length('yyyy-mm-dd HH:MM:SS')),'yyyy-mm-dd HH:MM:SS');
                    elseif ~isempty(strfind(TimeOffset,'seconds'))
                        Offset=datenum(TimeOffset(length('seconds since '):length('seconds since ')+length('yyyy-mm-dd HH:MM:SS')),'yyyy-mm-dd HH:MM:SS');
                    end
                    
                    [y, m, d, h, mn, s] = datevec(Offset);
                    
                    sFirst=double(s+NumOfSecFirst);
                    sLast=double(s+NumOfSecLast);
                    
                    
                    data_mainVar=netcdf.getVar(nc,0);
                    NoNaNData=sum(data_mainVar~=999999);
                    
                    
                    START=datenum(y, m, d,h,mn,sFirst);
                    END=datenum(y, m, d,h,mn,sLast);
                    eps1=0.00001;
                    X1=[START-eps1 START END END+eps1];
                    %                     YY1=[dimlen dimlen];
                    %                     YY2=[NoNaNData NoNaNData];
                    %
                    YY1=[0 dimlen dimlen 0];
                    YY2=[0 NoNaNData NoNaNData 0];
                    try
                        if ~isempty(X.([strcat('channelId',channelId)]))
                            myDATE=X.([strcat('channelId',channelId)]).myDATE;
                            myDATE=[myDATE X1];
                            TOTpoints= Y1(1).([strcat('channelId',channelId)]).TOTpoints;
                            TOTpoints=[TOTpoints YY1];
                            TOTgoodpoints=Y2(1).([strcat('channelId',channelId)]).TOTgoodpoints;
                            TOTgoodpoints=[TOTgoodpoints YY2];
                        else
                            %                             ii=1;
                        end
                    catch dv
                        %                         ii=1;
                        myDATE=X1;
                        TOTpoints=YY1;
                        TOTgoodpoints=YY2;
                    end
                    
                    X(1).([strcat('channelId',channelId)])=struct('myDATE',myDATE);
                    Y1(1).([strcat('channelId',channelId)])=struct('TOTpoints',TOTpoints);
                    Y2(1).([strcat('channelId',channelId)])=struct('TOTgoodpoints',TOTgoodpoints);
                    metaLongname(1).([strcat('channelId',channelId)])=struct('longname',long_name);
                    metaChannel(1).([strcat('channelId',channelId)])=struct('channelid',channelId);
                    
                    clear  myDATE  TOTpoints  TOTgoodpoints
                    
                end
                netcdf.close(nc);
                
            end
            
        end
        
        fprintf('%s - %s - Data availability \n', deployments(dd).name,sites(ss).name)
        
        nFields = numel(fieldnames(X));
        fields=fieldnames(X);
        
        
        
        
        
        %         set(fh, 'Position', [1   (nFields*300+nFields*nFields*30) 1300 (nFields*300+nFields*nFields*30) ]);
        aa=max(X.([fields{1}]).myDATE)-min(X.([fields{1}]).myDATE);
        bb=max(Y1.([fields{1}]).TOTpoints);
        indexMaxDateExtention=1;
        indexMaxPointsExtention=1;
        for ii=1:nFields
            if max(X.([fields{ii}]).myDATE)-min(X.([fields{ii}]).myDATE) > aa
                aa=max(X.([fields{ii}]).myDATE)-min(X.([fields{ii}]).myDATE) ;
                indexMaxDateExtention=ii;
            end
            
            if max(Y1.([fields{ii}]).TOTpoints) >bb
                bb=max(Y1.([fields{ii}]).TOTpoints);
                indexMaxPointsExtention=ii;
            end
        end
        
        fh=figure(indexi);
        set(fh,'Name',strcat(deployments(dd).name,'-',sites(ss).name))
        set(fh, 'Position',  [1   (nFields*300+nFields*nFields*40) 1400 (nFields*300+nFields*nFields*40) ], 'Color',[1 1 1]);
        for ii=1:nFields
            
            [year_min,month_min]=datevec(min(X.([fields{ii}]).myDATE));
            [year_max,month_max]=datevec(max(X.([fields{ii}]).myDATE));
            xMonths= (12-month_min)+month_max+(year_max-year_min-1)*12+1;
            
            %             subplot(nFields,1,ii,'replace')
            subplot(nFields,1,ii)
            
            area(X.([fields{ii}]).myDATE,Y1.([fields{ii}]).TOTpoints,'FaceColor','r',...
                'EdgeColor','k',...
                'LineWidth',2)
            xData = linspace(min(X.([fields{ii}]).myDATE),max(X.([fields{ii}]).myDATE),xMonths);
            grid on
            hold on
            area(X.([fields{ii}]).myDATE,Y2.([fields{ii}]).TOTgoodpoints,'FaceColor','g',...
                'EdgeColor','k',...
                'LineWidth',2)
            %         set(gca,'xtick',[],'ytick',[])
            
            %                         set(gca,'XTick',xData,'Layer','top')
            set(gca,'xtick',[])
            set(gca,'Layer','top')
            %             ylabel('Number of points per month')
            %             legend('Qtt NaN','Qtt QaQc','Location','EastOutside')
            %             set(gca,'LineStyle',':','LineWidth',2)
            
            %             title (strrep ( strcat(deployments(dd).name,'-',sites(ss).name,'- Channel:',metaChannel.([fields{ii}]).channelid,...
            %                 '-',metaLongname.([fields{ii}]).longname,'-Fromdate:',fromDate{str2double((metaChannel.([fields{ii}]).channelid))},'-Thrudate:',thruDate{str2double((metaChannel.([fields{ii}]).channelid))} ) ...
            %                 ,'_',' '),'FontWeight','bold')
            
            title (strrep ( strcat('Channel:',metaChannel.([fields{ii}]).channelid,...
                '-',metaLongname.([fields{ii}]).longname,...
                '-Fromdate@AIMS:',fromDate{str2double((metaChannel.([fields{ii}]).channelid))}(1:10),...
                '@emII:',datestr(min(X.([fields{ii}]).myDATE)+Tenhours,'yyyy-mm-dd'),...
                '---Thrudate@AIMS:',thruDate{str2double((metaChannel.([fields{ii}]).channelid))}(1:10),...
                '@emII:',datestr(max(X.([fields{ii}]).myDATE)+Tenhours,'yyyy-mm-dd')...
                ),'_',' '),'FontWeight','bold')
            
            %             datetick('x',28)
            
            axis([min(X.([fields{indexMaxDateExtention}]).myDATE) max(X.([fields{indexMaxDateExtention}]).myDATE) ...
                min(Y1.([fields{indexMaxPointsExtention}]).TOTpoints) max(Y1.([fields{indexMaxPointsExtention}]).TOTpoints)])
            %             datestr(max(X.([fields{ii}]).myDATE),'yyyy-mm-dd')
        end
        set(gca,'xtickMode', 'auto')
        datetick('x',28)
        axis([min(X.([fields{indexMaxDateExtention}]).myDATE) max(X.([fields{indexMaxDateExtention}]).myDATE) ...
            min(Y1.([fields{indexMaxPointsExtention}]).TOTpoints) max(Y1.([fields{indexMaxPointsExtention}]).TOTpoints)])
        
        
        %             print(fh,
        %             '-djpeg','-r300',strcat(deployments(dd).name,'-',sites(ss).name,'.jpg'))
        
        FAIMMS_ReportFolder=strcat(FAIMMS_DownloadFolder,'/Report');                             %folder where files will be downloaded
        
        if ~exist(strcat(FAIMMS_ReportFolder,filesep,deployments(dd).name),'dir')
            mkdir(strcat(FAIMMS_ReportFolder,filesep,deployments(dd).name));
        end
        
        
        pause(2);
        export_fig (strcat(FAIMMS_ReportFolder,filesep,deployments(dd).name,filesep,deployments(dd).name,'-',sites(ss).name,'-',levelVersion,'.png'))
        close(fh)
        
    end
end
