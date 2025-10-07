function plotGccBandwidthState(data, is_dl, datapath)
    % Check if GCC data is available
    if isempty(data.gcc_data_filtered)
        warning('GCC data is not available for plotting.');
        return;
    end
    
    % Extract data
    gcc_data = data.gcc_data_filtered;
    
    % Normalize the timestamps for plotting
    time_offset = min(gcc_data.timestamp_ms);
    
    % Extract trendline data
    trendline_indices = strcmp(gcc_data.component, 'trendline');
    trendline_data = gcc_data(trendline_indices, :);
    
    % Check if we have trendline data
    if isempty(trendline_data)
        warning('No trendline data available for plotting.');
        return;
    end
    
    % Extract timestamps for trendline data
    trend_times = (trendline_data.timestamp_ms - time_offset) / 1000;
    
    % Convert bandwidth_state text to numeric values for plotting
    state_map = containers.Map({'underusing', 'normal', 'overusing'}, {-1, 0, 1});
    
    % Handle trendline states
    trend_states = trendline_data.bandwidth_state;
    numeric_states = zeros(size(trend_states));
    
    for i = 1:length(trend_states)
        if ~isempty(trend_states{i}) && isKey(state_map, trend_states{i})
            numeric_states(i) = state_map(trend_states{i});
        else
            numeric_states(i) = NaN;
        end
    end
    
    % Remove NaN values
    valid_states = ~isnan(numeric_states);
    if is_dl 
        time_dl_numeric_states = [trend_times(valid_states)'; numeric_states(valid_states)'];
        save([datapath 'time_dl_numeric_states.mat'], "time_dl_numeric_states");
    else 
        time_ul_numeric_states = [trend_times(valid_states)'; numeric_states(valid_states)'];
        save([datapath 'time_ul_numeric_states.mat'], "time_ul_numeric_states");
    end
end