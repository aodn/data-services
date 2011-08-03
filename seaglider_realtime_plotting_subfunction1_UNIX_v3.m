function [toto] = seaglider_realtime_plotting_subfunction1_UNIX_v3(fileinput,deployment)
%
global outputdir
%outputdir = '/var/lib/matlab_3/ANFOG/realtime/seaglider/output';
global dfpublicdir
%dfpublicdir  = '/home/matlab_3/datafabric_root/public/ANFOG/Realtime/seaglider';
%
ncinfo = dir(strcat(fileinput,'/',deployment,'/','IMOS_ANFOG_*.nc'));  %struct of all .nc filenames in directory
%
ncastfiles = size(ncinfo,1) %count no of files available for processing
%
if (ncastfiles == 0)
    toto = 1;
else
    toto = 2;
%
%Creating variables
bTIME=[];
bTIME_quality_control=[];
bLATITUDE=[];
bLATITUDE_quality_control=[];
bLONGITUDE=[];
bLONGITUDE_quality_control=[];
bDEPTH=[];
bDEPTH_quality_control=[];
bTEMP=[];
bTEMP_quality_control=[];
bCDOM=[];
bCDOM_quality_control=[];
bDOXY=[];
bDOXY_quality_control=[];
bVBSC=[];
bVBSC_quality_control=[];
bCNDC=[];
bCNDC_quality_control=[];
bFLU2=[];
bFLU2_quality_control=[];
bPSAL=[];
bPSAL_quality_control=[];
%
%OPEN ALL NETCDF FILES OF A PARTICULAR DEPLOYMENT
for i=1:ncastfiles
%for i=1:95
    fclose('all');
    strcat(fileinput,'/',deployment,'/',ncinfo(i).name)
    nc = netcdf.open(strcat(fileinput,'/',deployment,'/',ncinfo(i).name),'NC_NOWRITE');
    temp_varid = netcdf.inqVarID(nc,'TIME');
    temp = netcdf.getVar(nc,temp_varid);
    TIME = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'LATITUDE');
    temp = netcdf.getVar(nc,temp_varid);
    LATITUDE = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'LONGITUDE');
    temp = netcdf.getVar(nc,temp_varid);
    LONGITUDE = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'DEPTH');
    temp = netcdf.getVar(nc,temp_varid);
    DEPTH = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'TEMP');
    temp = netcdf.getVar(nc,temp_varid);
    TEMP = temp(:);
% %    
    temp_varid = netcdf.inqVarID(nc,'CDOM');
    temp = netcdf.getVar(nc,temp_varid);
    CDOM = temp(:);
%
    temp_varid = netcdf.inqVarID(nc,'DOXY');
    temp = netcdf.getVar(nc,temp_varid);
    DOXY = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'VBSC');
    temp = netcdf.getVar(nc,temp_varid);
    VBSC = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'CNDC');
    temp = netcdf.getVar(nc,temp_varid);
    CNDC = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'FLU2');
    temp = netcdf.getVar(nc,temp_varid);
    FLU2 = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'PSAL');
    temp = netcdf.getVar(nc,temp_varid);
    PSAL = temp(:);
% %    
    temp_varid = netcdf.inqVarID(nc,'TIME_quality_control');
    temp = netcdf.getVar(nc,temp_varid);
    TIME_quality_control = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'LATITUDE_quality_control');
    temp = netcdf.getVar(nc,temp_varid);
    LATITUDE_quality_control = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'LONGITUDE_quality_control');
    temp = netcdf.getVar(nc,temp_varid);
    LONGITUDE_quality_control = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'DEPTH_quality_control');
    temp = netcdf.getVar(nc,temp_varid);
    DEPTH_quality_control = temp(:);
% %    
    temp_varid = netcdf.inqVarID(nc,'TEMP_quality_control');
    temp = netcdf.getVar(nc,temp_varid);
    TEMP_quality_control = temp(:);
