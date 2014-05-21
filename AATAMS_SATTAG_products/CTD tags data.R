rm(list=ls())
setwd("C:\\eMii work - Xavier Hoenner\\R\\CTD tags data")
library(ncdf)
library(DAAG) ## To get the pause function. Otherwise use the Sys.sleep function to pause the loop for a specified amount of time
library(maps) ## To get a world map
library(raster) ## To be able to plot the gridded netCDF file
library(plotrix) ## To be able to use color functions
library(maptools) ## To be able to read sphapefiles
library(ggplot2) ## For plotting purposes
library(scales) ## For plotting purposes

## CTD tags data
ctd<-open.ncdf("IMOS_AATAMS-SATTAG_TSP_20091126T104600Z_ct61-04-09_END-20100308T025400Z_FV00 (1).nc")
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
sssal<-sal[which((z)==min(z,na.rm=TRUE))]

############################################################################################################################################################
########################################################################## Plots ###########################################################################
############################################################################################################################################################

####################### Multiplot function ####################### 
multiplot <- function(..., plotlist=NULL, file, cols=1, layout=NULL) {
  require(grid)

  # Make a list from the ... arguments and plotlist
  plots <- c(list(...), plotlist)

  numPlots = length(plots)

  # If layout is NULL, then use 'cols' to determine layout
  if (is.null(layout)) {
    # Make the panel
    # ncol: Number of columns of plots
    # nrow: Number of rows needed, calculated from # of cols
    layout <- matrix(seq(1, cols * ceiling(numPlots/cols)),
                    ncol = cols, nrow = ceiling(numPlots/cols))
  }

 if (numPlots==1) {
    print(plots[[1]])

  } else {
    # Set up the page
    grid.newpage()
    pushViewport(viewport(layout = grid.layout(nrow(layout), ncol(layout))))

    # Make each plot, in the correct location
    for (i in 1:numPlots) {
      # Get the i,j matrix positions of the regions that contain this subplot
      matchidx <- as.data.frame(which(layout == i, arr.ind = TRUE))

      print(plots[[i]], vp = viewport(layout.pos.row = matchidx$row,
                                      layout.pos.col = matchidx$col))
    }
  }
}
####################### End ####################### 

world_map <- readShapeSpatial("C:\\eMii work - Xavier Hoenner\\R\\CTD tags data\\ne_50m_admin_0_countries\\ne_50m_admin_0_countries.shp")
world_map <- fortify(world_map)

