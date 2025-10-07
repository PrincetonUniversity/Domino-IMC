function GccOverUse(data, is_dl, export_datapath)
    % Check if GCC data is available
    if isempty(data.gcc_data_filtered)
        warning('GCC data is not available.');
        return;
    end

    gcc_data = data.gcc_data_filtered;

    % Normalize the timestamps for plotting
    time_offset = data.min_time;
    
    % Extract trendline data
    trendline_indices = strcmp(gcc_data.component, 'trendline');
    trendline_data = gcc_data(trendline_indices, :);
    trendline_data.timestamp_ms(1) = trendline_data.timestamp_ms(1)-150;
    trendline_data.timestamp_ms(end) = trendline_data.timestamp_ms(end)-100;
    
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
    valid_indices = find(~isnan(numeric_states));
    valid_times = trend_times(valid_indices);
    valid_states = numeric_states(valid_indices);
    
    if (is_dl)
        time_dl_overuse = [valid_times'; valid_states'];
        save([export_datapath 'time_dl_overuse.mat'], "time_dl_overuse");
    else
        time_ul_overuse = [valid_times'; valid_states'];
        save([export_datapath 'time_ul_overuse.mat'], "time_ul_overuse");
    end

end