% %    
    temp_varid = netcdf.inqVarID(nc,'CDOM_quality_control');
    temp = netcdf.getVar(nc,temp_varid);
    CDOM_quality_control = temp(:);
%
    temp_varid = netcdf.inqVarID(nc,'DOXY_quality_control');
    temp = netcdf.getVar(nc,temp_varid);
    DOXY_quality_control = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'VBSC_quality_control');
    temp = netcdf.getVar(nc,temp_varid);
    VBSC_quality_control = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'CNDC_quality_control');
    temp = netcdf.getVar(nc,temp_varid);
    CNDC_quality_control = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'FLU2_quality_control');
    temp = netcdf.getVar(nc,temp_varid);
    FLU2_quality_control = temp(:);
%    
    temp_varid = netcdf.inqVarID(nc,'PSAL_quality_control');
    temp = netcdf.getVar(nc,temp_varid);
    PSAL_quality_control = temp(:);   
% %        
%    ncload(ncinfo(i).name);
%    fclose('all');
     bTIME=[bTIME;TIME];
     bLATITUDE=[bLATITUDE;LATITUDE];
     bLONGITUDE=[bLONGITUDE;LONGITUDE];
     bDEPTH=[bDEPTH;DEPTH];
    bTEMP=[bTEMP;TEMP];
    bCDOM=[bCDOM;CDOM];
    bDOXY=[bDOXY;DOXY];
    bVBSC=[bVBSC;VBSC];
    bCNDC=[bCNDC;CNDC];
    bFLU2=[bFLU2;FLU2];
    bPSAL=[bPSAL;PSAL];    
%    
     bTIME_quality_control=[bTIME_quality_control;TIME_quality_control];    
     bLATITUDE_quality_control=[bLATITUDE_quality_control;LATITUDE_quality_control];
     bLONGITUDE_quality_control=[bLONGITUDE_quality_control;LONGITUDE_quality_control];
     bDEPTH_quality_control=[bDEPTH_quality_control;DEPTH_quality_control];
    bTEMP_quality_control=[bTEMP_quality_control;TEMP_quality_control];
    bCDOM_quality_control=[bCDOM_quality_control;CDOM_quality_control];
    bDOXY_quality_control=[bDOXY_quality_control;DOXY_quality_control];
    bVBSC_quality_control=[bVBSC_quality_control;VBSC_quality_control];
    bCNDC_quality_control=[bCNDC_quality_control;CNDC_quality_control];
    bFLU2_quality_control=[bFLU2_quality_control;FLU2_quality_control];
    bPSAL_quality_control=[bPSAL_quality_control;PSAL_quality_control];
%
    divetemp = textscan(netcdf.getatt(nc,netcdf.getConstant('GLOBAL'),'comment'),'%s','delimiter',' ');
    nbdive(i,1) = str2num(divetemp{1}{8}(1:end-7));
    timetemp = netcdf.getatt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_end');
    nbdive(i,2) = datenum(timetemp,'yyyy-mm-ddTHH:MM:SS')-datenum('01-01-1950 00:00:00');
%
    netcdf.close(nc);
