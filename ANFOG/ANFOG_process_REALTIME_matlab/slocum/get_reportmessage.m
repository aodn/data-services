function [message] = get_reportmessage(index)
% LIST OF OUTPUT MESSAGE WRITTEN IN THE LOG FILE
% INPUT  	
%			-index		:index of message
% OUTPUT
%		 	-message 
%Author: B.Pasquer July 2013
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
switch index
    case 1
    message = ' has been processed for the first time';
    case 2
    message = ' has been updated';
    case 3
    message = ' has NO UPDATE';
    case 4
    message = ' PROBLEM to copy locally the text file containing GPS positions for the following deployment ';
    case 5
    message = ' PROBLEM during the processing of the following deployment ';
    case 6
    message = ' No Deployment to process';
    case 7
    message = ' The Deployment ';
    case 8
    message = 'New deployment soon to be processed';  
end