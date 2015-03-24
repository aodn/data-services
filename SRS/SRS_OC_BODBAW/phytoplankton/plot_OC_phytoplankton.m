function plot_OC_phytoplankton(File)
%by default we plot the first station,can be modified to become an argument
%of the function though.
if exist(File,'file') ==2
    nc = netcdf.open(char(File),'NC_NOWRITE');
    [numdims, numvars, numglobalatts, unlimdimID] = netcdf.inq(nc);
    [dimname, dimlen] = netcdf.inqDim(nc,1);
    
    VARNAME=[];
    for varid=0:numvars-1
        varid;
        [varname,~,~,~] = netcdf.inqVar(nc,varid);
        VARNAME=[VARNAME,{varname}];
    end
    
    % 9 known variables
    dimidTIME = netcdf.inqVarID(nc,'TIME');
    dimidLAT = netcdf.inqVarID(nc,'LATITUDE');
    dimidLON = netcdf.inqVarID(nc,'LONGITUDE');
    dimidDEPTH= netcdf.inqVarID(nc,'DEPTH');
    dimidstation_name= netcdf.inqVarID(nc,'station_name');
    dimidprofile= netcdf.inqVarID(nc,'profile');
    dimidstation_index= netcdf.inqVarID(nc,'station_index');
    dimidrowSize= netcdf.inqVarID(nc,'rowSize');
    
    tttt=1:numvars;
    ttt=tttt(setdiff(1:length(tttt),[tttt(dimidTIME+1),tttt(dimidLAT+1),...
        tttt(dimidLON+1),tttt(dimidDEPTH+1),...
        tttt(dimidstation_name+1),tttt(dimidprofile+1),tttt(dimidstation_index+1),...
        tttt(dimidrowSize+1)]));
    for ii=1:length(ttt)
        dimidVAR{ii}= netcdf.inqVarID(nc,VARNAME{ttt(ii)});
    end
    
    
    %     lat= double(netcdf.getVar(nc,dimidLAT));
    %     lon=double(netcdf.getVar(nc,dimidLON));
    %     time=(netcdf.getVar(nc,dimidTIME));
    
    rowSize=double(netcdf.getVar(nc,dimidrowSize));
    
    %% which station do we plot ? jj
    jj=1;
    %     StationIndex=(netcdf.getVar(nc,dimidstation_index));
    StationNames=(netcdf.getVar(nc,dimidstation_name));
    strlen=size(StationNames,1);
    StationName=((StationNames(1:strlen,jj))'); % go from 1:2 because
    
    %     numberObsSation=rowSize(jj);
    
    VAR1_varname='CPHL_c3';
    dimidVAR1= netcdf.inqVarID(nc,VAR1_varname);
    %     VAR1Idx= strcmpi(VARNAME,VAR1_varname);
    %
    %     VAR1=double(netcdf.getVar(nc,dimidVAR1,[jj-1],[numberObsSation]));
    %     VAR1(VAR1==-999)=NaN;
    %
    %     depth=-double(netcdf.getVar(nc,dimidDEPTH,[jj-1],[numberObsSation]));
    %
    %
    %     % Generate the mesh plot (CONTOUR can also be used):
    %     fh=figure;
    %     set(fh, 'Position',  [1 500 900 500 ], 'Color',[1 1 1]);
    %
    %
    %     plot(VAR1,depth,'--rs')
    %     xlabel 'CPHL_c1c2'; ylabel depth;
    %     title({strcat(strrep(netcdf.getAtt(nc,dimidVAR1,'long_name'),'_',' ')),...
    %         strcat('in units:',netcdf.getAtt(nc,dimidVAR{1},'units')),...
    %         strcat('for station :',StationName)})
    %
    %     Filename=str2mat(File);
    %     Filename=Filename(1:end-3);
    %     export_fig (strcat(Filename,'.png'))
    %     close(fh)
    %
    
    
    
    %%%
    depth=-double(netcdf.getVar(nc,dimidDEPTH));
    %     StationIndex=(netcdf.getVar(nc,dimidstation_index));
    fh=figure;
    set(fh, 'Position',  [1 500 900 500 ], 'Color',[1 1 1]);
    hold all;
    
    %% we plot only the first 5 stations otherwise it's a mess
    start=1;
    for jj=1:5
        numberObsSation=rowSize(jj);
        VAR1=double(netcdf.getVar(nc,dimidVAR1,[jj-1],[numberObsSation]));
        VAR1(VAR1==-999)=NaN;
        
        plot(VAR1,depth(start:start+numberObsSation-1),'--s')
        start=start+numberObsSation;
    end
    StationNames=StationNames';
    str = strtrim(cellstr(strcat('station:',StationNames)));
    
%     legend(str{1:5},'Location','EastOutside');
    
    xlabel(char(VAR1_varname)); ylabel depth;
    title({strcat(strrep(netcdf.getAtt(nc,dimidVAR1,'long_name'),'_',' ')),...
        strcat('in units:',netcdf.getAtt(nc,dimidVAR{1},'units')),...
        strcat('Example for the first 5 stations')})
    
    Filename=str2mat(File);
    Filename=Filename(1:end-3);
%     export_fig (strcat(Filename,'.png'))
%     close(fh)
end