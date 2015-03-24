function SOOP_track_report()
Tenhours=datenum(0,0,0,10,0,0);

WhereAreScripts    = what;
SOOP_Matlab_Folder = WhereAreScripts.path;
addpath(genpath(SOOP_Matlab_Folder));


destinationPath = getenv('data_opendap_path');
dataWIP         = getenv('data_wip_path');
XML             = getenv('xmlRSS_address_level1');


if exist([dataWIP filesep 'PreviousDownload.mat'],'file')
    load ([dataWIP filesep 'PreviousDownload.mat'])
end

SOOP_ReportFolder=getenv('soop_report_path', 'config.txt','=');
mkpath(SOOP_ReportFolder)

%% Load the RSS feed into a structure
filenameXML = [dataWIP filesep 'SOOP_RSS.xml'];
urlwrite(XML, filenameXML);
V           = xml_parseany(fileread(filenameXML));                                    %Create the structure from the XML file
delete(filenameXML);
[~,b]       = size(V.channel{1,1}.item);

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
fromDate_pre  = cell(MaxChannelValue,1);
thruDate_pre  = cell(MaxChannelValue,1);
fromDate      = cell(MaxChannelValue,1);
thruDate      = cell(MaxChannelValue,1);
metadata_uuid = cell(MaxChannelValue,1);


%% Create a list of Channel ID sync with lat, long, metadata_UUID...
for i=1:b
    k                = str2double(channelId{i});
    metadata_uuid{k} = V.channel{1,1}.item{1,i}.metadataLink{1,1}.CONTENT;
end


%% Create a list of available dates to download for each channel
for i=1:length(channelId)
    k=str2double(channelId{i});

    fromDate_pre{k}=V.channel{1,1}.item{1,i}.fromDate{1,1}.CONTENT;
    thruDate_pre{k}=V.channel{1,1}.item{1,i}.thruDate{1,1}.CONTENT;


    [yearLaunch,monthLaunch,dayLaunch,hourLaunch,minLaunch,secLaunch]=datevec(fromDate_pre{k},'yyyy-mm-ddTHH:MM:SS');
    fromDate{k}=datestr(datenum([ yearLaunch monthLaunch dayLaunch hourLaunch minLaunch secLaunch]), 'yyyy-mm-ddTHH:MM:SS');


        [yearEnd,monthEnd,dayEnd,hourEnd,minEnd,secEnd]=datevec(thruDate_pre{k},'yyyy-mm-ddTHH:MM:SS');
        thruDate{k}=datestr(datenum([ yearEnd monthEnd dayEnd hourEnd minEnd secEnd]), 'yyyy-mm-ddTHH:MM:SS');


    %if nothing has never been downloaded before, the last date is the
    %launch date. We do a try catch, if a new channel, with a number over
    %the preallocation, has been added
    try
        if isempty(PreviousDateDownloaded_lev0{k})
            PreviousDateDownloaded_lev0{k}=fromDate{k};
        end
    catch %#ok
        PreviousDateDownloaded_lev0{k}=fromDate{k};
        PreviousDownloadedFile_lev0{k}=[];
    end

    try
        if isempty(PreviousDateDownloaded_lev1{k})
            PreviousDateDownloaded_lev1{k}=fromDate{k};
        end
    catch %#ok
        PreviousDateDownloaded_lev1{k}=fromDate{k};
        PreviousDownloadedFile_lev1{k}=[];
    end
end



