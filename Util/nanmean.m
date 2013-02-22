function ouptut = nanmean(input)

iNan = isnan(input);
output = mean(input(~iNan));