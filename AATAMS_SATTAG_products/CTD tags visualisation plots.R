rm(list=ls())
library(ncdf)
library(DAAG) ## To get the pause function. Otherwise use the Sys.sleep function to pause the loop for a specified amount of time
library(maps) ## To get a world map
library(raster) ## To be able to plot the gridded netCDF file
library(plotrix) ## To be able to use color functions
library(maptools) ## To be able to read sphapefiles
library(ggplot2) ## For plotting purposes
library(scales) ## For plotting purposes
library(animation)

setwd('/Users/Xavier/Work/R/CTD tags data/AATAMS data files')
file_name<-dir()[1:154]
world_map <- readShapeSpatial("/Users/Xavier/Work/R/CTD tags data/ne_50m_admin_0_countries/ne_50m_admin_0_countries.shp")
world_map_Aus <- fortify(world_map[world_map$sovereignt=="Australia",])
world_map_Ant<-fortify(world_map)[which((fortify(world_map)$lat)<(-10)),]

for (a in 132:length(file_name)){
setwd("/Users/Xavier/Work/R/CTD tags data/")
## CTD tags data
ctd<-open.ncdf(paste("/Users/Xavier/Work/R/CTD tags data/AATAMS data files","/",file_name[a],sep=""))
x<-get.var.ncdf(ctd,"LONGITUDE") # Longitude
y<-get.var.ncdf(ctd,"LATITUDE") # Latitude
z<-get.var.ncdf(ctd,"PRES") # Depth
temp<-get.var.ncdf(ctd,"TEMP") # Temperature
sal<-get.var.ncdf(ctd,"PSAL") # Salinity
par<-get.var.ncdf(ctd,"parentIndex") # Parent Index

time<-get.var.ncdf(ctd,"TIME") # Time
## Attribute a date to each z,temp and sal observation
times<-matrix(ncol=1,nrow=length(par))
for (i in 1:length(par)){
	times[i]<-time[par[i]]
}
date<-as.POSIXlt(times*3600*24,origin="1950-01-01",tz="UTC") # Transform time into calendar date and time

## Transform 9999 values to NA
temp[which((temp)==9999)]<-NA
z[which((z)==9999)]<-NA
sal[which((sal)==9999)]<-NA

## Isolate SST
sst<-temp[which((z)==min(z,na.rm=TRUE))]
if(length(sst)!=length(x)) for (u in 1:length(table(par))){sst[u]<-print(temp[which((par)==u)[1]])}
sssal<-sal[which((z)==min(z,na.rm=TRUE))]
if(length(sssal)!=length(x)) for (u in 1:length(table(par))){sssal[u]<-print(sal[which((par)==u)[1]])}

## Load maps
if (min(y)>(-45)) world_map <- world_map_Aus else world_map<-world_map_Ant

## Create new directory to store plots
subDir<-paste(unlist(strsplit(unlist(strsplit(ctd$filename,split="Z_"))[2],split="_END"))[1])
dir.create(file.path(subDir))
mainDir<-"C:/eMii work - Xavier Hoenner/R/CTD tags data"
setwd(file.path(mainDir,subDir))

########################################################################################## Temperature chart ######################################################################################################
if(length(which((is.na(temp))==TRUE))==0) date2<-date else date2<-date[-which((is.na(temp))==TRUE)]
if(length(which((is.na(temp))==TRUE))==0) z2<-z else z2<-z[-which((is.na(temp))==TRUE)]
if(length(which((is.na(temp))==TRUE))==0) temp2<-temp else temp2<-temp[-which((is.na(temp))==TRUE)]

br<-if(as.numeric(difftime(date2[length(date2)],date2[1],units="days"))>45) "1 month" else if(as.numeric(difftime(date2[length(date2)],date2[1],units="days"))<7) "1 day" else "1 week"
#
jpeg(filename = paste(unlist(strsplit(unlist(strsplit(ctd$filename,split="Z_"))[2],split="_END"))[1],"_","TEMP",".jpg",sep="")
	,width = 1638, height = 1124, units = "px",res=92,quality=100,bg = "white")
temp_profiles<-qplot(as.Date(date2),-z2,colour=temp2) + geom_point(size=4)+
scale_colour_gradient2("Temperature (°C)",limits=c(min(temp2),max(temp2)),low="blue", mid="yellow",high="red",space="rgb",midpoint=min(temp2)+(max(temp2)-min(temp2))/2) + 
xlab("Date")+ylab("Depth (m)")+ labs(title=paste(unlist(strsplit(ctd$filename,split="_"))[5],strftime(date2[1],"%Y%m%d"),": ","TEMP (°C)"))+
theme(panel.background = element_rect(fill='white', colour='black'),panel.grid.minor = element_blank(),
axis.text.x=element_text(colour='black',size=15,vjust=3),
axis.text.y=element_text(colour='black',size=15),
axis.title.x=element_text(colour='black',size=20),
axis.title.y=element_text(colour='black',size=20),
axis.ticks=element_line(colour='black'),
legend.text=element_text(colour='black',size=20),
legend.title=element_text(colour='black',size=20),
legend.key.height=unit(1.5,"cm"),
legend.key.width=unit(1,"cm"),
plot.title=element_text(colour='black',size=20))+
scale_x_date(labels=date_format("%d %b %Y"),breaks=br)
print(temp_profiles)
dev.off()

###################################################################################### Surface temperature fluctuation over time ###############################################################################
## Create new directory to store plots
#subsubDir<-"SST gif"
#dir.create(file.path(subsubDir))
#setwd(file.path(mainDir,subDir,subsubDir))

if(length(which((is.na(sst))==TRUE))==0) x2<-x else x2<-x[-which((is.na(sst))==TRUE)]
if(length(which((is.na(sst))==TRUE))==0) y2<-y else y2<-y[-which((is.na(sst))==TRUE)]
date2<-date[which((duplicated(date))==FALSE)]
if(length(which((is.na(sst))==TRUE))==0) date2<-date2 else date2<-date2[-which((is.na(sst))==TRUE)]
if(length(which((is.na(sst))==TRUE))==0) sst2<-sst else sst2<-sst[-which((is.na(sst))==TRUE)]

#if(length(x2)>=1000) x2<-x2[seq(1,length(x2),3)] else x2<-x2
#if(length(y2)>=1000) y2<-y2[seq(1,length(y2),3)] else y2<-y2
#if(length(date2)>=1000) date2<-date2[seq(1,length(date2),3)] else date2<-date2
#if(length(sst2)>=1000) sst2<-sst2[seq(1,length(sst2),3)] else sst2<-sst2

#if(length(x2)>=520) x2<-x2[seq(1,length(x2),2)] else x2<-x2
#if(length(y2)>=520) y2<-y2[seq(1,length(y2),2)] else y2<-y2
#if(length(date2)>=520) date2<-date2[seq(1,length(date2),2)] else date2<-date2
#if(length(sst2)>=520) sst2<-sst2[seq(1,length(sst2),2)] else sst2<-sst2

#x2<-x2[c(1,round(length(x2)/4),round(length(x2)/4)*2,round(length(x2)/4)*3,length(x2))]
#y2<-y2[c(1,round(length(y2)/4),round(length(y2)/4)*2,round(length(y2)/4)*3,length(y2))]
#date2<-date2[c(1,round(length(date2)/4),round(length(date2)/4)*2,round(length(date2)/4)*3,length(date2))]
#sst2<-sst2[c(1,round(length(sst2)/4),round(length(sst2)/4)*2,round(length(sst2)/4)*3,length(sst2))]

x2[which((x2)<0)]<-abs(x2[which((x2)<0)])+(180-abs(x2[which((x2)<0)]))*2  ### To deal with international date line by transforming into a 0-360 format !!

#### Plot number 1 -- Multi-plot
pt<-ggplot(world_map) + geom_map(map=world_map,aes(x=long,y=lat,map_id=id),fill="grey70",color="grey10",alpha=.8)+
scale_x_continuous(limits = if (min(y)>(-45)) {c(min(x2)-1, max(x2)+1)} else {c(0,360)},expand=c(0,0),
breaks=if (min(y)>(-45)) {(round(min(x2)-1,0)):(round(max(x2)+1,0))} else {seq(0,270,90)},
labels=if(min(y)<(-45)) c(0,90,"180/-180",-90) else (round(min(x2)-1,0)):(round(max(x2)+1,0)))+ 
scale_y_continuous(limits =  if (min(y)>(-45)) {c(min(y2)-1, max(y2)+1)} else {c(-90,max(y2))},expand=c(0,0),
breaks=if (min(y)>(-45)) {(round(min(y2)-1,0)):(round(max(y2)+1,0))} else {seq(-80,-40,10)},
labels=if(min(y)<(-45)) seq(-80,-40,10) else (round(min(y2)-1,0)):(round(max(y2)+1,0)))+
scale_colour_gradient2("Sea Surface 
Temperature (°C)",limits=c(min(sst2),max(sst2)),low="blue", mid="yellow",high="red",space="rgb",midpoint=min(sst2)+(max(sst2)-min(sst2))/2)+
xlab("Longitude")+ylab("Latitude")+
theme(panel.background = element_rect(fill='white', colour='black'),panel.grid.major = if (min(y)<(-45)) element_line(colour="black") else element_blank(),
axis.text.x=element_text(colour='black',size=15,vjust=3),
axis.text.y=if(min(y)>(-45)) element_text(colour='black',size=15) else element_text(colour='black',size=15,angle=90,hjust=0.65,vjust=11.5,face="italic"),
axis.title.x=element_text(colour='black',size=20),
axis.title.y=element_text(colour='black',size=20),
axis.ticks.x=if(min(y)>(-45)) element_line(colour='black') else element_blank(),
axis.ticks.y=if(min(y)>(-45)) element_line(colour='black') else element_blank(),
legend.text=element_text(colour='black',size=20),
legend.title=element_text(colour='black',size=20),
legend.key.height=unit(1.5,"cm"),
legend.key.width=unit(1,"cm"),
plot.title=element_text(colour='black',size=20))

if (min(y)<(-45)) pt$coordinates=coord_map(projection="ortho",orientation=c(-90,0,180)) else pt$coordinates=coord_cartesian()
if (min(y)<(-45)) pt<-pt+coord_polar(theta="x",start=pi) else pt<-pt

insetrect <- data.frame(xmin = min(x2)-1, xmax = max(x2)+1, 
    ymin = min(y2)-1, ymax = max(y2)+1)

if (min(y2)>(-45)) lims<-c(112.5,156,-45,-10) else lims<-c(0,360,-90,-20)

study_area<-ggplot(world_map) + geom_map(map=world_map,aes(x=long,y=lat,map_id=id),fill="grey70",color="grey10", alpha=1)+
geom_rect(data = insetrect, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax), alpha=0.5, colour="red", size = 1, linetype=1) +
theme(panel.background = element_rect(fill=rgb(70/255,130/255,180/255,alpha=.5),colour='black'),panel.grid.minor = element_blank(),panel.grid.major = element_blank(),
panel.border=element_blank(),
plot.background=element_blank(),
panel.margin=element_blank(),
axis.text.x=element_blank(),
axis.text.y=element_blank(),
axis.title.x=element_blank(),
axis.title.y=element_blank(),
axis.ticks=element_blank())+
scale_x_continuous(limits = c(lims[1],lims[2]),expand=c(0,0)) + 
scale_y_continuous(limits = c(lims[3],lims[4]),expand=c(0,0))

if (min(y)<(-45)) study_area$coordinates=coord_map(projection="ortho",orientation=c(-90,0,180)) else study_area$coordinates=coord_cartesian()

vppt_ <- viewport(width = 1, height = 1, x = 0.5, y = 0.5)  # the larger map
if (min(y)<(-45)) vpstudy_area_<-viewport(width = 0.25, height = 0.32, x = 0.611, y = 0.8)  else vpstudy_area_ <-viewport(width = 0.25, height = 0.32, x = 0.172, y = 0.8)

filename=paste("plotsst",1,sep="")
png(file = paste(filename,".png",sep=""),width = 1024, height = 720, units = "px",res=92,bg = "white")
plot<-pt+geom_point(aes(x=x2[1],y=y2[1],colour=sst2[1]),size=4)+geom_point(aes(x=x2[1],y=y2[1]),pch=21,size=4.5,colour = "black")+
labs(title=strftime(date2[1],"%d %B %Y %H:%M:%S"))
print(plot, vp = vppt_)
print(study_area, vp = vpstudy_area_)
dev.off()

for (i in 2:length(sst2)){
	filename=paste("plotsst",i,sep="")
	png(file = paste(filename,".png",sep=""),width = 1024, height = 720, units = "px",res=92,bg = "white")
	plot<-pt+geom_point(aes(x=x2[i],y=y2[i],colour=sst2[i]),size=4)+geom_point(aes(x=x2[i],y=y2[i]),pch=21,size=4.5,colour = "black")+
	geom_path(aes(x=x2[c(ifelse(i-100<=0,1,i-100):i)],y=y2[c(ifelse(i-100<=0,1,i-100):i)],colour=sst2[c(ifelse(i-100<=0,1,i-100):i)]),data=data.frame(x2[c(ifelse(i-100<=0,1,i-100):i)],y2[c(ifelse(i-100<=0,1,i-100):i)],sst2[c(ifelse(i-100<=0,1,i-100):i)]),size=1.3)+
	labs(title=strftime(date2[i],"%d %B %Y %H:%M:%S"))
	print(plot, vp = vppt_)
	print(study_area, vp = vpstudy_area_)
	dev.off()
}

#filenames<-c(paste("plot",seq(1,length(sst2),1),".png",sep=""))
#ani.options(ani.height = 560, ani.width = 800,interval = .1,outdir=getwd(),convert=shQuote('C:/Program Files (x86)/ImageMagick-6.8.1-Q16/convert.exe'))
#im.convert(filenames,output=paste(unlist(strsplit(ctd$filename,split="_"))[5],"-","SST",".mpg",sep=""),clean=TRUE)

if (length(sal)==length(which((is.na(sal))==TRUE))) next

########################################################################################## Salinity chart ######################################################################################################
#setwd(file.path(mainDir,subDir))
if(length(which((is.na(sal))==TRUE))==0) date3<-date else date3<-date[-which((is.na(sal))==TRUE)]
if(length(which((is.na(sal))==TRUE))==0) z3<-z else z3<-z[-which((is.na(sal))==TRUE)]
if(length(which((is.na(sal))==TRUE))==0) sal3<-sal else sal3<-sal[-which((is.na(sal))==TRUE)]

br<-if(as.numeric(difftime(date2[length(date2)],date2[1],units="days"))>30) "1 month" else if(as.numeric(difftime(date2[length(date2)],date2[1],units="days"))<7) "1 day" else "1 week"
#
jpeg(filename = paste(unlist(strsplit(unlist(strsplit(ctd$filename,split="Z_"))[2],split="_END"))[1],"_","PSAL",".jpg",sep="")
	,width = 1638, height = 1124, units = "px",res=92,quality=100,bg = "white")
sal_profiles<-qplot(as.Date(date3),-z3,colour=sal3) + geom_point(size=4)+ 
scale_colour_gradient2("Salinity (psu)",limits=c(min(sal3),max(sal3)),low="blue", mid="yellow",high="green",space="rgb",midpoint=min(sal3)+(max(sal3)-min(sal3))/2) + 
xlab("Date")+ylab("Depth (m)")+ labs(title=paste(unlist(strsplit(ctd$filename,split="_"))[5],strftime(date2[1],"%Y%m%d"),": ","PSAL"))+
theme(panel.background = element_rect(fill='white', colour='black'),panel.grid.minor = element_blank(),
axis.text.x=element_text(colour='black',size=15,vjust=3),
axis.text.y=element_text(colour='black',size=15),
axis.title.x=element_text(colour='black',size=20),
axis.title.y=element_text(colour='black',size=20),
axis.ticks=element_line(colour='black'),
legend.text=element_text(colour='black',size=20),
legend.title=element_text(colour='black',size=20),
legend.key.height=unit(1.5,"cm"),
legend.key.width=unit(1,"cm"),
plot.title=element_text(colour='black',size=20))+
scale_x_date(labels=date_format("%d %b %Y"),breaks=br)
print(sal_profiles)
dev.off()

###################################################################################### Surface temperature fluctuation over time ###############################################################################
## Create new directory to store plots
#subsubDir<-"SSSal gif"
#dir.create(file.path(subsubDir))
#setwd(file.path(mainDir,subDir,subsubDir))

if(length(which((is.na(sssal))==TRUE))==0) x2<-x else x2<-x[-which((is.na(sssal))==TRUE)]
if(length(which((is.na(sssal))==TRUE))==0) y2<-y else y2<-y[-which((is.na(sssal))==TRUE)]
date2<-date[which((duplicated(date))==FALSE)]
if(length(which((is.na(sssal))==TRUE))==0) date2<-date2 else date2<-date2[-which((is.na(sssal))==TRUE)]
if(length(which((is.na(sssal))==TRUE))==0) sssal2<-sssal else sssal2<-sssal[-which((is.na(sssal))==TRUE)]

#if(length(x2)>=1000) x2<-x2[seq(1,length(x2),3)] else x2<-x2
#if(length(y2)>=1000) y2<-y2[seq(1,length(y2),3)] else y2<-y2
#if(length(date2)>=1000) date2<-date2[seq(1,length(date2),3)] else date2<-date2
#if(length(sssal2)>=1000) sssal2<-sssal2[seq(1,length(sssal2),3)] else sssal2<-sssal2

#if(length(x2)>=520) x2<-x2[seq(1,length(x2),2)] else x2<-x2
#if(length(y2)>=520) y2<-y2[seq(1,length(y2),2)] else y2<-y2
#if(length(date2)>=520) date2<-date2[seq(1,length(date2),2)] else date2<-date2
#if(length(sssal2)>=520) sssal2<-sssal2[seq(1,length(sssal2),2)] else sssal2<-sssal2

#x2<-x2[c(1,round(length(x2)/4),round(length(x2)/4)*2,round(length(x2)/4)*3,length(x2))]
#y2<-y2[c(1,round(length(y2)/4),round(length(y2)/4)*2,round(length(y2)/4)*3,length(y2))]
#date2<-date2[c(1,round(length(date2)/4),round(length(date2)/4)*2,round(length(date2)/4)*3,length(date2))]
#sssal2<-sssal2[c(1,round(length(sssal2)/4),round(length(sssal2)/4)*2,round(length(sssal2)/4)*3,length(sssal2))]

x2[which((x2)<0)]<-abs(x2[which((x2)<0)])+(180-abs(x2[which((x2)<0)]))*2  ### To deal with international date line by transforming into a 0-360 format !!

#### Plot number 1 -- Multi-plot
pt<-ggplot(world_map) + geom_map(map=world_map,aes(x=long,y=lat,map_id=id),fill="grey70",color="grey10",alpha=.8)+
scale_x_continuous(limits = if (min(y)>(-45)) {c(min(x2)-1, max(x2)+1)} else {c(0,360)},expand=c(0,0),
breaks=if (min(y)>(-45)) {(round(min(x2)-1,0)):(round(max(x2)+1,0))} else {seq(0,270,90)},
labels=if(min(y)<(-45)) c(0,90,"180/-180",-90) else (round(min(x2)-1,0)):(round(max(x2)+1,0)))+ 
scale_y_continuous(limits =  if (min(y)>(-45)) {c(min(y2)-1, max(y2)+1)} else {c(-90,max(y2))},expand=c(0,0),
breaks=if (min(y)>(-45)) {(round(min(y2)-1,0)):(round(max(y2)+1,0))} else {seq(-80,-40,10)},
labels=if(min(y)<(-45)) seq(-80,-40,10) else (round(min(y2)-1,0)):(round(max(y2)+1,0)))+
scale_colour_gradient2("Sea Surface 
Salinity (psu)",limits=c(min(sssal2),max(sssal2)),low="blue", mid="yellow",high="green",space="rgb",midpoint=min(sssal2)+(max(sssal2)-min(sssal2))/2)+
xlab("Longitude")+ylab("Latitude")+
theme(panel.background = element_rect(fill='white', colour='black'),panel.grid.major = if (min(y)<(-45)) element_line(colour="black") else element_blank(),
axis.text.x=element_text(colour='black',size=15,vjust=3),
axis.text.y=if(min(y)>(-45)) element_text(colour='black',size=15) else element_text(colour='black',size=15,angle=90,hjust=0.65,vjust=11.5,face="italic"),
axis.title.x=element_text(colour='black',size=20),
axis.title.y=element_text(colour='black',size=20),
axis.ticks.x=if(min(y)>(-45)) element_line(colour='black') else element_blank(),
axis.ticks.y=if(min(y)>(-45)) element_line(colour='black') else element_blank(),
legend.text=element_text(colour='black',size=20),
legend.title=element_text(colour='black',size=20),
legend.key.height=unit(1.5,"cm"),
legend.key.width=unit(1,"cm"),
plot.title=element_text(colour='black',size=20))

if (min(y)<(-45)) pt$coordinates=coord_map(projection="ortho",orientation=c(-90,0,180)) else pt$coordinates=coord_cartesian()
if (min(y)<(-45)) pt<-pt+coord_polar(theta="x",start=pi) else pt<-pt

insetrect <- data.frame(xmin = min(x2)-1, xmax = max(x2)+1, 
    ymin = min(y2)-1, ymax = max(y2)+1)

if (min(y2)>(-45)) lims<-c(112.5,156,-45,-10) else lims<-c(0,360,-90,-20)

study_area<-ggplot(world_map) + geom_map(map=world_map,aes(x=long,y=lat,map_id=id),fill="grey70",color="grey10", alpha=1)+
geom_rect(data = insetrect, aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax), alpha=0.5, colour="red", size = 1, linetype=1) +
theme(panel.background = element_rect(fill=rgb(70/255,130/255,180/255,alpha=.5),colour='black'),panel.grid.minor = element_blank(),panel.grid.major = element_blank(),
panel.border=element_blank(),
plot.background=element_blank(),
panel.margin=element_blank(),
axis.text.x=element_blank(),
axis.text.y=element_blank(),
axis.title.x=element_blank(),
axis.title.y=element_blank(),
axis.ticks=element_blank())+
scale_x_continuous(limits = c(lims[1],lims[2]),expand=c(0,0)) + 
scale_y_continuous(limits = c(lims[3],lims[4]),expand=c(0,0))

if (min(y)<(-45)) study_area$coordinates=coord_map(projection="ortho",orientation=c(-90,0,180)) else study_area$coordinates=coord_cartesian()

vppt_ <- viewport(width = 1, height = 1, x = 0.5, y = 0.5)  # the larger map
if (min(y)<(-45)) vpstudy_area_<-viewport(width = 0.25, height = 0.32, x = 0.611, y = 0.8)  else vpstudy_area_ <-viewport(width = 0.25, height = 0.32, x = 0.172, y = 0.8)

filename=paste("plotsssal",1,sep="")
png(file = paste(filename,".png",sep=""),width = 1024, height = 720, units = "px",res=92,bg = "white")
plot<-pt+geom_point(aes(x=x2[1],y=y2[1],colour=sssal2[1]),size=4)+geom_point(aes(x=x2[1],y=y2[1]),pch=21,size=4.5,colour = "black")+
labs(title=strftime(date2[1],"%d %B %Y %H:%M:%S"))
print(plot, vp = vppt_)
print(study_area, vp = vpstudy_area_)
dev.off()

for (i in 2:length(sssal2)){
	filename=paste("plotsssal",i,sep="")
	png(file = paste(filename,".png",sep=""),width = 1024, height = 720, units = "px",res=92,bg = "white")
	plot<-pt+geom_point(aes(x=x2[i],y=y2[i],colour=sssal2[i]),size=4)+geom_point(aes(x=x2[i],y=y2[i]),pch=21,size=4.5,colour = "black")+
	geom_path(aes(x=x2[c(ifelse(i-100<=0,1,i-100):i)],y=y2[c(ifelse(i-100<=0,1,i-100):i)],colour=sssal2[c(ifelse(i-100<=0,1,i-100):i)]),data=data.frame(x2[c(ifelse(i-100<=0,1,i-100):i)],y2[c(ifelse(i-100<=0,1,i-100):i)],sssal2[c(ifelse(i-100<=0,1,i-100):i)]),size=1.3)+
	labs(title=strftime(date2[i],"%d %B %Y %H:%M:%S"))
	print(plot, vp = vppt_)
	print(study_area, vp = vpstudy_area_)
	dev.off()
}

#filenames<-c(paste("plot",seq(1,length(sssal2),1),".png",sep=""))
#ani.options(ani.height = 560, ani.width = 800,interval = .1,outdir=getwd(),convert=shQuote('C:/Program Files (x86)/ImageMagick-6.8.1-Q16/convert.exe'))
#im.convert(filenames,output=paste(unlist(strsplit(ctd$filename,split="_"))[5],"-","SSSal",".mpg",sep=""),clean=TRUE)

print(a)
}