%
end
%
%DEFINITION OF THE MIN AND MAX TOBE USED FOR PLOTTING FOR EACH DEPLOYMENT
switch deployment
    case {'CoralSea20100601','CoralSea20110723'}
        doxymax =4.5;
        doxymin =2;
        vbscmax =0.0003;
        vbscmin =0;
        cndcmax =10;
        cndcmin =0;
        flu2max =1.5;
        flu2min =0;
        psalmin =34;
        psalmax =36;
        cdommax =2;
        cdommin =0;
        tempmax =28;
        tempmin =5;
    case 'CrowdyHead20100809'
        doxymax =5;
        doxymin =2.5;
        vbscmax =0.001;
        vbscmin =0;
        cndcmax =10;
        cndcmin =0;
        flu2max =4;
        flu2min =0;
        psalmin =34;
        psalmax =36;
        cdommax =2;
        cdommin =0;
        tempmax =22;
        tempmin =5;        
    case {'Perth20100517','Perth20100906'}
        doxymax =5.5;
        doxymin =2.5;
        vbscmax =0.001;
        vbscmin =0;
        cndcmax =10;
        cndcmin =0;
        flu2max =1;
        flu2min =0;
        psalmin =34;
        psalmax =36;
        cdommax =2;
        cdommin =0;
        tempmax =26;
        tempmin =5;        
    case {'Perth20110626_1','Perth20110626_2'}
        doxymax =5.5;
        doxymin =3;
        vbscmax =0.001;
        vbscmin =0;
        cndcmax =10;
        cndcmin =0;
        flu2max =1.5;
        flu2min =0;
        psalmin =34;
        psalmax =36;
        cdommax =2;
        cdommin =0;
        tempmax =26;
        tempmin =5;        
    case {'Bicheno20100813','Bicheno20110406'}
        doxymax =6;
        doxymin =2.5;
        vbscmax =0.005;
        vbscmin =0;
        cndcmax =10;
        cndcmin =0;
        flu2max =1.5;
        flu2min =0;
        psalmin =34;
        psalmax =36;
        cdommax =2;
        cdommin =0;
        tempmax =20;
        tempmin =5;
    case 'SOTS20100913'
        doxymax =6;
        doxymin =4;
        vbscmax =0.001;
        vbscmin =0;
        cndcmax =10;
        cndcmin =0;
        flu2max =0.5;
        flu2min =0;
        psalmax =36;
        psalmin =34;
        cdommax =1;
        cdommin =0;
        tempmax =14;
        tempmin =4;
    otherwise   
        doxymax =5;
        doxymin =2;
        vbscmax =0.001;
        vbscmin =0;
        cndcmax =10;
        cndcmin =0;
        flu2max =2;
        flu2min =0;
        psalmin =34;
        psalmax =37;
        cdommax =2;
        cdommin =0;
        tempmax =26;
        tempmin =5;        
end
%
% %plot colour transects for each type of data
% 
figure(1)
%seerange(bDOXY_quality_control)
ok=find(bDOXY_quality_control==1);
if(~isempty(ok))
zz = ceil(length(ok)/200000);
%plotddots(bDOXY(ok),bTIME(ok),bDEPTH(ok),floor(min(bDOXY(ok))),ceil(max(bDOXY(ok))))
plotddots(bDOXY(ok(1:zz:end)),bTIME(ok(1:zz:end)),bDEPTH(ok(1:zz:end)),doxymin,doxymax)
title('Oxygen Concentration (ml/L)','FontSize',20)
%datetick('x','dd/mm','keeplimits')
%xlabel('date in 2009')
ylabel('depth (m)','FontSize',20)
 stepdive = floor(max(nbdive(:,1))/5);
 strlegend1 = strcat('Dive-',num2str(nbdive(1+stepdive,1)));
 strlegend2 = strcat('Dive-',num2str(nbdive(1+2*stepdive,1)));
 strlegend3 = strcat('Dive-',num2str(nbdive(1+3*stepdive,1)));
 strlegend4 = strcat('Dive-',num2str(nbdive(1+4*stepdive,1)));
 strlegend5 = strcat('Dive-',num2str(max(nbdive(:,1))));
% maxbdepth = (max(max(bDEPTH(ok))))/100*(-1);
 if (max(bDEPTH(ok)) < 200)
     maxbdepth = -2;
elseif (max(bDEPTH(ok)) > 200 & max(bDEPTH(ok)) < 400)
     maxbdepth = -4;
elseif (max(bDEPTH(ok)) > 400 & max(bDEPTH(ok)) < 600)
     maxbdepth = -4;
elseif (max(bDEPTH(ok)) > 600 & max(bDEPTH(ok)) < 800)
     maxbdepth = -6;
elseif (max(bDEPTH(ok)) > 800 & max(bDEPTH(ok)) < 1000)
     maxbdepth = -8;
elseif (max(bDEPTH(ok)) > 1000 )
     maxbdepth = -10;
