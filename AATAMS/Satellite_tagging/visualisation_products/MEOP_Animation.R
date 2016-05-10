rm(list=ls());
library(ncdf); library(grid); library(maptools); library(ggplot2);

################
################
#### MAP
################
################
world_map <- readShapeSpatial("/Users/xavierhoenner/Work/AATAMS_Biologging/sattags/DataProducts/ne_10m_land/ne_10m_land.shp");
world_map<-fortify(world_map)[which((fortify(world_map)$lat)<(0)),];
mp1<-world_map; mp2<-world_map; mp2$long<-mp2$long+360;
mp2$group<- as.numeric(paste(mp1$group)) + max(as.numeric(paste(mp1$group)))+1;
br <- as.numeric(row.names(table(levels(mp1$group))))+max(as.numeric(row.names(table(levels(mp1$group)))))+1

for (i in 1:length(as.numeric(levels(mp1$group)))){
	if (length(which((br)==br[i]))==1) br[i]<-br[i] else br[i]<-br[i]+runif(1,500,770)
};

for (i in 1:length(as.numeric(levels(mp1$group)))){
	if (length(which((br)==br[i]))==1) br[i]<-br[i] else br[i]<-br[i]+701
};

mp2$group<-cut(mp2$group,breaks=br); mp2 <- mp2[-which((mp2$piece)==10),]; mp2<-mp2[-which((mp2$piece)==50),]; mp <- rbind(mp1, mp2);

vppt_ <- viewport(width = 1, height = 1, x = 0.5, y = 0.5)  # the larger map
theme_opts <- list(theme(panel.grid.minor = element_blank(),
                        panel.grid.major.y = element_line(colour = 'black'),
                        panel.background =   element_rect(fill = "white"),
                        plot.background = element_rect(fill="#e6e8ed"),
                        panel.border = element_blank(),
                        axis.line = element_blank(),
						axis.text.x=element_blank(),
						axis.text.y=element_blank(),
						axis.title.x=element_text(colour='black',size=20),
						axis.title.y=element_text(colour='black',size=20),
						axis.ticks.x=element_line(colour='black'),
						axis.ticks.y=element_line(colour='black'),
						legend.text=element_text(colour='black',size=15),
						legend.title=element_text(colour='black',size=22),
						legend.key.width=unit(1.5, "cm"),
						legend.key.height=unit(2.5, "cm"),
						legend.text.align= 0.5,			
						plot.title=element_text(colour='black',size=25)))

