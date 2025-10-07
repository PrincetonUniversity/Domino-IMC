%% Parameters
clear;

% Define experiment and application codes
expCode = '0418';
appCode = '1745261055';
linktype = 'D'; % 'U' for uplink, 'D' for downlink

% Moving average window size for packet delay
window_size = 1;
bin_sz_prb = 50;  % PRB data bin size (ms)
bin_sz_tbs = 50;  % PRB data bin size (ms)
enb2sfu_delay = -5.0; % ms

% Define relative plot period
relative_plot_period = [440401, 445600];
xlim_values = [0, 5.2];

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
set(gcf, 'Position', [100, 100, 1200, 800]);  % Increase height to accommodate subplots

% Create array to store axes handles for linking
ax = cell(4, 1);

% Define relative heights for each subplot (sum should be 1)
% Adjust these values to change relative heights
heights = [0.22, 0.26, 0.18, 0.20];
bottom = 0.12;

% Define highlight regions
highlight_pink_x = [1.3688, 2.7562];
highlight_green_x = [2.7562, 4.595];

% Define position for vertical line (as requested)
vertical_line_x = 2.7562;

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

%% 1. Packet Delay Plot (same as original subplot 3)
ax{1} = subplot('Position', [0.15, sum(heights(2:end))+bottom, 0.70, heights(1)]);

% Add highlight regions
hold on;
ylim_values = [0, 300];
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