end
 text(min(bTIME(ok)),maxbdepth,'Dive-1','HorizontalAlignment','Center');
 text(nbdive(1+stepdive,2),maxbdepth,strlegend1,'HorizontalAlignment','Center');
 text(nbdive(1+2*stepdive,2),maxbdepth,strlegend2,'HorizontalAlignment','Center');
 text(nbdive(1+3*stepdive,2),maxbdepth,strlegend3,'HorizontalAlignment','Center');
 text(nbdive(1+4*stepdive,2),maxbdepth,strlegend4,'HorizontalAlignment','Center');
if (max(bTIME(ok)) > nbdive(end-10,2))
 text(max(bTIME(ok)),maxbdepth,strlegend5,'HorizontalAlignment','Center');
end
fileoutput = strcat(outputdir,'/plotting/',deployment,'_DOXY.jpg');
print (1,'-djpeg',fileoutput)
%
try
filejpeg1 = strcat(outputdir,'/plotting/',deployment,'_DOXY.jpg');
filejpeg2 = strcat(dfpublicdir,'/',deployment,'/',deployment,'_DOXY.jpg');
delete(filejpeg2);
copyfile(filejpeg1,filejpeg2);
end
%shg
close(1)
end
%
% figure(2)
% seerange(bVBSC_quality_control)
% ok=find(bVBSC_quality_control==1);
% zz = ceil(length(ok)/200000);
% plotddots(bVBSC(ok(1:zz:end)),bTIME(ok(1:zz:end)),bDEPTH(ok(1:zz:end)),floor(min(bVBSC(ok))),ceil(max(bVBSC(ok))))
% plotddots(bVBSC(ok(1:zz:end)),bTIME(ok(1:zz:end)),bDEPTH(ok(1:zz:end)),vbscmin,vbscmax)
% title('VBSC (m-1 sr-1)')
% datetick('x','dd/mm','keeplimits')
% xlabel('date in 2009')
% ylabel('depth (m)')
% fileoutput = strcat(deployment,'_VBSC.jpeg');
% print (2,'-djpeg',fileoutput)
% shg
% figure(3)
% %seerange(bCNDC_quality_control)
% ok=find(bCNDC_quality_control==1);
% zz = ceil(length(ok)/200000);
% %plotddots(bCNDC(ok(1:zz:end)),bTIME(ok(1:zz:end)),bDEPTH(ok(1:zz:end)),floor(min(bCNDC(ok))),ceil(max(bCNDC(ok))))
% plotddots(bCNDC(ok(1:zz:end)),bTIME(ok(1:zz:end)),bDEPTH(ok(1:zz:end)),cndcmin,cndcmax)
% title('CNDC')
% % datetick('x','dd/mm','keeplimits')
% %xlabel('date in 2009')
% ylabel('depth (m)')
% fileoutput = strcat(deployment,'_CNDC.jpeg');
% print (3,'-djpeg',fileoutput)
% %shg
% close(3)
%
figure(4)
%seerange(bFLU2_quality_control)
ok=find(bFLU2_quality_control==1);
if(~isempty(ok))
zz = ceil(length(ok)/200000);
%plotddots(bFLU2(ok),bTIME(ok),bDEPTH(ok),floor(min(bFLU2(ok))),ceil(max(bFLU2(ok))))
plotddots(bFLU2(ok(1:zz:end)),bTIME(ok(1:zz:end)),bDEPTH(ok(1:zz:end)),flu2min,flu2max)
title('Chlorophyll-a','FontSize',20)
% datetick('x','dd/mm','keeplimits')
%xlabel('date in 2009')
ylabel('depth (m)','FontSize',20)
 stepdive = floor(max(nbdive(:,1))/5);
 strlegend1 = strcat('Dive-',num2str(nbdive(1+stepdive,1)));
 strlegend2 = strcat('Dive-',num2str(nbdive(1+2*stepdive,1)));
 strlegend3 = strcat('Dive-',num2str(nbdive(1+3*stepdive,1)));
 strlegend4 = strcat('Dive-',num2str(nbdive(1+4*stepdive,1)));
 strlegend5 = strcat('Dive-',num2str(max(nbdive(:,1))));
