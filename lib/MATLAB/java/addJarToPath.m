function addJarToPath(folder)
%% addJarToPath
% Add any *.jar java library located in folder to the classpath
% Example:
%    addJarToPath('~/JAR')
%
% Other m-files required:
% Other files required:
% Subfunctions: none
% MAT-files required: none
%
% See also:
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 10-Sept-2012

jars = dir([folder filesep '*.jar']);
for j = 1 : length(jars)
    javaaddpath([folder filesep jars(j).name]);
end
end