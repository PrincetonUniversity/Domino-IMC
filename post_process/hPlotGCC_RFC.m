function hPlotGCC_RFC(ts_ue, ts_server, delay_pkt)
% hPlotGCCTrendline plots three vertically stacked subplots:
%   1. Raw delay-gradient (slope) vs. sender time (in seconds)
%   2. Filtered delay-gradient (slope) and adaptive threshold vs. sender time (in seconds)
%   3. Overuse/Underuse/Normal state vs. sender time (in seconds)
%
% INPUTS:
%   ts_ue     - [Nx1] vector of packet send timestamps (in milliseconds)
%   ts_server - [Nx1] vector of packet receive timestamps (not used in this function)
%   delay_pkt - [Nx1] vector of per-packet delay measurements (in ms)
%
% The x-axis is computed as (ts_ue - min(ts_ue))/1000 so that it starts at 0 (in seconds).
%
% This function implements a GCC-style overuse estimator with an adaptive threshold.
% The adaptive threshold update uses the following constants:
%    k_up = 0.0087, k_down = 0.039, kMaxAdaptOffsetMs = 15, kMaxTimeDeltaMs = 100,
% and clamps the threshold between 6 and 600.
%
% The state is set as:
%    state =  1 if filtered_slope > threshold (overuse)
%    state = -1 if filtered_slope < -threshold (underuse)
%    state =  0 otherwise (normal)
%
% The figure is plotted in a tight layout.

    %% Hyperparameters for Grouping and Regression
    T_group         = 5;       % Grouping interval in ms (since ts_ue is in ms)
    window_size     = 20;      % Number of groups for sliding window regression
    alpha           = 0.9;     % Exponential smoothing factor

    %% Hyperparameters for Modified Trend (WebRTC style)
    threshold_gain  = 4.0;     % Gains the slope upward/downward
    kMinNumDeltas   = 60;      % Caps the number of deltas used in scaling

    %% Adaptive Threshold Parameters
    % Initial threshold value (ms/s) and update parameters.
    threshold = 12.5;      % initial threshold (ms/s)
    last_update_ms = -1;   % last update time in ms
    k_up = 0.0087;
    k_down = 0.039;
    % Note: WebRTC typically uses kMaxAdaptOffsetMs = 15. Here it's set large (500).    
    kMaxAdaptOffsetMs = 500;
    kMaxTimeDeltaMs = 100;
    min_threshold = 6;
    max_threshold = 600;

    %% Step 1. Compute Delay Offsets
    % Use the minimum delay as baseline.
    d_min = min(delay_pkt);
    offsets = delay_pkt - d_min;
    
    %% Step 2. Group Packets by ts_ue
    % For each group (using sender time in ms), compute a representative time
    % (mean of ts_ue in the group) and the median offset.
    groups_time = [];    % representative ts_ue (in ms) per group
    groups_offset = [];  % median offset per group
    n = length(ts_ue);
    if n < 1
        error('Input vectors are empty.');
    end
    
    % Initialize the first group.
    current_group_start = ts_ue(1);
    temp_ts = ts_ue(1);
    temp_offsets = offsets(1);
    
    for i = 2:n
        if (ts_ue(i) - current_group_start) <= T_group
            temp_ts(end+1) = ts_ue(i);          %#ok<AGROW>
            temp_offsets(end+1) = offsets(i);     %#ok<AGROW>
        else
            groups_time(end+1) = mean(temp_ts);       %#ok<AGROW>
            groups_offset(end+1) = median(temp_offsets); %#ok<AGROW>
            current_group_start = ts_ue(i);
            temp_ts = ts_ue(i);
            temp_offsets = offsets(i);
        end
    end
    % Finalize the last group.
    if ~isempty(temp_ts)
        groups_time(end+1) = mean(temp_ts);
        groups_offset(end+1) = median(temp_offsets);
    end

    %% Adjust groups_time for plotting
    % Convert groups_time (in ms) to seconds, starting at 0.
    groups_time_adj = (groups_time - min(ts_ue)) / 1000;  % in seconds

    %% Step 3. Compute Raw and Exponentially Smoothed Slope via Linear Regression
    num_groups = length(groups_time);
    slopes = nan(1, num_groups);         % raw slope estimates (ms/s)
    filtered_slopes = nan(1, num_groups);  % exponentially smoothed slopes (ms/s)

    % Compute slopes once we have a complete sliding window.
    % Note: X is in ms, so the regression gives ms/ms; multiply by 1000 to get ms/s.
    for i = window_size:num_groups
        idx = i-window_size+1 : i;
        X = groups_time(idx);   % time in ms
        Y = groups_offset(idx); % offsets in ms
        
        % Zero-center X for numerical stability.
        X_centered = X - mean(X);
        if sum(X_centered.^2) > 0
            slope = (sum(X_centered .* (Y - mean(Y))) / sum(X_centered.^2)) * 1000;
        else
            slope = 0;
        end
        slopes(i) = slope;
        
        if i == window_size
            filtered_slopes(i) = slope;
        else
            filtered_slopes(i) = alpha * slope + (1 - alpha) * filtered_slopes(i-1);
        end
    end

    %% Step 4. Adaptive Threshold Update and State Determination
    % For each group (with a computed filtered slope), update the threshold
    % and then set the state based on the updated threshold.
    modified_trend    = nan(1, num_groups);    
    state = zeros(1, num_groups);  % 1 (overuse), -1 (underuse), 0 (normal)
    adaptive_threshold = nan(1, num_groups);  % store threshold per group

    for i = window_size:num_groups
        % Approximate the "number of deltas" as i (or i-window_size+1, etc.).
        % In WebRTC, num_of_deltas_ increments per packet, but group-based is approximate.
        num_deltas = i;  
        
        % Compute the WebRTC-like modified trend.
        modified_trend(i) = min(num_deltas, kMinNumDeltas) ...
                            * filtered_slopes(i) ...
                            * threshold_gain;

        % Time of the current group (ms):        
        now_ms = groups_time(i); % current time in ms
        if last_update_ms == -1
            last_update_ms = now_ms;
        end
        
        % If the absolute filtered slope is much larger than the threshold plus offset,
        % avoid adapting the threshold (to ignore sudden large spikes).
        if abs(modified_trend(i)) > threshold + kMaxAdaptOffsetMs
            last_update_ms = now_ms;
            % threshold remains unchanged.
        else
            % Choose update constant based on the relation between the trend and threshold.
            if abs(modified_trend(i)) < threshold
                k = k_down;
            else
                k = k_up;
            end
            time_delta_ms = min(now_ms - last_update_ms, kMaxTimeDeltaMs);
            threshold = threshold + k * (abs(modified_trend(i)) - threshold) * time_delta_ms;
            % Clamp the threshold between min_threshold and max_threshold.
            threshold = max(min(threshold, max_threshold), min_threshold);
            last_update_ms = now_ms;
        end
        adaptive_threshold(i) = threshold;
        
        % Determine state based on the updated threshold.
        if modified_trend(i) > threshold
            state(i) = 1;
        elseif modified_trend(i) < -threshold
            state(i) = -1;
        else
            state(i) = 0;
        end
    end

    %% Step 5. Plot Figure in a Tight Layout
    % Create figure with a similar "tight" subplot layout.
    figure(5);
    clf;
    set(gcf, 'Position', [200, 200, 1200, 900]);  % [left, bottom, width, height]

    % Define margins and layout parameters.
    left_margin   = 0.1;
    right_margin  = 0.05;
    bottom_margin = 0.05;
    top_margin    = 0.02;
    vertical_gap  = 0.02;
    num_subplots  = 3;
    plot_region_height = 1 - bottom_margin - top_margin;
    subplot_height = (plot_region_height - (num_subplots-1)*vertical_gap) / num_subplots;
    subplot_width  = 1 - left_margin - right_margin;
    
    % Create axes handles.
    ax = gobjects(num_subplots,1);
    
    % Subplot 1: Raw Slope
    pos1 = [left_margin, bottom_margin + 2*(subplot_height + vertical_gap), subplot_width, subplot_height];
    ax(1) = axes('Position', pos1);
    plot(ax(1), groups_time_adj, slopes, '-o', 'LineWidth', 1.5);
    xlabel(ax(1), 'Time (s)');
    ylabel(ax(1), 'Slope (ms/s)');
    title(ax(1), 'Delay Gradient - Raw Slope');
    grid(ax(1), 'on');
    xlim(ax(1), [0 max(groups_time_adj)]);
    
    % Subplot 2: Filtered Slope and Adaptive Threshold
    pos2 = [left_margin, bottom_margin + subplot_height + vertical_gap, subplot_width, subplot_height];
    ax(2) = axes('Position', pos2);
    % Plot filtered slope.
    h1 = plot(ax(2), groups_time_adj, modified_trend, '-o', 'LineWidth', 1.5);
    hold(ax(2), 'on');
    % Plot adaptive threshold.
    h2 = plot(ax(2), groups_time_adj, adaptive_threshold, '--r', 'LineWidth', 1.5);
    h3 = plot(ax(2), groups_time_adj, -adaptive_threshold, '--g', 'LineWidth', 1.5);
    hold(ax(2), 'off');
    xlabel(ax(2), 'Time (s)');
    ylabel(ax(2), 'Slope (ms/s)');
    title(ax(2), 'Delay Gradient - Exponential Smoothing & Adaptive Threshold');
    legend(ax(2), [h1, h2, h3], {'Filtered Slope', 'Adaptive Threshold', 'Adaptive Threshold'}, 'Location', 'Best');
    grid(ax(2), 'on');
    xlim(ax(2), [0 max(groups_time_adj)]);
    
    % Subplot 3: Scatter Plot for Overuse/Underuse
    pos3 = [left_margin, bottom_margin, subplot_width, subplot_height];
    ax(3) = axes('Position', pos3);
    hold(ax(3), 'on');
    % Plot scatter points for overuse (state = 1) and underuse (state = -1)
    overuseIdx = (state == 1);
    underuseIdx = (state == -1);
    % For visualization, plot overuse at y=1 and underuse at y=-1
    scatter(ax(3), groups_time_adj(overuseIdx), ones(sum(overuseIdx),1), 50, 'r', 'filled');
    scatter(ax(3), groups_time_adj(underuseIdx), -ones(sum(underuseIdx),1), 50, 'b', 'filled');
    hold(ax(3), 'off');
    xlabel(ax(3), 'Time (s)');
    ylabel(ax(3), 'State');
    title(ax(3), 'Overuse (red) & Underuse (blue)');
    ylim(ax(3), [-1.5, 1.5]);
    yticks(ax(3), [-1, 0, 1]);
    grid(ax(3), 'on');
    xlim(ax(3), [0 max(groups_time_adj)]);

end