% maxbdepth = max(bDEPTH(ok))/100;
 if (max(bDEPTH(ok)) < 200)
     maxbdepth = -2;
elseif (max(bDEPTH(ok)) > 200 & max(bDEPTH(ok)) < 400)
     maxbdepth = -4;
elseif (max(bDEPTH(ok)) > 400 & max(bDEPTH(ok)) < 600)
     maxbdepth = -4;
elseif (max(bDEPTH(ok)) > 600 & max(bDEPTH(ok)) < 800)
     maxbdepth = -6;
elseif (max(bDEPTH(ok)) > 800 & max(bDEPTH(ok)) < 1000)
     maxbdepth = -8;
elseif (max(bDEPTH(ok)) > 1000 )
     maxbdepth = -10;
end
 text(min(bTIME(ok)),maxbdepth,'Dive-1','HorizontalAlignment','Center');
 text(nbdive(1+stepdive,2),maxbdepth,strlegend1,'HorizontalAlignment','Center');
 text(nbdive(1+2*stepdive,2),maxbdepth,strlegend2,'HorizontalAlignment','Center');
 text(nbdive(1+3*stepdive,2),maxbdepth,strlegend3,'HorizontalAlignment','Center');
 text(nbdive(1+4*stepdive,2),maxbdepth,strlegend4,'HorizontalAlignment','Center');
if (max(bTIME(ok)) > nbdive(end-10,2))
 text(max(bTIME(ok)),maxbdepth,strlegend5,'HorizontalAlignment','Center');
end
fileoutput = strcat(outputdir,'/plotting/',deployment,'_chlorophyll.jpg');
print (4,'-djpeg',fileoutput)
try
filejpeg1 = strcat(outputdir,'/plotting/',deployment,'_chlorophyll.jpg');
filejpeg2 = strcat(dfpublicdir,'/',deployment,'/',deployment,'_chlorophyll.jpg');
delete(filejpeg2);
copyfile(filejpeg1,filejpeg2);
end
%shg
close(4)
end
%
figure(5)
%seerange(bPSAL_quality_control)
ok=find(bPSAL_quality_control==1);
if(~isempty(ok))
zz = ceil(length(ok)/200000);
%plotddots(bPSAL(ok),bTIME(ok),bDEPTH(ok),floor(min(bPSAL(ok))),ceil(max(bPSAL(ok))))
plotddots(bPSAL(ok(1:zz:end)),bTIME(ok(1:zz:end)),bDEPTH(ok(1:zz:end)),psalmin,psalmax)
title('Salinity (PSU)','FontSize',20)
%datetick('x','dd/mm','keeplimits')
%xlabel('date in 2009')
ylabel('depth (m)','FontSize',20)
 stepdive = floor(max(nbdive(:,1))/5);
 strlegend1 = strcat('Dive-',num2str(nbdive(1+stepdive,1)));
 strlegend2 = strcat('Dive-',num2str(nbdive(1+2*stepdive,1)));
 strlegend3 = strcat('Dive-',num2str(nbdive(1+3*stepdive,1)));
 strlegend4 = strcat('Dive-',num2str(nbdive(1+4*stepdive,1)));
 strlegend5 = strcat('Dive-',num2str(max(nbdive(:,1))));
% maxbdepth = max(bDEPTH(ok))/100;
 if (max(bDEPTH(ok)) < 200)
     maxbdepth = -2;
elseif (max(bDEPTH(ok)) > 200 & max(bDEPTH(ok)) < 400)
     maxbdepth = -4;
elseif (max(bDEPTH(ok)) > 400 & max(bDEPTH(ok)) < 600)
     maxbdepth = -4;
elseif (max(bDEPTH(ok)) > 600 & max(bDEPTH(ok)) < 800)
     maxbdepth = -6;
