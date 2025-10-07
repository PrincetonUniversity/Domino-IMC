function plotGccBandwidthState(data)
    % Check if GCC data is available
    if isempty(data.gcc_data_filtered)
        warning('GCC data is not available for plotting.');
        text(0.5, 0.5, 'GCC data not available', 'HorizontalAlignment', 'center');
        axis off;
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
        text(0.5, 0.5, 'No trendline data available', 'HorizontalAlignment', 'center');
        axis off;
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
    
    % Plot bandwidth state
    plot(trend_times(valid_states), numeric_states(valid_states), 'm.-', 'LineWidth', 1.5);
    
    % Set y-axis limits and ticks
    ylim([-1.5, 1.5]);
    yticks([-1, 0, 1]);
    yticklabels({'Underusing', 'Normal', 'Overusing'});
    
    % Add labels
    grid on;
    xlabel('Time (s)');
    ylabel('State');
end