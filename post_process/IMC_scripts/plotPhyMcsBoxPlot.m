function plotPhyMcsBoxPlot(data, bin_sz_mcs)
    % Plot MCS statistics in box plot format
    % First filter out MCS values > 28 and get only UEs of interest
    valid_mcs_indices = (data.mcs_physync <= 28) & data.is_interest_ue;
    
    % Check if we have valid MCS data
    if ~any(valid_mcs_indices)
        warning('No valid MCS data points (MCS ≤ 28) found for UEs of interest.');
        text(0.5, 0.5, 'No valid MCS data available', 'HorizontalAlignment', 'center');
        axis off;
        return;
    end
    
    % Extract valid MCS values and their timestamps
    mcs_values = data.mcs_physync(valid_mcs_indices);
    ts_values = data.ts_physync(valid_mcs_indices);
    
    % Normalize timestamps to start from 0 and convert to seconds
    time_offset = data.min_time;
    ts_normalized = (ts_values - time_offset)/1000;  % Convert to seconds
    
    % Convert bin size to seconds for consistency
    bin_size_sec = bin_sz_mcs/1000;  % Convert ms to seconds
    
    % Create time bins for aggregation similar to plotPhyTbsCapComp
    plot_start = min(ts_normalized);
    plot_end = max(ts_normalized);
    time_bins = plot_start:bin_size_sec:plot_end;
    
    % Check if we have enough bins
    if length(time_bins) <= 1
        warning('Not enough data for multiple bins.');
        text(0.5, 0.5, 'Not enough data for multiple bins', 'HorizontalAlignment', 'center');
        axis off;
        return;
    end
    
    % Initialize arrays for percentiles
    num_bins = length(time_bins) - 1;
    p90 = nan(num_bins, 1);
    p75 = nan(num_bins, 1);
    p50 = nan(num_bins, 1);
    p25 = nan(num_bins, 1);
    p10 = nan(num_bins, 1);
    
    % Calculate bin centers for x-axis
    bin_centers = zeros(num_bins, 1);
    
    % Calculate percentiles for each bin
    for i = 1:num_bins
        % Find data points in this bin - similar to plotPhyTbsCapComp approach
        bin_indices = (ts_normalized >= time_bins(i)) & (ts_normalized < time_bins(i+1));
        bin_mcs = mcs_values(bin_indices);
        
        if length(bin_mcs) >= 5 % Need at least 5 points for meaningful percentiles
            p90(i) = prctile(bin_mcs, 90);
            p75(i) = prctile(bin_mcs, 75);
            p50(i) = prctile(bin_mcs, 50);
            p25(i) = prctile(bin_mcs, 25);
            p10(i) = prctile(bin_mcs, 10);
        end
        
        % Calculate bin center for x-axis (same as in plotPhyTbsCapComp)
        bin_centers(i) = (time_bins(i) + time_bins(i+1))/2;
    end
    
    % Plot boxes from 10th to 90th percentile with light blue fill
    hold on;
    
    % Define box width (0.6 * bin_size in seconds)
    box_width = 0.6 * bin_size_sec;
    
    % Light blue color for face
    light_blue = [0.7, 0.9, 1.0];
    
    % Plot boxes for each bin
    for i = 1:num_bins
        if ~isnan(p50(i))
            % Box coordinates
            x_left = bin_centers(i) - box_width/2;
            x_right = bin_centers(i) + box_width/2;
            y_bottom = p10(i);
            y_top = p90(i);
            
            % Create filled rectangle
            x_rect = [x_left, x_right, x_right, x_left];
            y_rect = [y_bottom, y_bottom, y_top, y_top];
            fill(x_rect, y_rect, light_blue, 'EdgeColor', 'b');
            
            % Add median line
            plot([x_left, x_right], [p50(i), p50(i)], 'r-', 'LineWidth', 1.5);
        end
    end
    
    % Set axis labels and grid
    xlabel('Time (s)');
    ylabel('MCS');
    grid on;
    title('Uplink MCS Statistics (UEs of Interest Only, 10th-90th Percentile)');
    
    % Add legend
    h1 = fill(NaN(1,4), NaN(1,4), light_blue, 'EdgeColor', 'b');
    h2 = plot(NaN, NaN, 'r-', 'LineWidth', 1.5);
    legend([h1, h2], {'10-90th Percentile Range', 'Median'}, 'Location', 'best');
    
    hold off;
end