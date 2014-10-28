#############################################################################################################################################################################################################################################
############################################################################################# Sea surface temperature #######################################################################################################################
#############################################################################################################################################################################################################################################
rm(list=ls())
library(ncdf)
library(plotrix) ## To be able to use color functions
library(maptools) ## To be able to read sphapefiles
library(ggplot2) ## For plotting purposes
library(scales) ## For plotting purposes
library(animation)

setwd("C:\\eMii work - Xavier Hoenner\\R\\CTD tags data\\AATAMS data files")
file_name<-dir()[1:153]
alldata<-matrix(ncol=6)

for (f in 1:length(file_name)){
setwd("C:\\eMii work - Xavier Hoenner\\R\\CTD tags data")
## CTD tags data
ctd<-open.ncdf(paste("C:/eMii work - Xavier Hoenner/R/CTD tags data/AATAMS data files","/",file_name[f],sep=""))
x<-get.var.ncdf(ctd,"LONGITUDE") # Longitude
y<-get.var.ncdf(ctd,"LATITUDE") # Latitude
z<-get.var.ncdf(ctd,"PRES") # Depth
temp<-get.var.ncdf(ctd,"TEMP") # Temperature
par<-get.var.ncdf(ctd,"parentIndex") # Parent Index
id<-unlist(strsplit(ctd$filename,split="_"))[5]

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

if(length(which((is.na(sst))==TRUE))==0) x2<-x else x2<-x[-which((is.na(sst))==TRUE)]
if(length(which((is.na(sst))==TRUE))==0) y2<-y else y2<-y[-which((is.na(sst))==TRUE)]
date2<-date[which((duplicated(date))==FALSE)]
if(length(which((is.na(sst))==TRUE))==0) date2<-date2 else date2<-date2[-which((is.na(sst))==TRUE)]
if(length(which((is.na(sst))==TRUE))==0) sst2<-sst else sst2<-sst[-which((is.na(sst))==TRUE)]

if(length(x2)>=1000) x2<-x2[seq(1,length(x2),3)] else x2<-x2
if(length(y2)>=1000) y2<-y2[seq(1,length(y2),3)] else y2<-y2
if(length(date2)>=1000) date2<-date2[seq(1,length(date2),3)] else date2<-date2
if(length(sst2)>=1000) sst2<-sst2[seq(1,length(sst2),3)] else sst2<-sst2

if(length(x2)>=520) x2<-x2[seq(1,length(x2),2)] else x2<-x2
if(length(y2)>=520) y2<-y2[seq(1,length(y2),2)] else y2<-y2
if(length(date2)>=520) date2<-date2[seq(1,length(date2),2)] else date2<-date2
if(length(sst2)>=520) sst2<-sst2[seq(1,length(sst2),2)] else sst2<-sst2

x2[which((x2)<0)]<-abs(x2[which((x2)<0)])+(180-abs(x2[which((x2)<0)]))*2  ### To deal with international date line by transforming into a 0-360 format !!

seld<-which((as.Date(date2))==row.names(table(as.Date(date2)))[1])
x3<-mean(x2[seld],na.rm=TRUE)
y3<-mean(y2[seld],na.rm=TRUE)
date3<-row.names(table(as.Date(date2)))[1]
sst3<-mean(sst2[seld],na.rm=TRUE)

for (d in 2:length(table(as.Date(date2)))){
	seld<-which((as.Date(date2))==row.names(table(as.Date(date2)))[d])
	x3<-c(x3,mean(x2[seld],na.rm=TRUE))
	y3<-c(y3,mean(y2[seld],na.rm=TRUE))
	date3<-c(date3,row.names(table(as.Date(date2)))[d])
	sst3<-c(sst3,mean(sst2[seld],na.rm=TRUE))
}

if (f==1) alldata<-data.frame(rep(id,length(x3)),x3,y3,strptime(date3,"%Y-%m-%d"),sst3,seq(1,length(x3),1)) else alldata<-rbind(alldata,data.frame(rep(id,length(x3)),x3,y3,strptime(date3,"%Y-%m-%d"),sst3,seq(1,length(x3),1)))

}

colnames(alldata)<-c("id","x2","y2","date2","sst2","obs_no")

alldata2<-alldata[order(alldata$date2),]

