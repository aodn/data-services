function [aggregatedT, aggregatedX, varargout] = aggregate(t, x, burst_duration, exclusions)
% Inputs:
%        t - time, in datenum
%        x - data values
%        burst_duration - time in seconds of nominal burst length, as
%                       documented in the raw file metadata
%        exclusions - the indices of any points to exclude from averaging
% Outputs:
%       aggregatedT - time array, timestamp is middle of raw burst; prior
%                                   to excluding
%       aggregatedX - data array, burst averages, matching aggregatedT array

%       varargout{1} - numInclude
%       varargout{2} - SDburst   SD of data in each burst, same dims
%       varargout{3} - rangeburst   n x 2 matrix, n=length(aggregatedT) each row has min & max of
%                                   burst, after removal of exclusions
%       varargout{4} - indices of aggregated result where whole burst was
%       removed
%       varargout{5} - numExclude  an array of numbers, same dimensions as
%       aggregatedT and aggregatedX

% calculate an aggregated x and t, with means for each burst:
difft = diff(t);    % difft(i)=t(i+1)-t(i)

% the differences are calculated in rounded seconds, just because it's
% easier to observe what's happening when in these units
difft = round(86400*difft);

% f = mode(difft);
% f is 'standard' gap, or interval between points in a burst. For WQM, 1 second

allowed_gap = burst_duration;

hasrightneighbour = find(difft < allowed_gap);
hasleftneighbour = hasrightneighbour + 1;   % If a point has a right neighbour,
                                            % then that right neighbour has a
                                            % left neighbour
indexinternals = intersect(hasrightneighbour, hasleftneighbour);
indexinternals = indexinternals(indexinternals < length(difft));
% ie. internal points, neighbours both sides
% the algorithm sees the final point in data as internal,
indexonlyright = setdiff(hasrightneighbour, indexinternals);
indexonlyleft = setdiff(hasleftneighbour, indexinternals);
% Note, these are all indices into t and x

startburstind = indexonlyright;
finishburstind = indexonlyleft;

% at least this loop is only the length of num of bursts, not length
% of data array
nAggregated = length(startburstind);
aggregatedX = NaN(nAggregated, 1);
aggregatedT = NaN(nAggregated, 1);
% numExclude = NaN(nAggregated, 1);
numInclude = NaN(nAggregated, 1);
minBurst = NaN(nAggregated, 1);
maxBurst = NaN(nAggregated, 1);
SDBurst = NaN(nAggregated, 1);
removed = true(nAggregated, 1);
% at least this loop is only the length of num of bursts, not length
% of data array
minexclusion = min(exclusions);
maxexclusion = max(exclusions);
for i=1:nAggregated
    burstinds = startburstind(i):finishburstind(i);
    
%     numExclude(i) = length(intersect(burstinds, exclusions));
    % introduce this test to minimise the number of calls to setdiff
    if isempty(exclusions)
        remainingburstinds = burstinds;
    else
        if finishburstind(i) < minexclusion || ...
                startburstind(i) > maxexclusion
            remainingburstinds = burstinds;
        else
            remainingburstinds = setdiff(burstinds, exclusions); % cpu time consuming
        end
    end
    aggregatedT(i) = (t(startburstind(i)) + t(finishburstind(i)))/2;
    if ~isempty(remainingburstinds)
        xBurst = x(remainingburstinds);
        aggregatedX(i)  = mean(xBurst);
        minBurst(i)     = min(xBurst);
        maxBurst(i)     = max(xBurst);
        SDBurst(i)      = std(xBurst);
        removed(i)      = false;
    end
    numInclude(i) = length(remainingburstinds);
end
varargout{1} = numInclude;
varargout{2} = SDBurst;
varargout{3} = [minBurst maxBurst];
varargout{4} = find(removed);
% varargout{5} = numExclude;