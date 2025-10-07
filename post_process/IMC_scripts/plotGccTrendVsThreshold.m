function plotGccTrendVsThreshold(data)
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
    time_offset = data.min_time;
    
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
    
    % Extract modified trend and threshold data
    modified_trend = trendline_data.modified_trend;
    thresholds = trendline_data.threshold;
    
    % Remove NaN values
    valid_trend = ~isnan(modified_trend);
    valid_thresh = ~isnan(thresholds);
    
    % Plot data
    hold on;
    plot(trend_times(valid_trend), modified_trend(valid_trend), 'g.-', 'LineWidth', 1.5, 'DisplayName', 'Modified Trend');
    plot(trend_times(valid_thresh), thresholds(valid_thresh), 'k--', 'LineWidth', 1.5, 'DisplayName', 'Threshold');
    hold off;
    
    % Add labels and legend
    legend('Location', 'Best');
    grid on;
    xlabel('Time (s)');
    ylabel('Slope / Threshold');
end