## Create new directory to store plots
dir.create("C:/eMii work - Xavier Hoenner/R/CTD tags data/All deployments")
setwd("C:/eMii work - Xavier Hoenner/R/CTD tags data/All deployments")

world_map <- readShapeSpatial("C:\\eMii work - Xavier Hoenner\\R\\CTD tags data\\ne_50m_admin_0_countries\\ne_50m_admin_0_countries.shp")
world_map<-fortify(world_map)[which((fortify(world_map)$lat)<(-10)),]

#world_map$long[which((world_map$long)<0)]<-abs(world_map$long[which((world_map$long)<0)])+(180-abs(world_map$long[which((world_map$long)<0)]))*2  ### To deal with international date line by transforming into a 0-360 format !!
mp1<-world_map
mp2<-world_map
mp2$long<-mp2$long+360
mp2$group<- as.numeric(paste(mp1$group)) + max(as.numeric(paste(mp1$group)))+1
br<-as.numeric(row.names(table(levels(mp1$group))))+max(as.numeric(row.names(table(levels(mp1$group)))))+1

for (i in 1:length(as.numeric(levels(mp1$group)))){
	if (length(which((br)==br[i]))==1) br[i]<-br[i] else br[i]<-br[i]+runif(1,500,770)
}

for (i in 1:length(as.numeric(levels(mp1$group)))){
	if (length(which((br)==br[i]))==1) br[i]<-br[i] else br[i]<-br[i]+701
}
mp2$group<-cut(mp2$group,breaks=br)
mp2<-mp2[-which((mp2$piece)==10),]
mp2<-mp2[-which((mp2$piece)==50),]
mp <- rbind(mp1, mp2)

