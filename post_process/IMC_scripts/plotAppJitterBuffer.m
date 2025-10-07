function plotAppJitterBuffer(data)
    % Process time data to start from 0
    time_offset = data.min_time;
    app_time = (data.ts_appin_range - time_offset) / 1000;  % Convert to seconds
    
    % Calculate per-frame jitter buffer metrics
    jb_delay_diff = [0; diff(data.data_appin(:, 18))];
    jb_target_diff = [0; diff(data.data_appin(:, 19))];
    jb_min_diff = [0; diff(data.data_appin(:, 20))];
    jb_emitted_diff = [0; diff(data.data_appin(:, 21))];
    
    % Calculate per-frame metrics (avoiding division by zero)
    valid_idx = jb_emitted_diff > 0;
    jb_delay_per_frame = zeros(size(jb_delay_diff));
    jb_target_per_frame = zeros(size(jb_target_diff));
    jb_min_per_frame = zeros(size(jb_min_diff));
    
    jb_delay_per_frame(valid_idx) = jb_delay_diff(valid_idx) ./ jb_emitted_diff(valid_idx) * 1000;
    jb_target_per_frame(valid_idx) = jb_target_diff(valid_idx) ./ jb_emitted_diff(valid_idx) * 1000;
    jb_min_per_frame(valid_idx) = jb_min_diff(valid_idx) ./ jb_emitted_diff(valid_idx) * 1000;
    
    % Plot all jitter buffer metrics
    plot(app_time, jb_delay_per_frame, 'b-', 'LineWidth', 1.5);
    hold on;
    plot(app_time, jb_target_per_frame, 'r-', 'LineWidth', 1.5);
    plot(app_time, jb_min_per_frame, 'g-', 'LineWidth', 1.5);
    
    % Add labels and title
    xlabel('Time (s)');
    ylabel('Jitter Buffer Delay per Frame (ms)');
    title('Inbound Jitter Buffer Metrics');
    
    % Add legend
    legend('Current Delay', 'Target Delay', 'Minimum Delay', 'Location', 'Best');
    
    % Add grid
    grid on;
end