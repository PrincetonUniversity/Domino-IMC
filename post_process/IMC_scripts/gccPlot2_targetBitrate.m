%% Parameters
clear;

% Define experiment and application codes
expCode = '0420';
appCode = '1745461047';
linktype = 'U'; % 'U' for uplink, 'D' for downlink

% Moving average window size for packet delay
window_size = 1;
% Bin sizes
bin_sz_prb = 50;  % PRB data bin size (ms)
bin_sz_tbs = 50;  % PRB data bin size (ms)
enb2sfu_delay = -0.0; % ms

% Define relative plot period
relative_plot_period = [034500, 042500];
xlim_values = [0, 8];

% Load data
[ulData, dlData, config] = loadWebRTCData(expCode, appCode, enb2sfu_delay);

%% Process data for time period
% Calculate DL plot period based on DL data start time
dl_start_time = floor(dlData.data_packets(1,14));
dl_plot_period = [dl_start_time + relative_plot_period(1), dl_start_time + relative_plot_period(2)];

% Calculate UL plot period based on UL data start time
ul_start_time = floor(ulData.data_packets(1,14));
ul_plot_period = [ul_start_time + relative_plot_period(1), ul_start_time + relative_plot_period(2)];

% Process data with appropriate direction parameters
dlData = processDataForTimePeriod(dlData, dl_plot_period, config, 'DL');
ulData = processDataForTimePeriod(ulData, ul_plot_period, config, 'UL');

%% Create main figure
figure;
set(gcf, 'Position', [100, 100, 1200, 1000]);  % Increase height to accommodate subplots

% Create array to store axes handles for linking
ax = cell(5, 1);

% Define relative heights for each subplot (sum should be 1)
% Adjust these values to change relative heights
heights = [0.16, 0.22, 0.16, 0.16, 0.16];
bottom = 0.1;

% Define highlight regions
highlight_pink_x = [1.333, 4.000];
highlight_green_x = [4.27, 6.19];

% Determine which data to use based on linktype
if strcmp(linktype, 'U')
    data = ulData;
    opposite_data = dlData;
    direction_label = 'Uplink';
    opposite_direction_label = 'Downlink';
else % 'D'
    data = dlData;
    opposite_data = ulData;
    direction_label = 'Downlink';
    opposite_direction_label = 'Uplink';
end

%% 1. Merged plotPacketDelay function
ax{1} = subplot('Position', [0.20, sum(heights(2:end))+bottom, 0.70, heights(1)]);

% Add highlight regions
hold on;
ylim_values = [-50, 450];
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

% Green highlight region
patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

% Set xaxis_base for packet delay plot
xaxis_base = 'ue';

% Calculate moving average and standard deviation
mov_avg = movmean(data.delay_pkt, window_size);
mov_std = movstd(data.delay_pkt, window_size);

% Choose appropriate timestamps based on xaxis_base parameter
if strcmpi(xaxis_base, 'server')
    % Use server timestamps
    ts_pkt = (data.ts_server - data.min_time)/1000;
    base_label = 'X-axis: Server PKT Sent Time';
else % 'ue'
    % Use UE timestamps
    ts_pkt = (data.ts_ue - data.min_time)/1000;
    base_label = 'X-axis: UE PKT Arrival Time';
end

