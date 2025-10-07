function plotAppQP(data)
    % Process time data to start from 0
    time_offset = data.min_time;
    app_time = (data.ts_appout_range - time_offset) / 1000;  % Convert to seconds
    
    % Calculate per-frame jitter buffer metrics
    qp_diff = [0; diff(data.data_appout(:, 36))];
    frames_diff = [0; diff(data.data_appout(:, 15))];
    
    % Calculate per-frame metrics (avoiding division by zero)
    valid_idx = frames_diff > 0;
    qp_per_frame = zeros(size(qp_diff));
    
    qp_per_frame(valid_idx) = qp_diff(valid_idx) ./ frames_diff(valid_idx);
    
    % Plot all jitter buffer metrics
    plot(app_time, qp_per_frame, 'b-', 'LineWidth', 1.5);
    hold on;
    
    % Add labels and title
    xlabel('Time (s)');
    ylabel('QP');
    
    % Add legend
    legend('QP', 'Location', 'Best');
    
    % Add grid
    grid on;
end