#################################################################### MULTIPLOT ###########################################################################
x2<-x[-which((is.na(sst))==TRUE)]
y2<-y[-which((is.na(sst))==TRUE)]
sst2<-sst[-which((is.na(sst))==TRUE)]
#### Plot number 1 -- Multi-plot
p1<-ggplot(world_map) + geom_map(map=world_map,aes(x=long,y=lat,map_id=id),fill="grey50",color="grey10")+
geom_point(aes(x=x2,y=y2,colour=sst2),data=data.frame(x2,y2,sst2))+
scale_colour_gradient2("Sea Surface 
Temperature (°C)",limits=c(min(sst2),max(sst2)),low="blue", mid="yellow",high="red",space="rgb",midpoint=min(sst2)+(max(sst2)-min(sst2))/2)+
scale_x_continuous(limits = c(min(x2)-0.5, max(x2)+0.5),expand=c(0,0),breaks=(round(min(x2)-0.5,0)):(round(max(x2)+0.5,0))) + 
scale_y_continuous(limits = c(min(y2)-0.5, max(y2)+0.5),expand=c(0,0),breaks=(round(min(y2)-0.5,0)):(round(max(y2)+0.5,0))) +
xlab("Longitude")+ylab("Latitude")+
theme(panel.background = element_rect(fill='white', colour='black'),panel.grid.minor = element_blank(),
axis.text.x=element_text(colour='black',size=10,vjust=3),
axis.text.y=element_text(colour='black',size=10,hjust=3),
axis.title.x=element_text(colour='black',size=15),
axis.title.y=element_text(colour='black',size=15))

##
date2<-date[-which((is.na(temp))==TRUE)]
z2<-z[-which((is.na(temp))==TRUE)]
temp2<-temp[-which((is.na(temp))==TRUE)]
##
p2<-qplot(as.Date(date2),-z2,colour=temp2) + 
scale_colour_gradient2("Temperature (°C)",limits=c(min(temp2),max(temp2)),low="blue", mid="yellow",high="red",space="rgb",midpoint=min(temp2)+(max(temp2)-min(temp2))/2) + 
xlab("Date")+ylab("Depth (m)")+
theme(panel.background = element_rect(fill='white', colour='black'),panel.grid.minor = element_blank(),
axis.text.x=element_text(colour='black',size=10,vjust=3),
axis.text.y=element_text(colour='black',size=10),
axis.title.x=element_text(colour='black',size=15),
axis.title.y=element_text(colour='black',size=15))+
scale_x_date(labels=date_format("%d %b %Y"),breaks="1 month")

### IF SALINITY DATA ARE AVAILABLE
x3<-x[-which((is.na(sssal))==TRUE)]
y3<-y[-which((is.na(sssal))==TRUE)]
sssal3<-sssal[-which((is.na(sssal))==TRUE)]
p3<-ggplot(world_map) + geom_map(map=world_map,aes(x=long,y=lat,map_id=id),fill="grey50",color="grey10")+
geom_point(aes(x=x3,y=y3,colour=sssal3),data=data.frame(x3,y3,sssal3))+
scale_colour_gradient2("Sea Surface 
Salinity (psu)",limits=c(min(sssal3),max(sssal3)),low="blue", mid="yellow",high="green",space="rgb",midpoint=min(sssal3)+(max(sssal3)-min(sssal3))/2)+
scale_x_continuous(limits = c(min(x3)-1, max(x3)+1),expand=c(0,0),breaks=(round(min(x3)-1,0)):(round(max(x3)+1,0))) + 
scale_y_continuous(limits = c(min(y3)-1, max(y3)+1),expand=c(0,0),breaks=(round(min(y3)-1,0)):(round(max(y3)+1,0))) +
xlab("Longitude")+ylab("Latitude")+
theme(panel.background = element_rect(fill='white', colour='black'),panel.grid.minor = element_blank(),
axis.text.x=element_text(colour='black',size=10,vjust=3),
axis.text.y=element_text(colour='black',size=10,hjust=3),
axis.title.x=element_text(colour='black',size=15),
axis.title.y=element_text(colour='black',size=15))

date3<-date[-which((is.na(sal))==TRUE)]
z3<-z[-which((is.na(sal))==TRUE)]
sal3<-sal[-which((is.na(sal))==TRUE)]
p4<-qplot(as.Date(date3),-z3,colour=sal3) + 
scale_colour_gradient2("Salinity (psu)",limits=c(min(sal3),max(sal3)),low="blue", mid="yellow",high="green",space="rgb",midpoint=min(sal3)+(max(sal3)-min(sal3))/2) + 
xlab("Date")+ylab("Depth (m)")+
theme(panel.background = element_rect(fill='white', colour='black'),panel.grid.minor = element_blank(),
axis.text.x=element_text(colour='black',size=10,vjust=3),
axis.text.y=element_text(colour='black',size=10),
axis.title.x=element_text(colour='black',size=15),
axis.title.y=element_text(colour='black',size=15))+
scale_x_date(labels=date_format("%d %b %Y"),breaks="1 month")

multiplot(p1,p2,p3,p4,cols=2)



################################################################## FLUCTUATION OVER TIME ###################################################################
x2<-x[-which((is.na(sst))==TRUE)]
y2<-y[-which((is.na(sst))==TRUE)]
date2<-date[which((duplicated(date))==FALSE)]
date2<-date2[-which((is.na(sst))==TRUE)]
sst2<-sst[-which((is.na(sst))==TRUE)]
#### Plot number 1 -- Multi-plot
pt<-ggplot(world_map) + geom_map(map=world_map,aes(x=long,y=lat,map_id=id),fill="grey50",color="grey10")+
scale_x_continuous(limits = c(min(x2)-1, max(x2)+1),expand=c(0,0),breaks=(round(min(x2)-1,0)):(round(max(x2)+1,0))) + 
scale_y_continuous(limits = c(min(y2)-1, max(y2)+1),expand=c(0,0),breaks=(round(min(y2)-1,0)):(round(max(y2)+1,0))) +
scale_colour_gradient2("Sea Surface 
Temperature (°C)",limits=c(min(sst2),max(sst2)),low="blue", mid="yellow",high="red",space="rgb",midpoint=min(sst2)+(max(sst2)-min(sst2))/2)+
xlab("Longitude")+ylab("Latitude")+
theme(panel.background = element_rect(fill='white', colour='black'),panel.grid.minor = element_blank(),
axis.text.x=element_text(colour='black',size=20,vjust=3),
axis.text.y=element_text(colour='black',size=20,hjust=3),
axis.title.x=element_text(colour='black',size=30),
axis.title.y=element_text(colour='black',size=30))

for (i in 1:length(sst)){
	tiff(filename = paste(unlist(strsplit(ctd$filename,split="_"))[5],"SSTSSAL",strftime(date2[i],"%d%m%Y"),".tiff",sep="")
	,width = 480, height = 480, units = "px", pointsize = 12,
     compression = "lzw",bg = "white")
	pt<-pt+geom_point(aes(x=x2[i],y=y2[i],colour=sst2[i]),data=data.frame(x2,y2,sst2))+
	geom_text(aes(max(x2),max(y2),label=date2[i]))
	print(pt)
	dev.off()
	pause()
}

tiff(filename = paste(unlist(strsplit(ctd$filename,split="_"))[5],"SSTSSAL",strftime(date2[i],"%d%m%Y"),".tiff",sep="")
	,width = 900, height = 900, units = "px",compression = "lzw",bg = "white")
	pt<-pt+geom_point(aes(x=x2[i],y=y2[i],colour=sst2[i]),data=data.frame(x2,y2,sst2))+
	geom_point(aes(size=5))+
	geom_text(aes(max(x2),max(y2),label=date2[i]))
	print(pt)
	dev.off()
