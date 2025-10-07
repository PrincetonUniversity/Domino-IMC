function plotGccTargetRates(data)
    % Check if GCC data is available
    if isempty(data.gcc_data_filtered)
        warning('GCC data is not available for plotting.');
        text(0.5, 0.5, 'GCC data not available', 'HorizontalAlignment', 'center');
        axis off;
        return;
    end
    
    % Normalize the timestamps for plotting
    gcc_data = data.gcc_data_filtered;
    time_offset = data.min_time;
    normalized_time = (gcc_data.timestamp_ms - time_offset) / 1000; % Convert to seconds
    
    % Extract data by component type
    network_indices = strcmp(gcc_data.component, 'network_controller');
    network_data = gcc_data(network_indices, :);
    
    % Check if we have network_controller data
    if isempty(network_data)
        warning('No network_controller data available for plotting.');
        text(0.5, 0.5, 'No network_controller data available', 'HorizontalAlignment', 'center');
        axis off;
        return;
    end
    
    % Plot Loss-based and Pushback rates
    hold on;
    
    % Extract timestamps for network_controller data
    network_times = (network_data.timestamp_ms - time_offset) / 1000;
    
    % Loss-based target rate (displayed as "Target Bitrate")
    if ismember('loss_based_target_rate_bps', network_data.Properties.VariableNames)
        loss_based_rate = network_data.loss_based_target_rate_bps;
        valid_loss = ~isnan(loss_based_rate);
        plot(network_times(valid_loss), loss_based_rate(valid_loss)/1000, 'b.-', 'LineWidth', 1.5, 'DisplayName', 'Target Bitrate');
    end
    
    % Pushback target rate
    if ismember('pushback_target_rate_bps', network_data.Properties.VariableNames)
        pushback_rate = network_data.pushback_target_rate_bps;
        valid_pushback = ~isnan(pushback_rate);
        plot(network_times(valid_pushback), pushback_rate(valid_pushback)/1000, 'g.-', 'LineWidth', 1.5, 'DisplayName', 'Pushback Rate');
    end
    
    hold off;
    grid on;
    legend('Location', 'Best');
    xlabel('Time (s)');
    ylabel('Bitrate (kbps)');
end