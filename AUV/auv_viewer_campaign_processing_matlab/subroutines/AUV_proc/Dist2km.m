function DistanceKM=Dist2km(lon1,lat1,lon2,lat2)
%DistanceKM compute the distance in km between two lat/lon points
% Inputs:
%   lon1  - double of the first longitude point.
%   lon2  - double of the last longitude point.
%   lat1  - double of the first latitude point.
%   lat2  - double of the last latitude point.
%
% Outputs:
%   DistanceKM       - double containing data.
%
% Author: Laurent Besnard <laurent.besnard@utas,edu,au>
%
%
% Copyright (c) 2010, eMarine Information Infrastructure (eMII) and Integrated 
% Marine Observing System (IMOS).
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without 
% modification, are permitted provided that the following conditions are met:
% 
%     * Redistributions of source code must retain the above copyright notice, 
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright 
%       notice, this list of conditions and the following disclaimer in the 
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
%       may be used to endorse or promote products derived from this software 
%       without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
% POSSIBILITY OF SUCH DAMAGE.
%

E=6378.1370;                                                                %Equateur Radius (km)
P=6356.7523;                                                                %Pole Radius (km)   pi = acos(-1);
deg2rad2 = pi / 180 ;

%Earth Radius depending of lat (km)
R_Lat=sqrt( ((E*E*cos(lat1*deg2rad2)).*(E*E*cos(lat1*deg2rad2)) +(P*P*sin(lat1*deg2rad2)).*(P*P*sin(lat1*deg2rad2))) ./ ((E*cos(lat1*deg2rad2)).*(E*cos(lat1*deg2rad2)) +(P*sin(lat1*deg2rad2)).*(P*sin(lat1*deg2rad2))) );

DELTA_LON= lon2 - lon1;
DELTA_LAT= lat2 - lat1;

a= sin(DELTA_LAT *deg2rad2 /2) .* sin(DELTA_LAT *deg2rad2/2)  + cos(lat1 *deg2rad2).*cos(lat2 *deg2rad2).*sin(DELTA_LON *deg2rad2/2).*sin(DELTA_LON  *deg2rad2/2 ) ;
c = 2 * atan2( sqrt(a), sqrt(1-a));

DistanceKM = R_Lat .* c;    

end