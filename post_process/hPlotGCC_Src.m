function hPlotGCC_Src(period_st, period_ed, expCode, appCode, time_st, linktype)
    % PLOT_GCC_METRICS Plots WebRTC GCC internal metrics from log file
    %   PLOT_GCC_METRICS(PERIOD_ST, PERIOD_ED, TIMESTAMP_PREFIX) loads data from
    %   the CSV file '{TIMESTAMP_PREFIX}-gcc-2.csv' and plots metrics within
    %   the time range [PERIOD_ST, PERIOD_ED] milliseconds.
    %
    %   The function plots eight metrics:
    %   1. Modified trend
    %   2. Threshold
    %   3. Modified trend vs Threshold
    %   4. Bandwidth state (overuse/normal/underuse)
    %   5. Bitrate estimates (target, loss-based, pushback, stable)
    %   6. Outstanding bytes
    %   7. Time window (ms)
    %   8. Data window (bytes)
    
    % Set direction-specific parameters based on linktype
    if strcmp(linktype, 'U')
        gcc_file = '-gcc-2.csv';
        fig_num = 5;
        direction_title = 'Uplink';
    elseif strcmp(linktype, 'D')
        gcc_file = '-gcc-1.csv';
        fig_num = 6;
        direction_title = 'Downlink';
    else
        error('Invalid linktype. Must be ''U'' or ''D''.');
    end

    % Construct the filename
    filename = ['../data_webrtc/data_exp' expCode '/' appCode gcc_file];
    
    % Check if file exists
    if ~exist(filename, 'file')
        error('File %s does not exist.', filename);
    end
    
    % Read the CSV file
    % Explicitly tell MATLAB to read headers and how to handle the data
    opts = detectImportOptions(filename);
    opts.VariableNamesLine = 1;  % Specifically tell MATLAB headers are in line 1
    opts.DataLines = 2;          % Data starts at line 2
    opts.Delimiter = ',';
    data = readtable(filename, opts);
    
    % Convert all numeric cell columns to double arrays
    numericCols = {'timestamp_ms', 'modified_trend', 'threshold', 'target_bitrate_bps', ...
                  'loss_based_target_rate_bps', 'pushback_target_rate_bps', ...
                  'stable_target_rate_bps', 'fraction_loss', 'peer_id', ...
                  'outstanding_bytes', 'time_window_ms', 'data_window_bytes'};
    
    for i = 1:length(numericCols)
        colName = numericCols{i};
        if ismember(colName, data.Properties.VariableNames) && iscell(data.(colName))
            % This handles vacant fields by converting them to NaN
            data.(colName) = cellfun(@(x) str2double(x), data.(colName), 'UniformOutput', true);
        end
    end    
    
    % Extract the timestamp column and filter by time range
    data.timestamp_ms = data.timestamp_ms - data.timestamp_ms(1);
    timestamps = data.timestamp_ms;
    valid_indices = timestamps >= (period_st-time_st) & timestamps <= (period_ed-time_st);
    data = data(valid_indices, :);
    
    if isempty(data)
        error('No data points found in the specified time range.');
    end
    
    % Normalize the timestamps to start at 0 for plotting
    if ~isempty(data)
        time_offset = min(data.timestamp_ms);
        data.normalized_time = (data.timestamp_ms - time_offset) / 1000; % Convert to seconds
    end
    
    % Prepare the figure
    figure(fig_num); clf;
    
    % Extract data by component type
    trendline_data = data(strcmp(data.component, 'trendline'), :);
    delaybwe_data = data(strcmp(data.component, 'delay_bwe'), :);
    network_data = data(strcmp(data.component, 'network_controller'), :);
    
    % 1) Modified trend
    subplot(8,1,1);
    trend_times = trendline_data.normalized_time;
    modified_trend = trendline_data.modified_trend;
    valid_trend = ~isnan(modified_trend);
    plot(trend_times(valid_trend), modified_trend(valid_trend), 'g.-');
    grid on;
    xlabel('Time [s]');
    ylabel('Modified Trend');
    title('Trendline Modified Trend');
    
    % 2) Threshold
    subplot(8,1,2);
    thresholds = trendline_data.threshold;
    valid_thresh = ~isnan(thresholds);
    plot(trend_times(valid_thresh), thresholds(valid_thresh), 'k.-');
    grid on;
    xlabel('Time [s]');
    ylabel('Threshold');
    title('Adaptive Threshold');
    
    % 3) Modified trend vs. threshold
    subplot(8,1,3); hold on;
    plot(trend_times(valid_trend), modified_trend(valid_trend), 'g.-', 'DisplayName', 'Modified Trend');
    plot(trend_times(valid_thresh), thresholds(valid_thresh), 'k--', 'DisplayName', 'Threshold');
    legend('Location', 'Best');
    grid on;
    xlabel('Time [s]');
    ylabel('Slope / Threshold');
    title('Modified Trend vs. Adaptive Threshold');
    
    % 4) Bandwidth state (-1=Under, 0=Normal, +1=Over)
    subplot(8,1,4);
    
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
    valid_states = ~isnan(numeric_states);
    
    plot(trend_times(valid_states), numeric_states(valid_states), 'm.-');
    grid on;
    ylim([-1.5, 1.5]);
    yticks([-1, 0, 1]);
    yticklabels({'Underusing', 'Normal', 'Overusing'});
    xlabel('Time [s]');
    ylabel('State');
    title('Bandwidth State');
    
    % 5) Bitrates
    subplot(8,1,5); hold on;
    
    % Target bitrate from delay_bwe
    if ~isempty(delaybwe_data)
        delay_times = delaybwe_data.normalized_time;
        target_bitrate = delaybwe_data.target_bitrate_bps;
        valid_target = ~isnan(target_bitrate);
        plot(delay_times(valid_target), target_bitrate(valid_target)/1000, 'b.-', 'DisplayName', 'Target Bitrate');
    end
    
    % Loss-based, pushback, and stable bitrates from network_controller
    if ~isempty(network_data)
        network_times = network_data.normalized_time;
        
        % Loss-based target rate
        loss_based_rate = network_data.loss_based_target_rate_bps;
        valid_loss = ~isnan(loss_based_rate);
        plot(network_times(valid_loss), loss_based_rate(valid_loss)/1000, 'r.-', 'DisplayName', 'Loss-Based Rate');
        
        % Pushback target rate
        pushback_rate = network_data.pushback_target_rate_bps;
        valid_pushback = ~isnan(pushback_rate);
        plot(network_times(valid_pushback), pushback_rate(valid_pushback)/1000, 'g.-', 'DisplayName', 'Pushback Rate');

        % % Stable target rate
        % stable_rate = network_data.stable_target_rate_bps;
        % valid_stable = ~isnan(stable_rate);
        % plot(network_times(valid_stable), stable_rate(valid_stable)/1000, 'c.-', 'DisplayName', 'Stable Rate');
    end
    
    grid on;
    legend('Location', 'Best');
    xlabel('Time [s]');
    ylabel('Bitrate [kbps]');
    title('GCC Bitrate Estimates');
    
    % 6) Outstanding bytes
    subplot(8,1,6);
    if ~isempty(network_data) && ismember('outstanding_bytes', network_data.Properties.VariableNames)
        outstanding_bytes = network_data.outstanding_bytes;
        valid_bytes = ~isnan(outstanding_bytes);
        plot(network_times(valid_bytes), outstanding_bytes(valid_bytes), 'b.-');
        grid on;
        xlabel('Time [s]');
        ylabel('Bytes');
        title('Outstanding Bytes');
    else
        text(0.5, 0.5, 'No outstanding bytes data available', 'HorizontalAlignment', 'center');
        axis off;
    end
    
    % 7) Time window
    subplot(8,1,7);
    if ~isempty(network_data) && ismember('time_window_ms', network_data.Properties.VariableNames)
        time_window = network_data.time_window_ms;
        valid_time = ~isnan(time_window);
        plot(network_times(valid_time), time_window(valid_time), 'r.-');
        grid on;
        xlabel('Time [s]');
        ylabel('Time [ms]');
        title('Time Window');
    else
        text(0.5, 0.5, 'No time window data available', 'HorizontalAlignment', 'center');
        axis off;
    end
    
    % 8) Data window bytes
    subplot(8,1,8);
    if ~isempty(network_data) && ismember('data_window_bytes', network_data.Properties.VariableNames)
        data_window = network_data.data_window_bytes;
        valid_window = ~isnan(data_window);
        plot(network_times(valid_window), data_window(valid_window), 'g.-');
        grid on;
        xlabel('Time [s]');
        ylabel('Bytes');
        title('Data Window Size');
    else
        text(0.5, 0.5, 'No data window size available', 'HorizontalAlignment', 'center');
        axis off;
    end
    
    % Adjust figure layout
    set(gcf, 'Position', [100, 100, 1200, 1200]);
    sgtitle(['WebRTC GCC Metrics - ' direction_title ' - Time Range ' num2str((period_st-time_st)/1000) 's to ' num2str((period_ed-time_st)/1000) 's'], 'FontSize', 14);
end