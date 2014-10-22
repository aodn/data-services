 This is a readme file to describe the few steps to customize the automated processing of the seaglider real-time data.The seaglider_realtime_main_UNIX.m script is launched with a cron job every day. This main function and some of its subfunction read pathname and other various parameter in three configuration text file: config.txt (config for the main routine), configGTS.txt( for the seaglider_realtime_GTS_main_UNIX.m routine) and configPlot.txt (for the seaglider_realtime_plotting_subfunction1_UNIX_v3.m routine). 
Only the configPlot.txt needs to be uptaded when a new deployment is received. If it's not updated, standard value will be used. 
No change should be made to the other configuration files     

