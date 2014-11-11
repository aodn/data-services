function addJarToPath(folder)
% Add any *.jar java library to the classpath
jars = dir([folder filesep '*.jar']);
for j = 1 : length(jars)
    javaaddpath([folder filesep jars(j).name]);
end
end