#### Plot number 1 -- Multi-plot
pt<-ggplot(mp) + geom_map(map=mp,aes(x=long,y=lat,map_id=id,group=group),fill="grey70",color="grey10",alpha=.8)+
scale_x_continuous(limits = c(25,225),expand=c(0,0),
breaks=seq(0,270,90),
labels=seq(0,270,90))+ 
scale_y_continuous(limits =  c(-86,-10),expand=c(0,0),
breaks=seq(-80,-10,10),
labels= seq(-80,-10,10))+
scale_colour_gradient2("Sea Surface 
Temperature (°C)",limits=c(min(alldata2$sst2),max(alldata2$sst2)),low="blue", mid="yellow",high="red",space="rgb",midpoint=min(alldata2$sst2)+(max(alldata2$sst2)-min(alldata2$sst2))/2)+
xlab("Longitude")+ylab("Latitude")+
theme(panel.background = element_rect(fill='white', colour='black'),panel.grid.major = element_blank(),
axis.text.x=element_text(colour='black',size=15,vjust=3),
axis.text.y=element_text(colour='black',size=15),
axis.title.x=element_text(colour='black',size=20),
axis.title.y=element_text(colour='black',size=20),
axis.ticks.x=element_line(colour='black'),
axis.ticks.y=element_line(colour='black'),
legend.text=element_text(colour='black',size=20),
legend.title=element_text(colour='black',size=20),
legend.key.height=unit(1.5,"cm"),
legend.key.width=unit(1,"cm"),
plot.title=element_text(colour='black',size=20))

vppt_ <- viewport(width = 1, height = 1, x = 0.5, y = 0.5)  # the larger map

ids<-row.names(table(alldata2$id))
summaryobs<-data.frame(ncol=3,nrow=length(ids))
for (i in 1:length(ids)){
	summaryobs[i,1]<-ids[i]
	summaryobs[i,2]<-as.character(alldata2$date2[tail(which((alldata2$id)==ids[i]),n=1)])
	summaryobs[i,3]<-alldata2$obs_no[tail(which((alldata2$id)==ids[i]),n=1)]
}

tab<-matrix(nrow=length(row.names(table(alldata2$date2))),ncol=length(ids)+1)
for (i in 1:length(row.names(table(alldata2$date2)))){
	print(i)
	tab[i,1]<-row.names(table(alldata2$date2))[i]
		for (d in 1:nrow(summaryobs)){
			sel<-alldata2[which((summaryobs[d,1])==alldata2$id),]
			tab[i,d+1]<-ifelse(length(which((as.character(sel$date2))==row.names(table(alldata2$date2))[i]))>0,sel$obs_no[which((as.character(sel$date2))==row.names(table(alldata2$date2))[i])],NA)
}}

colnames(tab)<-c("Date",paste(summaryobs[,1]))

write.table(tab,"C:/eMii work - Xavier Hoenner/R/CTD tags data/All deployments/tabsst.csv",col.names=TRUE,row.names=FALSE,sep=",")
#tab2<-read.table("C:/eMii work - Xavier Hoenner/R/CTD tags data/All deployments/tabsst.csv",header=TRUE,sep=",")


for (dat in 1:length(row.names(table(alldata2$date2)))){
	seldat<-which((as.character(alldata2$date2))==row.names(table(alldata2$date2))[dat])
	seldat2<-seldat[which((alldata2$obs_no[seldat])>1)]
	alldata3<-alldata2[which((alldata2$id)==alldata2$id[seldat2][1]),][which((alldata2$obs_no[which((alldata2$id)==alldata2$id[seldat2][1])])<=alldata2$obs_no[seldat2][1]),]
	for (s in 2:length(seldat2)){
	alldata3<-rbind(alldata3,alldata2[which((alldata2$id)==alldata2$id[seldat2][s]),][which((alldata2$obs_no[which((alldata2$id)==alldata2$id[seldat2][s])])<=alldata2$obs_no[seldat2][s]),])
	}
	alldata3<-alldata3[-which((duplicated(alldata3))==TRUE),]
	if (length(tab[1:dat,2])>length(which((is.na(tab[1:dat,2]))==TRUE))) alldata4<-alldata2[which((alldata2$id)==summaryobs[1,1]),]
	if (nrow(alldata4)>nrow(alldata4[1:which((as.character(alldata4$date2))==tab[which((as.numeric(tab[1:dat,2]))==max(as.numeric(tab[1:dat,2]),na.rm=TRUE)),1]),])) alldata5<-alldata4[1:which((as.character(alldata4$date2))==tab[which((as.numeric(tab[1:dat,2]))==max(as.numeric(tab[1:dat,2]),na.rm=TRUE)),1]),] else alldata5<-matrix(ncol=6)
	colnames(alldata5)<-c("id","x2","y2","date2","sst2","obs_no")
	for (su in 2:nrow(summaryobs)){
		if (length(tab[1:dat,su+1])>length(which((is.na(tab[1:dat,su+1]))==TRUE))) alldata4<-alldata2[which((alldata2$id)==summaryobs[su,1]),] else next
		if (nrow(alldata4)>nrow(alldata4[1:which((as.character(alldata4$date2))==tab[which((as.numeric(tab[1:dat,su+1]))==max(as.numeric(tab[1:dat,su+1]),na.rm=TRUE)),1]),])) alldata5<-rbind(alldata5,alldata4[1:which((as.character(alldata4$date2))==tab[which((as.numeric(tab[1:dat,su+1]))==max(as.numeric(tab[1:dat,su+1]),na.rm=TRUE)),1]),])
		}

	filename=paste("plotsst",dat,sep="")
	png(file = paste(filename,".png",sep=""),width = 1920, height = 1080, units = "px",res=92,bg = "white")
	plot<-pt+geom_point(aes(x=x2,y=y2,colour=sst2,group=id),size=4,data=alldata2[seldat,])+
	geom_point(aes(x=x2,y=y2,group=id),data=alldata2[seldat,],pch=21,size=4.5,colour = "black")+
	labs(title=strftime(row.names(table(alldata2$date2))[dat],"%d %B %Y"))
	if (nrow(alldata5)>1) plot<-plot+geom_path(aes(x=x2,y=y2,colour=sst2,group=id),data=alldata5,size=1.3)
	if (nrow(alldata3)>0) plot<-plot+geom_path(aes(x=x2,y=y2,colour=sst2,group=id),data=alldata3,size=1.3)
	print(plot, vp = vppt_)
	dev.off()
}





#############################################################################################################################################################################################################################################
############################################################################################### Sea surface salinity ########################################################################################################################
#############################################################################################################################################################################################################################################
rm(list=ls())
library(ncdf)
library(plotrix) ## To be able to use color functions
library(maptools) ## To be able to read sphapefiles
library(ggplot2) ## For plotting purposes
library(scales) ## For plotting purposes
library(animation)

setwd("C:\\eMii work - Xavier Hoenner\\R\\CTD tags data\\AATAMS data files")
file_name<-dir()[1:153]
alldata<-matrix(ncol=6)

for (f in 1:length(file_name)){
setwd("C:\\eMii work - Xavier Hoenner\\R\\CTD tags data")
## CTD tags data
ctd<-open.ncdf(paste("C:/eMii work - Xavier Hoenner/R/CTD tags data/AATAMS data files","/",file_name[f],sep=""))
x<-get.var.ncdf(ctd,"LONGITUDE") # Longitude
y<-get.var.ncdf(ctd,"LATITUDE") # Latitude
z<-get.var.ncdf(ctd,"PRES") # Depth
sal<-get.var.ncdf(ctd,"PSAL") # Salinity
par<-get.var.ncdf(ctd,"parentIndex") # Parent Index
id<-unlist(strsplit(ctd$filename,split="_"))[5]

time<-get.var.ncdf(ctd,"TIME") # Time
## Attribute a date to each z,temp and sal observation
times<-matrix(ncol=1,nrow=length(par))
for (i in 1:length(par)){
	times[i]<-time[par[i]]
}
date<-as.POSIXlt(times*3600*24,origin="1950-01-01",tz="UTC") # Transform time into calendar date and time

## Transform 9999 values to NA
z[which((z)==9999)]<-NA
sal[which((sal)==9999)]<-NA

## Isolate SSSAL
sssal<-sal[which((z)==min(z,na.rm=TRUE))]
if(length(sssal)!=length(x)) for (u in 1:length(table(par))){sssal[u]<-print(sal[which((par)==u)[1]])}

if(length(which((is.na(sssal))==TRUE))==0) x2<-x else x2<-x[-which((is.na(sssal))==TRUE)]
if(length(which((is.na(sssal))==TRUE))==0) y2<-y else y2<-y[-which((is.na(sssal))==TRUE)]
date2<-date[which((duplicated(date))==FALSE)]
if(length(which((is.na(sssal))==TRUE))==0) date2<-date2 else date2<-date2[-which((is.na(sssal))==TRUE)]
if(length(which((is.na(sssal))==TRUE))==0) sssal2<-sssal else sssal2<-sssal[-which((is.na(sssal))==TRUE)]

if(length(x2)>=1000) x2<-x2[seq(1,length(x2),3)] else x2<-x2
if(length(y2)>=1000) y2<-y2[seq(1,length(y2),3)] else y2<-y2
if(length(date2)>=1000) date2<-date2[seq(1,length(date2),3)] else date2<-date2
if(length(sssal2)>=1000) sssal2<-sssal2[seq(1,length(sssal2),3)] else sssal2<-sssal2

if(length(x2)>=520) x2<-x2[seq(1,length(x2),2)] else x2<-x2
if(length(y2)>=520) y2<-y2[seq(1,length(y2),2)] else y2<-y2
if(length(date2)>=520) date2<-date2[seq(1,length(date2),2)] else date2<-date2
if(length(sssal2)>=520) sssal2<-sssal2[seq(1,length(sssal2),2)] else sssal2<-sssal2

x2[which((x2)<0)]<-abs(x2[which((x2)<0)])+(180-abs(x2[which((x2)<0)]))*2  ### To deal with international date line by transforming into a 0-360 format !!

seld<-which((as.Date(date2))==row.names(table(as.Date(date2)))[1])
x3<-mean(x2[seld],na.rm=TRUE)
y3<-mean(y2[seld],na.rm=TRUE)
date3<-row.names(table(as.Date(date2)))[1]
sssal3<-mean(sssal2[seld],na.rm=TRUE)

for (d in 2:length(table(as.Date(date2)))){
	seld<-which((as.Date(date2))==row.names(table(as.Date(date2)))[d])
	x3<-c(x3,mean(x2[seld],na.rm=TRUE))
	y3<-c(y3,mean(y2[seld],na.rm=TRUE))
	date3<-c(date3,row.names(table(as.Date(date2)))[d])
	sssal3<-c(sssal3,mean(sssal2[seld],na.rm=TRUE))
}

if(length(date3)==0) x3<-NA
if(length(date3)==0) y3<-NA
if(length(date3)==0) sssal3<-NA
if(length(date3)==0) date3<-NA

if (f==1) alldata<-data.frame(rep(id,length(x3)),x3,y3,strptime(date3,"%Y-%m-%d"),sssal3,seq(1,length(x3),1)) else alldata<-rbind(alldata,data.frame(rep(id,length(x3)),x3,y3,strptime(date3,"%Y-%m-%d"),sssal3,seq(1,length(x3),1)))

}

colnames(alldata)<-c("id","x2","y2","date2","sssal2","obs_no")

alldata2<-alldata[order(alldata$date2),]
alldata2<-alldata2[-which((is.na(alldata2[,2]))==TRUE),]

## Create new directory to store plots
dir.create("C:/eMii work - Xavier Hoenner/R/CTD tags data/All deployments")
setwd("C:/eMii work - Xavier Hoenner/R/CTD tags data/All deployments")

world_map <- readShapeSpatial("C:\\eMii work - Xavier Hoenner\\R\\CTD tags data\\ne_50m_admin_0_countries\\ne_50m_admin_0_countries.shp")
world_map<-fortify(world_map)[which((fortify(world_map)$lat)<(-10)),]

#world_map$long[which((world_map$long)<0)]<-abs(world_map$long[which((world_map$long)<0)])+(180-abs(world_map$long[which((world_map$long)<0)]))*2  ### To deal with international date line by transforming into a 0-360 format !!
mp1<-world_map
mp2<-world_map
mp2$long<-mp2$long+360
mp2$group<- as.numeric(paste(mp1$group)) + max(as.numeric(paste(mp1$group)))+1
br<-as.numeric(row.names(table(levels(mp1$group))))+max(as.numeric(row.names(table(levels(mp1$group)))))+1

for (i in 1:length(as.numeric(levels(mp1$group)))){
	if (length(which((br)==br[i]))==1) br[i]<-br[i] else br[i]<-br[i]+runif(1,500,770)
}

for (i in 1:length(as.numeric(levels(mp1$group)))){
	if (length(which((br)==br[i]))==1) br[i]<-br[i] else br[i]<-br[i]+701
}
mp2$group<-cut(mp2$group,breaks=br)
mp2<-mp2[-which((mp2$piece)==10),]
mp2<-mp2[-which((mp2$piece)==50),]
mp <- rbind(mp1, mp2)

#### Plot number 1 -- Multi-plot
pt<-ggplot(mp) + geom_map(map=mp,aes(x=long,y=lat,map_id=id,group=group),fill="grey70",color="grey10",alpha=.8)+
scale_x_continuous(limits = c(25,225),expand=c(0,0),
breaks=seq(0,270,90),
labels=seq(0,270,90))+ 
scale_y_continuous(limits =  c(-86,-10),expand=c(0,0),
breaks=seq(-80,-10,10),
labels= seq(-80,-10,10))+
scale_colour_gradient2("Sea Surface 
Salinity (psu)",limits=c(min(alldata2$sssal2),max(alldata2$sssal2)),low="blue", mid="yellow",high="green",space="rgb",midpoint=min(alldata2$sssal2)+(max(alldata2$sssal2)-min(alldata2$sssal2))/2)+
xlab("Longitude")+ylab("Latitude")+
theme(panel.background = element_rect(fill='white', colour='black'),panel.grid.major = element_blank(),
axis.text.x=element_text(colour='black',size=15,vjust=3),
axis.text.y=element_text(colour='black',size=15),
axis.title.x=element_text(colour='black',size=20),
axis.title.y=element_text(colour='black',size=20),
axis.ticks.x=element_line(colour='black'),
axis.ticks.y=element_line(colour='black'),
legend.text=element_text(colour='black',size=20),
legend.title=element_text(colour='black',size=20),
legend.key.height=unit(1.5,"cm"),
legend.key.width=unit(1,"cm"),
plot.title=element_text(colour='black',size=20))

vppt_ <- viewport(width = 1, height = 1, x = 0.5, y = 0.5)  # the larger map

ids<-row.names(table(alldata2$id)[which((table(alldata2$id))>0)])
summaryobs<-data.frame(ncol=3,nrow=length(ids))
for (i in 1:length(ids)){
	summaryobs[i,1]<-ids[i]
	summaryobs[i,2]<-as.character(alldata2$date2[tail(which((alldata2$id)==ids[i]),n=1)])
	summaryobs[i,3]<-alldata2$obs_no[tail(which((alldata2$id)==ids[i]),n=1)]
}

tab<-matrix(nrow=length(row.names(table(alldata2$date2))),ncol=length(ids)+1)
for (i in 409:length(row.names(table(alldata2$date2)))){
	print(i)
	tab[i,1]<-row.names(table(alldata2$date2))[i]
		for (d in 1:nrow(summaryobs)){
			sel<-alldata2[which((summaryobs[d,1])==alldata2$id),]
			tab[i,d+1]<-ifelse(length(which((as.character(sel$date2))==row.names(table(alldata2$date2))[i]))>0,sel$obs_no[which((as.character(sel$date2))==row.names(table(alldata2$date2))[i])],NA)
}}

colnames(tab)<-c("Date",paste(summaryobs[,1]))

write.table(tab,"C:/eMii work - Xavier Hoenner/R/CTD tags data/All deployments/tabsal.csv",col.names=TRUE,row.names=FALSE,sep=",")
tab<-read.table("C:/eMii work - Xavier Hoenner/R/CTD tags data/All deployments/tabsal.csv",header=TRUE,sep=",")


for (dat in 1:length(row.names(table(alldata2$date2)))){
	seldat<-which((as.character(alldata2$date2))==row.names(table(alldata2$date2))[dat])
	seldat2<-seldat[which((alldata2$obs_no[seldat])>1)]
	alldata3<-alldata2[which((alldata2$id)==alldata2$id[seldat2][1]),][which((alldata2$obs_no[which((alldata2$id)==alldata2$id[seldat2][1])])<=alldata2$obs_no[seldat2][1]),]
	for (s in 2:length(seldat2)){
	alldata3<-rbind(alldata3,alldata2[which((alldata2$id)==alldata2$id[seldat2][s]),][which((alldata2$obs_no[which((alldata2$id)==alldata2$id[seldat2][s])])<=alldata2$obs_no[seldat2][s]),])
	}
	alldata3<-alldata3[-which((duplicated(alldata3))==TRUE),]
	if (length(tab[1:dat,2])>length(which((is.na(tab[1:dat,2]))==TRUE))) alldata4<-alldata2[which((alldata2$id)==summaryobs[1,1]),]
	if (nrow(alldata4)>nrow(alldata4[1:which((as.character(alldata4$date2))==tab[which((as.numeric(tab[1:dat,2]))==max(as.numeric(tab[1:dat,2]),na.rm=TRUE)),1]),])) alldata5<-alldata4[1:which((as.character(alldata4$date2))==tab[which((as.numeric(tab[1:dat,2]))==max(as.numeric(tab[1:dat,2]),na.rm=TRUE)),1]),] else alldata5<-matrix(ncol=6)
	colnames(alldata5)<-c("id","x2","y2","date2","sssal2","obs_no")
	for (su in 2:nrow(summaryobs)){
		if (length(tab[1:dat,su+1])>length(which((is.na(tab[1:dat,su+1]))==TRUE))) alldata4<-alldata2[which((alldata2$id)==summaryobs[su,1]),] else next
		if (nrow(alldata4)>nrow(alldata4[1:which((as.character(alldata4$date2))==tab[which((as.numeric(tab[1:dat,su+1]))==max(as.numeric(tab[1:dat,su+1]),na.rm=TRUE)),1]),])) alldata5<-rbind(alldata5,alldata4[1:which((as.character(alldata4$date2))==tab[which((as.numeric(tab[1:dat,su+1]))==max(as.numeric(tab[1:dat,su+1]),na.rm=TRUE)),1]),])
		}

	filename=paste("plotsssal",dat,sep="")
	png(file = paste(filename,".png",sep=""),width = 1920, height = 1080, units = "px",res=92,bg = "white")
	plot<-pt+geom_point(aes(x=x2,y=y2,colour=sssal2,group=id),size=4,data=alldata2[seldat,])+
	geom_point(aes(x=x2,y=y2,group=id),data=alldata2[seldat,],pch=21,size=4.5,colour = "black")+
	labs(title=strftime(row.names(table(alldata2$date2))[dat],"%d %B %Y"))
	if (nrow(alldata5)>1) plot<-plot+geom_path(aes(x=x2,y=y2,colour=sssal2,group=id),data=alldata5,size=1.3)
	if (nrow(alldata3)>0) plot<-plot+geom_path(aes(x=x2,y=y2,colour=sssal2,group=id),data=alldata3,size=1.3)
	print(plot, vp = vppt_)
	dev.off()
}


