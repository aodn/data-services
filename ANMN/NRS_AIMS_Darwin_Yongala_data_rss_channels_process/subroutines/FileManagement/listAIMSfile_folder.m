function [firstDate,lastDate,creationDate,ncFile] = listAIMSfile_folder(pathstr)
% function to list the first date, last date and creation date of a AIMS
% netcdf file found in a folder pathstr
listingFile = dir(pathstr);
firstDate = zeros( 1,length(listingFile) -2);
lastDate = zeros( 1,length(listingFile) -2);
creationDate = zeros( 1,length(listingFile) -2);
ncFile = cell( 1,length(listingFile) -2);
for ii = 3:length(listingFile)
    ncFile{ii-2} = listingFile(ii).name;
    [ firstDate(ii-2),lastDate(ii-2),creationDate(ii-2) ] = AIMS_fileDates( ncFile{ii-2} );
    
end

end