% Plot shaded area for fluctuation
fill([ts_pkt; flipud(ts_pkt)], ...
     [mov_avg-mov_std; flipud(mov_avg+mov_std)], ...
     'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(ts_pkt, mov_avg, 'b', 'LineWidth', 1.5);

ylabel({'Delay of'; 'Media'; 'PKTs (ms)'}, 'FontSize', 24);
ylim(ylim_values);
yticks([0:150:450]);
xlim(xlim_values);
grid on;
set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size
hold off;

%% 2. plotGccTrendVsThreshold function
ax{2} = subplot('Position', [0.20, sum(heights(3:end))+bottom, 0.70, heights(2)]);

% Add highlight regions
hold on;
ylim_values = [-70, 80];  % Adjust as needed for trendline data
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Green highlight region
patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Extract data
gcc_data = data.gcc_data_filtered;

% Check if GCC data is available
if ~isempty(gcc_data)
    % Normalize the timestamps for plotting
    time_offset = data.min_time;
    
    % Extract trendline data
    trendline_indices = strcmp(gcc_data.component, 'trendline');
    trendline_data = gcc_data(trendline_indices, :);
    
    % Check if we have trendline data
    if ~isempty(trendline_data)
        % Extract timestamps for trendline data
        trend_times = (trendline_data.timestamp_ms - time_offset) / 1000;
        
        % Extract modified trend and threshold data
        modified_trend = trendline_data.modified_trend;
        thresholds = trendline_data.threshold;
        
        % Remove NaN values
        valid_trend = ~isnan(modified_trend);
        valid_thresh = ~isnan(thresholds);
        
        % Plot data
        plot(trend_times(valid_trend), modified_trend(valid_trend), 'g.-', 'LineWidth', 1.5, 'DisplayName', 'Trendline Slope');
        plot(trend_times(valid_thresh), thresholds(valid_thresh), 'k--', 'LineWidth', 1.5, 'DisplayName', 'Threshold');
        plot(trend_times(valid_thresh), -thresholds(valid_thresh), 'k--', 'LineWidth', 1.5, 'HandleVisibility', 'off');
        
        % Add legend
        lgd = legend('Location', 'NorthEast');
        lgd.FontSize = 20;
    else
        text(1.75, 0, 'No trendline data available', 'HorizontalAlignment', 'center', 'FontSize', 20);
    end
else
    text(1.75, 0, 'GCC data not available', 'HorizontalAlignment', 'center', 'FontSize', 20);
end

% Formatting
ylabel({'Slope of Delay'; 'Variation'}, 'FontSize', 24);
ylim(ylim_values);
xlim(xlim_values);
yticks([-60, 0, 60]);
grid on;
set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size
hold off;

%% 3. Merged plotGccBandwidthState function with colored states
ax{3} = subplot('Position', [0.20, sum(heights(4:end))+bottom, 0.70, heights(3)]);

% Extract data
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

% Add highlight regions
hold on;
ylim_values = [-1.5, 2.5];
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

% Green highlight region
patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

% Plot segments with different colors based on state
for i = 1:length(valid_states)
    if i < length(valid_states)
        x = [valid_times(i), valid_times(i+1)];
        y = [valid_states(i), valid_states(i)];
        
        if valid_states(i) == 1  % Overuse - Red
            plot(x, y, 'r-', 'LineWidth', 2);
        elseif valid_states(i) == 0  % Normal - Black
            plot(x, y, 'k-', 'LineWidth', 2);
        elseif valid_states(i) == -1  % Underuse - Green
            plot(x, y, 'g-', 'LineWidth', 2);
        end
        
        % Add vertical transitions in gray
        if i < length(valid_states) && valid_states(i) ~= valid_states(i+1)
            plot([valid_times(i+1), valid_times(i+1)], [valid_states(i), valid_states(i+1)], 'Color', [0.7 0.7 0.7], 'LineWidth', 1, 'LineStyle', '--');
        end
    else
        % Handle the last segment
        x = [valid_times(i), valid_times(i) + (valid_times(i) - valid_times(i-1))];  % Extend the last segment
        y = [valid_states(i), valid_states(i)];
        
        if valid_states(i) == 1  % Overuse - Red
            plot(x, y, 'r-', 'LineWidth', 2);
        elseif valid_states(i) == 0  % Normal - Black
            plot(x, y, 'k-', 'LineWidth', 2);
        elseif valid_states(i) == -1  % Underuse - Green
            plot(x, y, 'g-', 'LineWidth', 2);
        end
    end
end

% Set y-axis limits and ticks
ylim(ylim_values);
yticks([-1, 0, 1]);
xlim(xlim_values);
yticklabels({'Underuse', 'Normal', 'Overuse'});

% Only set y-axis label
grid on;
set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size
hold off;

%% 4. Merged plotGccTargetRates function with Mbps
ax{4} = subplot('Position', [0.20, sum(heights(5:end))+bottom, 0.70, heights(4)]);
% Add highlight regions
hold on;
ylim_values = [0, 2.5];
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
 [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
 [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');
% Green highlight region
patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
 [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
 [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');
% Normalize the timestamps for plotting
gcc_data = data.gcc_data_filtered;
time_offset = data.min_time;
% Extract data by component type
network_indices = strcmp(gcc_data.component, 'network_controller');
network_data = gcc_data(network_indices, :);
network_data.timestamp_ms(1) = network_data.timestamp_ms(1) - 150;
% Extract timestamps for network_controller data
network_times = (network_data.timestamp_ms - time_offset) / 1000;
hold on;

% Pushback target rate
if ismember('pushback_target_rate_bps', network_data.Properties.VariableNames)
 pushback_rate = network_data.pushback_target_rate_bps;
 valid_indices = find(~isnan(pushback_rate));
 valid_times = network_times(valid_indices);
 valid_pushback_rates = pushback_rate(valid_indices)/1e6; % Convert to Mbps
 stairs(valid_times, valid_pushback_rates, 'g-', 'LineWidth', 1.5, 'DisplayName', 'Pushback Rate');
end

% Loss-based target rate (displayed as "Target Bitrate")
if ismember('loss_based_target_rate_bps', network_data.Properties.VariableNames)
 loss_based_rate = network_data.loss_based_target_rate_bps;
 valid_indices = find(~isnan(loss_based_rate));
 valid_times = network_times(valid_indices);
 valid_rates = loss_based_rate(valid_indices)/1e6; % Convert to Mbps
% Create a step plot instead of continuous line
 stairs(valid_times, valid_rates, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Target Rate');
end

grid on;
% Only set y-axis labels, as this is not the bottom subplot
ylabel({'GCC'; 'Rate'; '(Mbps)'}, 'FontSize', 24);
% Set y-axis limits
ylim(ylim_values);
yticks([0, 1, 2]);
xlim(xlim_values);
set(gca, 'XTickLabel', [], 'FontSize', 24); % Remove x-tick labels and set font size

% Add legend with font size 20
lgd = legend('show', 'Location', 'northeast');
set(lgd, 'FontSize', 20); % Set font size to 20 and remove box

hold off;

%% 5. App resolution and framerate plot with dual y-axes
ax{5} = subplot('Position', [0.20, bottom, 0.70, heights(5)]);

% Add highlight regions
hold on;
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [0, 0, 1000, 1000], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');
% Green highlight region
patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
      [0, 0, 1000, 1000], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Create two y-axes
yyaxis left;
% Use input data
time_offset = data.min_time;
app_time = (data.ts_appout_range - time_offset) / 1000;  % Convert to seconds
resolution_data = data.data_appout(:, 20);
resolution_data(1:16) = resolution_data(17);
framerate_data = data.data_appout(:, 21);
plot(app_time, framerate_data, 'b-', 'LineWidth', 1.5);
ylabel({'Outbound'; 'FPS'}, 'FontSize', 24);
ylim([5, 35]);
yticks(10:10:30);

% Plot resolution on the right y-axis
yyaxis right;
% Plot resolution
plot(app_time, resolution_data, 'r-', 'LineWidth', 1.5);

ylim([180, 900]);
yticks([360, 540, 720]);
yticklabels({'360P', '540P', '720P'});

% Add grid
grid on;
xlim(xlim_values);
% Add legend
lgd = legend('Framerate', 'Resolution', 'Location', 'SouthWest');
lgd.FontSize = 20;
% Keep x-label for bottom subplot
xlabel('Timestamp at Sender (s)', 'FontSize', 26);
set(gca, 'FontSize', 24); % Set font size
hold off;

%% Link x-axes 
linkaxes([ax{:}], 'x');

%% Set zorder to ensure highlight boxes are in the background
for i = 1:length(ax)
    % Get all children of the axes
    children = get(ax{i}, 'Children');
    
    % Find patches (highlight boxes)
    rect_idx = [];
    for j = 1:length(children)
        if strcmp(get(children(j), 'Type'), 'patch')
            rect_idx = [rect_idx; j];
        end
    end
    
    % Move rectangles to the back by reordering children
    if ~isempty(rect_idx)
        non_rect_idx = setdiff(1:length(children), rect_idx);
        new_order = [children(non_rect_idx); children(rect_idx)];
        set(ax{i}, 'Children', new_order);
    end
end

% Save figure with proper sizing
fig = gcf;
fig.PaperPositionMode = 'auto';
fig.PaperUnits = 'inches';
papersize = fig.PaperSize;
fig.PaperSize = [fig.PaperPosition(3), fig.PaperPosition(4)];