% Green highlight region
patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [0.8, 1, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

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

% Add vertical dashed line
line([vertical_line_x, vertical_line_x], ylim_values, 'Color', [0.5, 0.5, 0.5], 'LineStyle', '--', 'LineWidth', 1.5, 'HandleVisibility', 'off');

ylabel({'Delay'; '(ms)'}, 'FontSize', 24);
ylim(ylim_values);
yticks([0, 120, 240]);
xlim(xlim_values);
grid on;
set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size
hold off;

%% 2. Jitter Buffer Plot (MODIFIED: removed target jitter buffer curve)
ax{2} = subplot('Position', [0.15, sum(heights(3:end))+bottom, 0.70, heights(2)]);

% Add highlight regions
hold on;
ylim_values = [-50, 400];
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Green highlight region
patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [0.8, 1, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Process time data to start from 0
time_offset = data.min_time;
app_time = (data.ts_appin_range - time_offset) / 1000;  % Convert to seconds
app_time = app_time(2:end);

% Calculate per-frame jitter buffer metrics
jb_delay_diff = [diff(data.data_appin(:, 18))];
jb_target_diff = [diff(data.data_appin(:, 19))];
jb_min_diff = [diff(data.data_appin(:, 20))];
jb_emitted_diff = [diff(data.data_appin(:, 21))];

% Calculate per-frame metrics (avoiding division by zero)
valid_idx = jb_emitted_diff > 0;
jb_delay_per_frame = zeros(size(jb_delay_diff));
jb_target_per_frame = zeros(size(jb_target_diff));
jb_min_per_frame = zeros(size(jb_min_diff));

jb_delay_per_frame(valid_idx) = jb_delay_diff(valid_idx) ./ jb_emitted_diff(valid_idx) * 1000;
jb_target_per_frame(valid_idx) = jb_target_diff(valid_idx) ./ jb_emitted_diff(valid_idx) * 1000;
jb_min_per_frame(valid_idx) = jb_min_diff(valid_idx) ./ jb_emitted_diff(valid_idx) * 1000;

% Plot current and minimum jitter buffer metrics (removed target line)
plot(app_time, jb_delay_per_frame, 'b-', 'LineWidth', 1.5);
plot(app_time, jb_min_per_frame, 'g-', 'LineWidth', 1.5);

% Add vertical dashed line
line([vertical_line_x, vertical_line_x], ylim_values, 'Color', [0.5, 0.5, 0.5], 'LineStyle', '--', 'LineWidth', 1.5, 'HandleVisibility', 'off');

% Add labels
ylabel({'Jitter Buffer'; 'Delay (ms)'}, 'FontSize', 24);
ylim(ylim_values);
yticks([0:150:300]);
xlim(xlim_values);
grid on;

% Add legend (updated to only include curves)
lgd = legend('Current Jitter Buffer', 'Minimum Jitter Buffer', 'Location', 'SouthWest');
lgd.FontSize = 20;
set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size
hold off;

%% 3. Freeze Count and Duration Plot (MODIFIED with curve for freeze duration)
ax{3} = subplot('Position', [0.15, sum(heights(4:end))+bottom, 0.70, heights(3)]);


% Add highlight regions
hold on;
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [-0.1, -0.1, 20, 20], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Green highlight region
patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
      [-0.1, -0.1, 20, 20], ...
      [0.8, 1, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Create two y-axes
% yyaxis left;

% Use input data
time_offset = data.min_time;
app_time = (data.ts_appin_range - time_offset) / 1000;  % Convert to seconds
freeze_count = data.data_appin(:, 46);

% % Plot freeze count
% plot(app_time, freeze_count, 'b-', 'LineWidth', 1.5);
% ylabel({'Freeze'; 'Count'}, 'FontSize', 24);
% ylim([2, 6]);
% yticks([3, 4]);
% yticklabels({'0', '1'});

% Plot freeze duration on the right y-axis
% yyaxis right;
freeze_duration = data.data_appin(:, 47);

% Calculate the difference between consecutive freeze duration values
freeze_duration_diff = diff(freeze_duration);
positive_idx = find(freeze_duration_diff > 0);

% Create a zero curve as the baseline
curve_x = app_time;
curve_y = zeros(size(app_time));

% If there are positive differences, modify the curve to show duration
if ~isempty(positive_idx)
    for i = 1:length(positive_idx)
        % Get the position and value of the positive difference
        pulse_start_idx = positive_idx(i) + 1;
        pulse_value = freeze_duration_diff(positive_idx(i));
        
        % Calculate the end index based on the duration
        % Find nearest time point that's at least pulse_value away from start
        pulse_end_time = app_time(pulse_start_idx) + pulse_value;
        [~, pulse_end_idx] = min(abs(app_time - pulse_end_time));
        
        % If end_idx is exactly at pulse_end_time or earlier, ensure we use the next point
        if app_time(pulse_end_idx) <= pulse_end_time && pulse_end_idx < length(app_time)
            pulse_end_idx = pulse_end_idx + 1;
        end
        
        % Set the curve value to pulse_value for the duration
        curve_y(pulse_start_idx:pulse_end_idx-1) = pulse_value;
    end
end

% Plot the curve
plot(curve_x, curve_y, 'r-', 'LineWidth', 1.5);

% Add vertical dashed line
ylim_values = [-0.1, 0.35];
line([vertical_line_x, vertical_line_x], ylim_values, 'Color', [0.5, 0.5, 0.5], 'LineStyle', '--', 'LineWidth', 1.5, 'HandleVisibility', 'off');

% Set y-axis properties
ylim(ylim_values);
% Only show ytick at 0.215 labeled as "freeze"
yticks([0, 0.215]);
yticklabels({'No Freeze', 'Freeze'});
xlim(xlim_values);

% Add grid
grid on;


% Add legend
lgd = legend('Freeze Duration', 'Location', 'NorthWest');
lgd.FontSize = 20;
set(gca, 'XTickLabel', [], 'FontSize', 24);  % Set font size
hold off;


%% 4. Resolution and Framerate Plot (based on plotAppResoluFr.m with direction='in')
ax{4} = subplot('Position', [0.15, bottom, 0.70, heights(4)]);

% Add highlight regions
hold on;
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [0, 0, 1000, 1000], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Green highlight region
patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
      [0, 0, 1000, 1000], ...
      [0.8, 1, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Create two y-axes
yyaxis left;

% Use input data
time_offset = data.min_time;
app_time = (data.ts_appin_range - time_offset) / 1000;  % Convert to seconds
resolution_data = data.data_appin(:, 33);

framerate_data = data.data_appin(:, 34);
plot(app_time, framerate_data, 'b-', 'LineWidth', 1.5);
ylabel({'Inbound'; 'FPS'}, 'FontSize', 24);
ylim([15, 35]);
yticks([20:5:30]);

% Add vertical dashed line for left y-axis
ylim_values_left = [15, 35];
line([vertical_line_x, vertical_line_x], ylim_values_left, 'Color', [0.5, 0.5, 0.5], 'LineStyle', '--', 'LineWidth', 1.5, 'HandleVisibility', 'off');

% Plot framerate on the right y-axis
yyaxis right;
% Plot resolution
plot(app_time, resolution_data, 'r-', 'LineWidth', 1.5);
ylim([0, 720]);
yticks([180, 360, 540]);
yticklabels({'180P', '360P', '540P'});

% Add vertical dashed line for right y-axis (need to add again for yyaxis right)
ylim_values_right = [0, 720];
line([vertical_line_x, vertical_line_x], ylim_values_right, 'Color', [0.5, 0.5, 0.5], 'LineStyle', '--', 'LineWidth', 1.5, 'HandleVisibility', 'off');

% Add grid
grid on;
xlim(xlim_values);
xticks([0:1:5]);
xlabel('Timestamp at Receiver (s)', 'FontSize', 26);  % Only add x-label to bottom subplot

% Add legend
lgd = legend('Framerate', 'Resolution', 'Location', 'SouthWest');
lgd.FontSize = 20;
set(gca, 'FontSize', 24);  % Remove x-tick labels and set font size
hold off;

%% Link x-axes 
linkaxes([ax{:}], 'x');

%% Set zorder to ensure highlight boxes are in the background
for i = 1:length(ax)
    % Get all children of the axes
    children = get(ax{i}, 'Children');
    
    % Find patch objects (highlight boxes)
    rect_idx = [];
    for j = 1:length(children)
        if strcmp(get(children(j), 'Type'), 'patch')
            rect_idx = [rect_idx; j];
        end
    end
    
    % Move patches to the back by reordering children
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