elseif (max(bDEPTH(ok)) > 800 & max(bDEPTH(ok)) < 1000)
     maxbdepth = -8;
elseif (max(bDEPTH(ok)) > 1000 )
     maxbdepth = -10;
end
 text(min(bTIME(ok)),maxbdepth,'Dive-1','HorizontalAlignment','Center');
 text(nbdive(1+stepdive,2),maxbdepth,strlegend1,'HorizontalAlignment','Center');
 text(nbdive(1+2*stepdive,2),maxbdepth,strlegend2,'HorizontalAlignment','Center');
 text(nbdive(1+3*stepdive,2),maxbdepth,strlegend3,'HorizontalAlignment','Center');
 text(nbdive(1+4*stepdive,2),maxbdepth,strlegend4,'HorizontalAlignment','Center');
if (max(bTIME(ok)) > nbdive(end-10,2))
 text(max(bTIME(ok)),maxbdepth,strlegend5,'HorizontalAlignment','Center');
end
fileoutput = strcat(outputdir,'/plotting/',deployment,'_salinity.jpg');
print (5,'-djpeg',fileoutput)
try
filejpeg1 = strcat(outputdir,'/plotting/',deployment,'_salinity.jpg');
filejpeg2 = strcat(dfpublicdir,'/',deployment,'/',deployment,'_salinity.jpg');
delete(filejpeg2);
copyfile(filejpeg1,filejpeg2);
end
%shg
close(5)
end
%
%
%
figure(6)
%seerange(bCDOM_quality_control)
ok=find(bCDOM_quality_control==1);
if(~isempty(ok))
zz = ceil(length(ok)/200000);
%plotddots(bCDOM(ok),bTIME(ok),bDEPTH(ok),floor(min(bCDOM(ok))),ceil(max(bCDOM(ok))))
plotddots(bCDOM(ok(1:zz:end)),bTIME(ok(1:zz:end)),bDEPTH(ok(1:zz:end)),cdommin,cdommax)
title('CDOM (ppb)','FontSize',20)
%datetick('x','dd/mm','keeplimits')
%xlabel('date in 2009')
ylabel('depth (m)','FontSize',20)
 stepdive = floor(max(nbdive(:,1))/5);
 strlegend1 = strcat('Dive-',num2str(nbdive(1+stepdive,1)));
 strlegend2 = strcat('Dive-',num2str(nbdive(1+2*stepdive,1)));
 strlegend3 = strcat('Dive-',num2str(nbdive(1+3*stepdive,1)));
 strlegend4 = strcat('Dive-',num2str(nbdive(1+4*stepdive,1)));
 strlegend5 = strcat('Dive-',num2str(max(nbdive(:,1))));
% maxbdepth = max(bDEPTH(ok))/100;
 if (max(bDEPTH(ok)) < 200)
     maxbdepth = -2;
elseif (max(bDEPTH(ok)) > 200 & max(bDEPTH(ok)) < 400)
     maxbdepth = -4;
elseif (max(bDEPTH(ok)) > 400 & max(bDEPTH(ok)) < 600)
     maxbdepth = -4;
elseif (max(bDEPTH(ok)) > 600 & max(bDEPTH(ok)) < 800)
     maxbdepth = -6;
elseif (max(bDEPTH(ok)) > 800 & max(bDEPTH(ok)) < 1000)
     maxbdepth = -8;
elseif (max(bDEPTH(ok)) > 1000 )
     maxbdepth = -10;
end
 text(min(bTIME(ok)),maxbdepth,'Dive-1','HorizontalAlignment','Center');
 text(nbdive(1+stepdive,2),maxbdepth,strlegend1,'HorizontalAlignment','Center');
 text(nbdive(1+2*stepdive,2),maxbdepth,strlegend2,'HorizontalAlignment','Center');
 text(nbdive(1+3*stepdive,2),maxbdepth,strlegend3,'HorizontalAlignment','Center');
 text(nbdive(1+4*stepdive,2),maxbdepth,strlegend4,'HorizontalAlignment','Center');