deployments= dir(destinationPath);
for dd=3:length(deployments)
    indexi=0;
    % for dd=3

    sites = dir(strcat(destinationPath,filesep,deployments(dd).name,filesep,'By_Cruise',filesep));
    for ss=3:length(sites)
        indexi=indexi+1;

        [~,~,Names]=DIRR(strcat(destinationPath ...
            ,filesep,deployments(dd).name,filesep,'By_Cruise',filesep,sites(ss).name),'.nc','name','isdir','1');

        LAT          =struct;
        LON          =struct;
        X            =struct;
        Y1           =struct;
        Y2           =struct;
        metaLongname =struct;
        metaChannel  =struct;
        for jj=1:length(Names)

            if strcmp(Names{jj}(end-2:end),'.nc')
                nc = netcdf.open(Names{jj},'NC_NOWRITE');

                long_name = netcdf.getAtt(nc,0,'long_name');
                long_name=strrep(long_name, ' ', '_');
                channelId=netcdf.getAtt(nc,netcdf.getConstant('NC_GLOBAL'),'aims_channel_id');
                date_id=netcdf.inqDimID(nc,'time');
                [~, dimlen] = netcdf.inqDim(nc,date_id);


                if dimlen > 0

                        %% get standard variables
                    lat                       = getVarUnpackedNC('LATITUDE',nc);
                    lon                       = getVarUnpackedNC('LONGITUDE',nc);
                    TIME                      = getVarUnpackedNC('time',nc);
                    START                     = datenum(TIME(1));
                    END                       = datenum(TIME(end));

                    %% get main variable
                    [allVarnames,~]           = listVarNC(nc);
                    idxLAT                    = strcmpi(allVarnames,'latitude')==1; %idx to remove from tt
                    idxLON                    = strcmpi(allVarnames,'longitude')==1; %idx to remove from tt
                    idxTIME                   = strcmpi(allVarnames,'time')==1; %idx to remove from tt
                    idxDEPTH                  = strcmpi(allVarnames,'depth')==1; %idx to remove from tt
                    idxQC                     =~cellfun('isempty',(strfind(allVarnames,'_quality_control')));

                    tttt                      =1:length(allVarnames);
                    mainVarIndex              =tttt(setdiff(1:length(tttt),[tttt(idxTIME),tttt(idxLAT),...
                    tttt(idxLON),tttt(idxQC),tttt(idxDEPTH)]));

                    mainVarname               =allVarnames(mainVarIndex);
                    [data_mainVar,mainvarAtt] =getVarUnpackedNC(mainVarname,nc);
                    NoNaNData                 =sum(data_mainVar~=mainvarAtt.FillValue);


                    eps1                      =0.00001;
                    X1                        =[START-eps1 START END END+eps1];

                    YY1                       =[0 dimlen dimlen 0];
                    YY2                       =[0 NoNaNData NoNaNData 0];
                    try
                        if ~isempty(X.([strcat('channelId',channelId)]))
                            myDATE=X.([strcat('channelId',channelId)]).myDATE;
                            myDATE=[myDATE X1];
                            TOTpoints= Y1(1).([strcat('channelId',channelId)]).TOTpoints;
                            TOTpoints=[TOTpoints YY1];
                            TOTgoodpoints=Y2(1).([strcat('channelId',channelId)]).TOTgoodpoints;
                            TOTgoodpoints=[TOTgoodpoints YY2];
                        else
                        end
                    catch dv
                        myDATE=X1;
                        TOTpoints=YY1;
                        TOTgoodpoints=YY2;
                    end

                    X(1).([strcat('channelId',channelId)])            =struct('myDATE',myDATE);
                    Y1(1).([strcat('channelId',channelId)])           =struct('TOTpoints',TOTpoints);
                    Y2(1).([strcat('channelId',channelId)])           =struct('TOTgoodpoints',TOTgoodpoints);
                    metaLongname(1).([strcat('channelId',channelId)]) =struct('longname',long_name);
                    metaChannel(1).([strcat('channelId',channelId)])  =struct('channelid',channelId);
                    LAT(1).([strcat('channelId',channelId)])          =struct('Lat',lat);
                    LON(1).([strcat('channelId',channelId)])          =struct('Lon',lon);


                    clear  myDATE  TOTpoints  TOTgoodpoints

                end
                netcdf.close(nc);

            end

        end

%         fprintf('%s - %s - Data availability \n', deployments(dd).name,sites(ss).name)

        nFields = numel(fieldnames(X));
        fields=fieldnames(X);



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

        fh2=figure(indexi);
        set(fh2,'Name',strcat(deployments(dd).name,'-',sites(ss).name,'-TRACK'))
        set(fh2, 'Position',  [1   (nFields*300+nFields*nFields*40) 1400 (nFields*300+nFields*nFields*40) ], 'Color',[1 1 1]);

        for ii=1:nFields
            subplot(nFields,1,ii)
            plot(LON.([fields{ii}]).Lon ,LAT.([fields{ii}]).Lat )
            xlabel('Longitude')
            ylabel('Latitude')

            title (strrep ( strcat('Channel:',metaChannel.([fields{ii}]).channelid,...
                '-',metaLongname.([fields{ii}]).longname,...
                '-Fromdate@AIMS:',fromDate{str2double((metaChannel.([fields{ii}]).channelid))}(1:10),...
                '@emII:',datestr(min(X.([fields{ii}]).myDATE)+Tenhours,'yyyy-mm-dd'),...
                '---Thrudate@AIMS:',thruDate{str2double((metaChannel.([fields{ii}]).channelid))}(1:10),...
                '@emII:',datestr(max(X.([fields{ii}]).myDATE)+Tenhours,'yyyy-mm-dd')...
                ),'_',' '),'FontWeight','bold')

        end


        if ~exist(strcat(SOOP_ReportFolder,filesep,deployments(dd).name),'dir')
            mkdir(strcat(SOOP_ReportFolder,filesep,deployments(dd).name));
        end


        export_fig (strcat(SOOP_ReportFolder,filesep,deployments(dd).name,filesep,deployments(dd).name,'-',sites(ss).name,'-TRACK.png'))
        close(fh2)

    end
end
