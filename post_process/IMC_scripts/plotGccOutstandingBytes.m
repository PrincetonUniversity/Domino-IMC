function plotGccOutstandingBytes(data)
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
    
    % Extract timestamps for network_controller data
    network_times = (network_data.timestamp_ms - time_offset) / 1000;
    
    % Plot Outstanding bytes
    if ismember('outstanding_bytes', network_data.Properties.VariableNames)
        outstanding_bytes = network_data.outstanding_bytes;
        valid_bytes = ~isnan(outstanding_bytes);
        plot(network_times(valid_bytes), outstanding_bytes(valid_bytes), 'b.-', 'LineWidth', 1.5);
        grid on;
        xlabel('Time (s)');
        ylabel('Bytes');
    else
        text(0.5, 0.5, 'No outstanding bytes data available', 'HorizontalAlignment', 'center');
        axis off;
    end
end