if (max(bTIME(ok)) > nbdive(end-10,2))
 text(max(bTIME(ok)),maxbdepth,strlegend5,'HorizontalAlignment','Center');
end
fileoutput = strcat(outputdir,'/plotting/',deployment,'_CDOM.jpg');
print (6,'-djpeg',fileoutput)
try
filejpeg1 = strcat(outputdir,'/plotting/',deployment,'_CDOM.jpg');
filejpeg2 = strcat(dfpublicdir,'/',deployment,'/',deployment,'_CDOM.jpg');
delete(filejpeg2);
copyfile(filejpeg1,filejpeg2);
end
%shg
close(6)
end
% 
 figure(7)
% %seerange(bTEMP_quality_control)
 ok=find(bTEMP_quality_control==1);
 if(~isempty(ok))
 zz = ceil(length(ok)/200000);
% plotddots(bTEMP(ok(1:zz:end)),bTIME(ok(1:zz:end)),bDEPTH(ok(1:zz:end)),floor(min(bTEMP(ok))),ceil(max(bTEMP(ok))))
 plotddots(bTEMP(ok(1:zz:end)),bTIME(ok(1:zz:end)),bDEPTH(ok(1:zz:end)),tempmin,tempmax)
 title('Temperature (Deg C)','FontSize',20)
% datetick('x','dd/mm','keeplimits')
%xlabel('date in 2009')
 ylabel('depth (m)','FontSize',20)
  if (max(bDEPTH(ok)) < 200)
     maxbdepth = -2;
elseif (max(bDEPTH(ok)) > 200 & max(bDEPTH(ok)) < 400)
     maxbdepth = -4;
elseif (max(bDEPTH(ok)) > 400 & max(bDEPTH(ok)) < 600)
     maxbdepth = -4;
elseif (max(bDEPTH(ok)) > 600 & max(bDEPTH(ok)) < 800)
     maxbdepth = -6;
elseif (max(bDEPTH(ok)) > 800 & max(bDEPTH(ok)) < 1000)
     maxbdepth = -8;
elseif (max(bDEPTH(ok)) > 1000 )
     maxbdepth = -10;
end
 stepdive = floor(max(nbdive(:,1))/5);
 strlegend1 = strcat('Dive-',num2str(nbdive(1+stepdive,1)));
 strlegend2 = strcat('Dive-',num2str(nbdive(1+2*stepdive,1)));
 strlegend3 = strcat('Dive-',num2str(nbdive(1+3*stepdive,1)));
 strlegend4 = strcat('Dive-',num2str(nbdive(1+4*stepdive,1)));
 strlegend5 = strcat('Dive-',num2str(max(nbdive(:,1))));
 text(min(bTIME(ok)),maxbdepth,'Dive-1','HorizontalAlignment','Center');
 text(nbdive(1+stepdive,2),maxbdepth,strlegend1,'HorizontalAlignment','Center');
 text(nbdive(1+2*stepdive,2),maxbdepth,strlegend2,'HorizontalAlignment','Center');
 text(nbdive(1+3*stepdive,2),maxbdepth,strlegend3,'HorizontalAlignment','Center');
 text(nbdive(1+4*stepdive,2),maxbdepth,strlegend4,'HorizontalAlignment','Center');
if (max(bTIME(ok)) > nbdive(end-10,2))
 text(max(bTIME(ok)),maxbdepth,strlegend5,'HorizontalAlignment','Center');
end
fileoutput = strcat(outputdir,'/plotting/',deployment,'_temperature.jpg');
print (7,'-djpeg',fileoutput)
try
filejpeg1 = strcat(outputdir,'/plotting/',deployment,'_temperature.jpg');
filejpeg2 = strcat(dfpublicdir,'/',deployment,'/',deployment,'_temperature.jpg');
delete(filejpeg2);
copyfile(filejpeg1,filejpeg2);
end
 close(7)
 end
% shg
end