#########################################################################################################################################################################################################################################
############################################################################################################### Reporting ############################################################################################################### 
#########################################################################################################################################################################################################################################
rm(list=ls())
library(ncdf)
library(DAAG) ## To get the pause function. Otherwise use the Sys.sleep function to pause the loop for a specified amount of time
library(maps) ## To get a world map
library(raster) ## To be able to plot the gridded netCDF file
library(plotrix) ## To be able to use color functions
library(maptools) ## To be able to read sphapefiles
library(ggplot2) ## For plotting purposes
library(scales) ## For plotting purposes
library(animation)

setwd("C:\\eMii work - Xavier Hoenner\\R\\CTD tags data\\AATAMS data files")
file_name<-dir()[1:153]
report<-matrix(ncol=8,nrow=length(file_name))

for (a in 1:length(file_name)){
setwd("C:\\eMii work - Xavier Hoenner\\R\\CTD tags data")
## CTD tags data
ctd<-open.ncdf(paste("C:/eMii work - Xavier Hoenner/R/CTD tags data/AATAMS data files","/",file_name[a],sep=""))
x<-get.var.ncdf(ctd,"LONGITUDE") # Longitude
y<-get.var.ncdf(ctd,"LATITUDE") # Latitude
z<-get.var.ncdf(ctd,"PRES") # Depth
temp<-get.var.ncdf(ctd,"TEMP") # Temperature
sal<-get.var.ncdf(ctd,"PSAL") # Salinity
par<-get.var.ncdf(ctd,"parentIndex") # Parent Index

time<-get.var.ncdf(ctd,"TIME") # Time
## Attribute a date to each z,temp and sal observation
times<-matrix(ncol=1,nrow=length(par))
for (i in 1:length(par)){
	times[i]<-time[par[i]]
}
date<-as.POSIXlt(times*3600*24,origin="1950-01-01",tz="UTC") # Transform time into calendar date and time

## Transform 9999 values to NA
temp[which((temp)==9999)]<-NA
z[which((z)==9999)]<-NA
sal[which((sal)==9999)]<-NA

## Isolate SST and SSSAL
sst<-temp[which((z)==min(z,na.rm=TRUE))]
if(length(sst)!=length(x)) for (u in 1:length(table(par))){sst[u]<-print(temp[which((par)==u)[1]])}
sssal<-sal[which((z)==min(z,na.rm=TRUE))]
if(length(sssal)!=length(x)) for (u in 1:length(table(par))){sssal[u]<-print(sal[which((par)==u)[1]])}

if(length(which((is.na(sst))==TRUE))==0) x2<-x else x2<-x[-which((is.na(sst))==TRUE)]
if(length(which((is.na(sst))==TRUE))==0) y2<-y else y2<-y[-which((is.na(sst))==TRUE)]
date2<-date[which((duplicated(date))==FALSE)]
if(length(which((is.na(sst))==TRUE))==0) date2<-date2 else date2<-date2[-which((is.na(sst))==TRUE)]
if(length(which((is.na(sst))==TRUE))==0) sst2<-sst else sst2<-sst[-which((is.na(sst))==TRUE)]
if(length(which((is.na(sssal))==TRUE))==0) x2<-x else x2<-x[-which((is.na(sssal))==TRUE)]
if(length(which((is.na(sssal))==TRUE))==0) y2<-y else y2<-y[-which((is.na(sssal))==TRUE)]
date2<-date[which((duplicated(date))==FALSE)]
if(length(which((is.na(sssal))==TRUE))==0) date2<-date2 else date2<-date2[-which((is.na(sssal))==TRUE)]
if(length(which((is.na(sssal))==TRUE))==0) sssal2<-sssal else sssal2<-sssal[-which((is.na(sssal))==TRUE)]


report[a,1]<-unlist(strsplit(ctd$filename,split="_"))[5]
report[a,2]<-length(temp)-length(which((is.na(temp))==TRUE))
report[a,3]<-length(sal)-length(which((is.na(sal))==TRUE))
report[a,4]<-length(sst)-length(which((is.na(sst))==TRUE))
report[a,5]<-length(sssal)-length(which((is.na(sssal))==TRUE))
report[a,6]<-paste(head(date[which((date)==min(date))],n=1L)$mday,"-",head(date[which((date)==min(date))],n=1L)$mon+1,"-",head(date[which((date)==min(date))],n=1L)$year+1900,sep="")
report[a,7]<-paste(tail(date[which((date)==max(date))],n=1L)$mday,"-",tail(date[which((date)==max(date))],n=1L)$mon+1,"-",tail(date[which((date)==max(date))],n=1L)$year+1900,sep="")
report[a,8]<-round(difftime(tail(date[which((date)==max(date))],n=1L),date[which((date)==min(date))][1],units="days"),1)

}

colnames(report)<-c("animal_id","No_TEMP_observations","No_PSAL_observations","No_SST_observations","No_SSSAL_observations","date_start","date_end","coverage_duration_days")

write.table(report,"report_AATAMS_SatTags.csv",sep=",",row.names=FALSE,col.names=TRUE)
