function [Xinterp ,Yinterp ,Zinterp] = SingleXYZ_to_spacedGrid(x,y,z)
% Determine the minimum and the maximum x and y values:
xmin = min(x); ymin = min(y);
xmax = max(x); ymax = max(y); 


% Define the resolution of the grid:
xres=100;
yres=100;


% Define the range and spacing of the x- and y-coordinates,
% and then fit them into X and Y
xv = linspace(xmin, xmax, xres);
yv = linspace(ymin, ymax, yres);
[Xinterp,Yinterp] = meshgrid(xv,yv); 


% Calculate Z in the X-Y interpolation space, which is an 
% evenly spaced grid:
Zinterp = griddata(x,y,z,Xinterp,Yinterp);
