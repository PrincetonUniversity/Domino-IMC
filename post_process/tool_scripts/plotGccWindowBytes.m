function plotGccWindowBytes(data, is_dl, datapath)
    % Check if GCC data is available
    if isempty(data.gcc_data_filtered)
        warning('GCC data is not available for plotting.');
        text(0.5, 0.5, 'GCC data not available', 'HorizontalAlignment', 'center');
        axis off;
        return;
    end
    
    % Normalize the timestamps for plotting
    gcc_data = data.gcc_data_filtered;
    time_offset = min(gcc_data.timestamp_ms);
    
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
    
    % Plot Data window bytes
    if ismember('data_window_bytes', network_data.Properties.VariableNames)
        data_window = network_data.data_window_bytes;
        valid_window = ~isnan(data_window);
        if is_dl
            time_dl_gcc_window_bytes = [network_times(valid_window)'; data_window(valid_window)'];
            save([datapath 'time_dl_gcc_window_bytes.mat'], "time_dl_gcc_window_bytes");
        else
            time_ul_gcc_window_bytes = [network_times(valid_window)'; data_window(valid_window)'];
            save([datapath 'time_ul_gcc_window_bytes.mat'], "time_ul_gcc_window_bytes");
        end
        plot(network_times(valid_window), data_window(valid_window), 'g.-', 'LineWidth', 1.5);
        grid on;
        xlabel('Time (s)');
        ylabel('Bytes');
    else
        text(0.5, 0.5, 'No data window size available', 'HorizontalAlignment', 'center');
        axis off;
    end
end