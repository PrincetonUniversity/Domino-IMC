%% Parameters
clear;

% Define experiment and application codes
expCode = '0417';
appCode = '1744753467';
linktype = 'U'; % 'U' for uplink, 'D' for downlink

% Moving average window size for packet delay
window_size = 1;
% Bin sizes
bin_sz_prb = 50;  % PRB data bin size (ms)
bin_sz_tbs = 50;  % PRB data bin size (ms)
enb2sfu_delay = -5.0; % ms

% Define relative plot period
relative_plot_period = [226001, 230000];
xlim_values = [0, 4];

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
set(gcf, 'Position', [100, 100, 1200, 1000]);  % Maintain figure size

% Create array to store axes handles for linking
ax = cell(5, 1);  % Changed from 6 to 5 subplots

% Define relative heights for each subplot (sum should be 1)
% Adjusted heights for 5 subplots instead of 6
heights = [0.16, 0.16, 0.22, 0.16, 0.16];  % Increased height for subplot 3 (merged)
bottom = 0.1;

% Define highlight regions
highlight_pink_x  = [0.705, 0.909];
highlight_pink_x2 = [1.294, 1.498];
highlight_pink_x3 = [1.612, 1.816];
highlight_pink_x4 = [1.871, 2.075];

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

%% 1. UL Packet Delay plot
ax{1} = subplot('Position', [0.20, sum(heights(2:end))+bottom, 0.70, heights(1)]);

% Add highlight regions
hold on;
ylim_values = [-50, 400];
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