pt <- ggplot(mp) + geom_map(map=mp,aes(x=long,y=lat,map_id=id,group=group),fill="grey70",color="grey10",alpha=.8) + geom_map(map=mp,aes(x=long,y=lat,map_id=id,group=group),fill="grey70") + 
coord_polar() + theme_opts +
scale_x_continuous(limits = c(0,360),expand=c(0,0), breaks=seq(0,360,90), labels= seq(0,360,90)) + 
scale_y_continuous(limits =  c(-90,-30),expand=c(0,0), breaks=seq(-80,-40,20), labels= seq(-80,-40,20)) +
scale_colour_gradient2("Sea Surface 
Temperature (°C)
",limits=c(-2.5,18), breaks = c(0, 5, 10, 15), labels = c(0, 5, 10, 15), low="blue", mid = 'yellow', high="red", space="rgb", midpoint = 8, expand=10) +
xlab("Longitude") + ylab("Latitude") + 
annotate('text', x = c(0,0,0), y = c( -78, -58, -38), label = c('-80°S','-60°S','0°E,-40°S')) +
annotate('text', x = 90, y = -35, label = '90°E') + annotate('text', x = 180, y = -45, label = '180°E') + annotate('text', x = 270, y = -33, label = '-90°W')


################################
################################
#### Prepare measurement dataset
################################
################################
setwd("/Users/xavierhoenner/Work/AATAMS_Biologging/MEOP_20160411");
dir.create("/Users/xavierhoenner/Work/AATAMS_Biologging/sattags/DataProducts/AllDeployments");
file_name<-dir(pattern = '*.nc', full.names=T, recursive = T);
file <- matrix(ncol=1);
for (i in 1:length(file_name)){
	file[i] <- strsplit(strsplit(file_name[i],'/')[[1]][4],'-')[[1]][1];
}
file_name <- file_name[-which(file == 'ft17')]; rm(file);

xydt_all <- matrix(ncol=6);
for (f in 1:length(file_name)){
	## Extract NetCDF variables
	ctd <- open.ncdf(file_name[f])
	x <- get.var.ncdf(ctd,"LONGITUDE") # Longitude
	y <- get.var.ncdf(ctd,"LATITUDE") # Latitude
	
	if (length(x) == 1 & length(y) == 1) {print(paste(file_name[f],' --> only a single profile',sep='')); next}; ### Flags erroneous NetCDF files for Fabien
	if (length(y) == length(which(y > -10))) {print(paste(file_name[f],' --> deployments in Northern Hemisphere',sep='')); next};
	if (length(which(x == 0)) == length(x) & length(which(y == 0)) == length(y)) {print(paste(file_name[f],' --> lat/lon coordinates all equal to 0',sep='')); next};
	
	temp <- get.var.ncdf(ctd,"TEMP_ADJUSTED"); if(is.na(ncol(temp)) == T)	sst <- temp[1] else sst <- temp[1,];
	id <- gsub('_prof.nc', '', strsplit(ctd$filename,split="/")[[1]][4]);
	date <- as.POSIXlt(get.var.ncdf(ctd,"JULD") * 24 * 60 *60, origin = '1950-01-01', tz='UTC') # Time
	
	## Extract QC flags
	z_qc <- substr(get.var.ncdf(ctd,"PRES_ADJUSTED_QC"),1,1); # Depth QC
	temp_qc <- substr(get.var.ncdf(ctd,"TEMP_ADJUSTED_QC"),1,1); # Temperature QC
	date_qc <- strsplit(get.var.ncdf(ctd,"JULD_QC"),'')[[1]];
	position_qc <- strsplit(get.var.ncdf(ctd,"POSITION_QC"),'')[[1]];
	good_qc <- which(z_qc == 1 & temp_qc == 1 & date_qc == 1 & position_qc == 1);
	
	## Select only data with good QC flags
	if (length(good_qc) > 0){
		x <- x[good_qc]; y <- y[good_qc]; sst <- sst[good_qc]; date <- date[good_qc]
	} else next

	## Transform longitude to range from 0-360
	if (length(which(x < 0)) > 0 & length(which(x > 0)) > 0 & length(which(x < -100)) == 0) x[which(x > 0)] <- x[which(x > 0)] + 360
	x[which((x)<0)] <- abs(x[which((x)<0)])+(180-abs(x[which((x)<0)]))*2
	
	## Calculate daily averages
	if(length(unique(as.Date(date))) > 1) {
		for (i in 1:length(unique(as.Date(date)))){
			d <- which((as.Date(date))==unique(as.Date(date))[i]);
			if (i == 1) {x_m <- mean(x[d],na.rm=TRUE)} else {x_m <- c(x_m,mean(x[d],na.rm=TRUE))};
			if (i == 1) {y_m <- mean(y[d],na.rm=TRUE)} else {y_m <- c(y_m,mean(y[d],na.rm=TRUE))};
			if (i == 1) {date_m <- unique(as.Date(date))[i]} else {date_m <- c(date_m,unique(as.Date(date))[i])};
			if (i == 1) {sst_m <- mean(sst[d],na.rm=TRUE)} else {sst_m <- c(sst_m,mean(sst[d],na.rm=TRUE))};
		}
	} else next
	
	## Substracts 360 to longitudes greater than 360
	if (length(which(x_m > 360)) > 0) {x_m[which(x_m > 360)] <- x_m[which(x_m > 360)] - 360};
	xydt <- data.frame(x_m,y_m,strptime(date_m,"%Y-%m-%d"),sst_m);
	colnames(xydt) <- c("x","y","date","sst");
	
	## Did the animal cross the Greenwich meridian?
	cross <- which(abs(x_m[2:length(x_m)]-x_m[1:(length(x_m)-1)]) > 300);
	if (length(cross) > 0){
		cross <- c(0,cross, nrow(xydt));
		xydt_m <- list()
		for (c in 2:length(cross)){
			if (c < length(cross)){
				xydt_m[[c-1]] <- rbind(xydt[(cross[c-1] + 1):cross[c],], xydt[cross[c],], xydt[cross[c],]);
				if(x_m[cross[c]] > 350) {xydt_m[[c-1]]$x[nrow(xydt_m[[c-1]]) - 1] <- 360; xydt_m[[c-1]]$x[nrow(xydt_m[[c-1]])] <- 0;} else {xydt_m[[c-1]]$x[nrow(xydt_m[[c-1]]) - 1] <- 0; xydt_m[[c-1]]$x[nrow(xydt_m[[c-1]])] <- 360;}
				} else xydt_m[[c-1]] <- xydt[(cross[c-1] + 1):cross[c],];
		}
		xydt <- do.call(rbind.data.frame, xydt_m);
	}

	xydt <- data.frame(rep(id,nrow(xydt)), xydt, seq(1,nrow(xydt),1));
	colnames(xydt_all) <- colnames(xydt) <- c('id',"x","y","date","sst",'obs_no');
	
	## Assemble all data together
	if (f==1) xydt_all <- xydt else xydt_all <- rbind(xydt_all, xydt);
};

xydt_all <- xydt_all[which(is.na(xydt_all$id) == F),]; xydt_all <- xydt_all[order(xydt_all$date),];
u_dates <- unique(xydt_all$date);
ids <- unique(xydt_all$id);
max_obs <- matrix(nrow = length(ids));
for (i in 1:length(ids)){
	max_obs[i] <- max(xydt_all$obs_no[which(xydt_all$id == ids[i])]);
}
max_obs_ids <- data.frame(ids,max_obs); rm(ids); rm(max_obs);

################################
################################
#### Plot: one image per day for time-lapse
################################
################################
setwd('/Users/xavierhoenner/Work/AATAMS_Biologging/sattags/DataProducts/AllDeployments');
for (i in 1:length(u_dates)){

	f <- which(xydt_all$date <= u_dates[i]); ## Isolate all mean measurements obtained before or on date i
	max_obs_ids_f <- aggregate(xydt_all$obs_no[f],by = list(xydt_all$id[f]), max); colnames(max_obs_ids_f) <- c('ids', 'max_obs'); ## Find all IDs with measurements obtained before or on date i, along with max obs_no.
	to_delete <- merge(max_obs_ids_f, max_obs_ids, by = 'ids'); ## Is max obs_no in f the actual last measurement for each id? If so get rid of these ids.
	sub_xydt_all <- xydt_all[f,];
	to_del <- to_delete$ids[which(to_delete[,2] == to_delete[,3])] ## identifies which IDs need to be deleted from sub_xydt_all
	if (length(to_del) > 0) {sub_xydt_all <- sub_xydt_all[- which(sub_xydt_all$id %in% to_del),]}; ## delete all measurements for IDs that had their last measurements
	
	if (length(unique(sub_xydt_all$id)) > 0) {sub_ids <- unique(sub_xydt_all$id);} else next
	cross_2 <- matrix(nrow = length(sub_ids));
	for (j in 1:length(sub_ids)){
		sub_xydt_id <- sub_xydt_all[which(sub_xydt_all$id == sub_ids[j]),];
		c_2 <- which(abs(sub_xydt_id$x[2:nrow(sub_xydt_id)] - sub_xydt_id$x[1:(nrow(sub_xydt_id)-1)]) > 300);
		cross_2[j] <- length(c_2) ## TO DO: Extract which IDs cross the international date line, exclude these from sub_xydt_all and plot these separately after geom_path using an if condition
		
		if (j==1) last <- sub_xydt_id[nrow(sub_xydt_id),] else last <- rbind(last, sub_xydt_id[nrow(sub_xydt_id),]);
	}
	
	filename <- paste("plotsst",i,sep="");
	png(file = paste(filename,".png",sep=""), width = 1920, height = 1080, units = "px", res=92, bg = "white");
	plot <- pt + ## Map
			labs(title = strftime(u_dates[i],"%d %B %Y"))
			if(nrow(sub_xydt_all) > 1) plot <- plot + geom_path(aes(x=x, y=y, colour=sst, group=id), data = sub_xydt_all[which(sub_xydt_all$id %in% sub_ids[which(cross_2 == 0)]),],size=1.3); ## Shows tracks from obs_no = 1 to max(obs_no) for each ID
			cross_ids <- which(cross_2 > 0);
			if(length(cross_ids) > 0) {
				for (j in 1:length(cross_ids)){
					sub_cross_id <- sub_xydt_all[which(sub_xydt_all$id == sub_ids[cross_ids[j]]),];
					c_2 <- which(abs(sub_cross_id$x[2:nrow(sub_cross_id)] - sub_cross_id$x[1:(nrow(sub_cross_id)-1)]) > 300); c_2 <- c(1,c_2,nrow(sub_cross_id));
					for (c in 1:(length(c_2)-1)){
						if (c == 1) {if (nrow(sub_cross_id[c_2[c]:c_2[c+1],]) > 1) plot <- plot + geom_path(aes(x=x,y=y,colour=sst,group=id),data= sub_cross_id[c_2[c]:c_2[c+1],],size=1.3)} else {if (nrow(sub_cross_id[(c_2[c]+1):c_2[c+1],]) > 1) plot <- plot + geom_path(aes(x=x,y=y,colour=sst,group=id),data= sub_cross_id[(c_2[c]+1):c_2[c+1],],size=1.3)}
					}
				}
			}
						
			plot <- plot + geom_point(aes(x=x, y=y, colour=sst, group=id),size=4,data = last) + geom_point(aes(x=x,y=y,group=id), data = last, pch=21,size=4.5,colour = "black"); ## Points showing location of last measurement for each ID
	print(plot, vp = vppt_);
	dev.off();
	
};