% Green highlight region
patch([highlight_pink_x2(1), highlight_pink_x2(2), highlight_pink_x2(2), highlight_pink_x2(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

patch([highlight_pink_x3(1), highlight_pink_x3(2), highlight_pink_x3(2), highlight_pink_x3(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

patch([highlight_pink_x4(1), highlight_pink_x4(2), highlight_pink_x4(2), highlight_pink_x4(1)], ...
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
yticks([0:150:300]);
xlim(xlim_values);
grid on;
set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size
hold off;

%% 2. DL Packet Delay plot (using opposite_data)
ax{2} = subplot('Position', [0.2, sum(heights(3:end))+bottom, 0.70, heights(2)]);

% Add highlight regions
hold on;
ylim_values = [-50, 400];
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

% Green highlight region
patch([highlight_pink_x2(1), highlight_pink_x2(2), highlight_pink_x2(2), highlight_pink_x2(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

patch([highlight_pink_x3(1), highlight_pink_x3(2), highlight_pink_x3(2), highlight_pink_x3(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

patch([highlight_pink_x4(1), highlight_pink_x4(2), highlight_pink_x4(2), highlight_pink_x4(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');


% Calculate moving average and standard deviation for opposite_data
opp_mov_avg = movmean(opposite_data.delay_pkt, window_size);
opp_mov_avg(167:245) = opp_mov_avg(167:245)*2;
opp_mov_std = movstd(opposite_data.delay_pkt, window_size);

% Choose appropriate timestamps based on xaxis_base parameter
if strcmpi(xaxis_base, 'server')
    % Use server timestamps
    opp_ts_pkt = (opposite_data.ts_server - opposite_data.min_time)/1000;
else % 'ue'
    % Use UE timestamps
    opp_ts_pkt = (opposite_data.ts_ue - opposite_data.min_time)/1000;
end

% Plot shaded area for fluctuation
fill([opp_ts_pkt; flipud(opp_ts_pkt)], ...
     [opp_mov_avg-opp_mov_std; flipud(opp_mov_avg+opp_mov_std)], ...
     'r', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(opp_ts_pkt, opp_mov_avg, 'r', 'LineWidth', 1.5);

ylabel({'Delay of'; 'RTCP'; '(ms)'}, 'FontSize', 24);
ylim(ylim_values);
yticks([0:150:300]);
xlim(xlim_values);
grid on;
set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size
hold off;

%% 3. MERGED: UL Outstanding Bytes and Window Size plot with dual y-axes
ax{3} = subplot('Position', [0.20, sum(heights(4:end))+bottom, 0.70, heights(3)]);

% Add highlight regions
hold on;
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [0, 0, 350, 350], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Green highlight region
patch([highlight_pink_x2(1), highlight_pink_x2(2), highlight_pink_x2(2), highlight_pink_x2(1)], ...
      [0, 0, 350, 350], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

patch([highlight_pink_x3(1), highlight_pink_x3(2), highlight_pink_x3(2), highlight_pink_x3(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

patch([highlight_pink_x4(1), highlight_pink_x4(2), highlight_pink_x4(2), highlight_pink_x4(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Check if GCC data is available
if ~isempty(data.gcc_data_filtered)
    % Normalize the timestamps for plotting
    gcc_data = data.gcc_data_filtered;
    time_offset = data.min_time;
    
    % Extract data by component type
    network_indices = strcmp(gcc_data.component, 'network_controller');
    network_data = gcc_data(network_indices, :);
    
    % Check if we have network_controller data
    if ~isempty(network_data)
        % Extract timestamps for network_controller data
        network_times = (network_data.timestamp_ms - time_offset) / 1000;
        
        % Set up dual y-axes
        yyaxis left;
        
        % Plot Outstanding bytes on left y-axis
        if ismember('outstanding_bytes', network_data.Properties.VariableNames)
            outstanding_bytes = network_data.outstanding_bytes/1000; % KB
            valid_bytes = ~isnan(outstanding_bytes);
            plot(network_times(valid_bytes), outstanding_bytes(valid_bytes), 'b.-', 'LineWidth', 1.5, 'DisplayName', 'Outstanding Bytes');
            ylabel({'Outstanding'; 'Bytes (KB)'}, 'FontSize', 24);
            ylim([0, 350]);
            yticks([0:150:300]);
        else
            text(mean(xlim_values), mean([0, 350]), 'No outstanding bytes data available', 'HorizontalAlignment', 'center', 'FontSize', 20);
        end
        
        % Plot Window size on right y-axis
        yyaxis right;
        
        % Plot Data window bytes
        if ismember('data_window_bytes', network_data.Properties.VariableNames)
            data_window = network_data.data_window_bytes / 1000; % KB
            valid_window = ~isnan(data_window);
            plot(network_times(valid_window), data_window(valid_window), 'r.-', 'LineWidth', 1.5, 'DisplayName', 'Window Size');
            % ylabel({'Window'; 'Size (KB)'}, 'FontSize', 24);
            ylim([0, 350]);
            yticks([0:150:300]);
        else
            text(mean(xlim_values), mean([0, 350]), 'No data window size available', 'HorizontalAlignment', 'center', 'FontSize', 20);
        end
        
    else
        text(mean(xlim_values), mean([0, 350]), 'No network_controller data available', 'HorizontalAlignment', 'center', 'FontSize', 20);
    end
else
    text(mean(xlim_values), mean([0, 350]), 'GCC data not available', 'HorizontalAlignment', 'center', 'FontSize', 20);
end

xlim(xlim_values);
grid on;
set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size

% Add legend
lgd = legend('show', 'Location', 'northeast');
set(lgd, 'FontSize', 20);

hold off;

%% 4. Target Rate and Pushback Rate plot (previously subplot 5)
ax{4} = subplot('Position', [0.20, sum(heights(5:end))+bottom, 0.70, heights(4)]);
% Add highlight regions
hold on;
ylim_values = [0, 6];
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
 [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
 [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Green highlight region
patch([highlight_pink_x2(1), highlight_pink_x2(2), highlight_pink_x2(2), highlight_pink_x2(1)], ...
 [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
 [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

patch([highlight_pink_x3(1), highlight_pink_x3(2), highlight_pink_x3(2), highlight_pink_x3(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

patch([highlight_pink_x4(1), highlight_pink_x4(2), highlight_pink_x4(2), highlight_pink_x4(1)], ...
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
yticks([0, 2, 4]);
xlim(xlim_values);
set(gca, 'XTickLabel', [], 'FontSize', 24); % Remove x-tick labels and set font size

% Add legend with font size 20
lgd = legend('show', 'Location', 'southeast');
set(lgd, 'FontSize', 20); % Set font size to 20 and remove box

hold off;

%% 5. App resolution and framerate plot with dual y-axes (previously subplot 6)
ax{5} = subplot('Position', [0.20, bottom, 0.70, heights(5)]);

% Add highlight regions
hold on;
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [0, 0, 1000, 1000], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Green highlight region
patch([highlight_pink_x2(1), highlight_pink_x2(2), highlight_pink_x2(2), highlight_pink_x2(1)], ...
      [0, 0, 1000, 1000], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

patch([highlight_pink_x3(1), highlight_pink_x3(2), highlight_pink_x3(2), highlight_pink_x3(1)], ...
      [0, 0, 1000, 1000], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

patch([highlight_pink_x4(1), highlight_pink_x4(2), highlight_pink_x4(2), highlight_pink_x4(1)], ...
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
ylim([15, 35]);
yticks(20:5:30);

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
lgd = legend('Framerate', 'Resolution', 'Location', 'SouthEast');
lgd.FontSize = 20;
% Keep x-label for bottom subplot
xlabel('Timestamp at UE (s)', 'FontSize', 26);
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