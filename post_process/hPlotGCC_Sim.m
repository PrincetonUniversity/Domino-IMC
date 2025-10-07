function hPlotGCC_Sim(ts_ue, ts_server, pkt_size)
% hPlotGCC_Src - A more complete illustration of GCC's inter-arrival + trendline logic,
%                storing data per-group, detecting overuse/underuse, and then
%                applying a simple AIMD-like step to compute current bitrate.
%                Finally, plots all results vs. the group's arrival time.
%
%   hPlotGCC_Src(ts_ue, ts_server, pkt_size) takes:
%   1) ts_ue    = send times [ms] for each packet,
%   2) ts_server= arrival times [ms] measured at the receiver,
%   3) pkt_size = packet sizes in bytes.
%
%   This version plots once per grouped interval (no large NaN arrays) and
%   adds a fifth subplot showing the current bitrate. The x-axis is
%   current_group_arrival_end for each finalized group.
%
%   NOTE: The AIMD logic here is simplified. In real GCC, the final
%   bandwidth estimate merges multiple signals (throughput, loss, etc.)
%   and uses more nuanced logic in AimdRateControl.

N = length(ts_ue);
if (length(ts_server) ~= N || length(pkt_size) ~= N)
    error('All input vectors must be the same length.');
end

% ------------------ InterArrival grouping parameters -------------------
send_time_group_length_ms = 5;   % kSendTimeGroupLength
burst_delta_thresh_ms     = 5;   % kBurstDeltaThreshold
max_burst_duration_ms     = 100; % kMaxBurstDuration
arrival_time_offset_limit = 3000; % kArrivalTimeOffsetThreshold (~30ms, set high for demo)

% ------------------ Trendline estimator parameters (simplified) ----------------
window_size         = 20;   % size of packet window to fit the slope
smoothing_coef      = 0.9;  % exponential smoothing
threshold_gain      = 4.0;  % multiply slope by this factor
overusing_time_th   = 10;   % "kOverUsingTimeThreshold"
k_up                = 0.0087;
k_down              = 0.039;
threshold_min       = 6;     % clamp range for threshold
threshold_max       = 600;
adapt_offset_max_ms = 15.0;  % do not adapt threshold for large outliers
initial_threshold   = 12.5;

% ------------------ Simplified AIMD-like parameters ---------------------
% We'll keep a small, made-up "current_bitrate" (kbps) to illustrate how
% Overuse -> reduce rate, Normal -> slowly increase, Underuse -> hold.
initial_bitrate_kbps = 1000;  % start at 1 Mbps
beta_factor          = 0.85;  % overuse backoff factor
add_increase_kbps    = 50;    % additive increase each group if normal
min_bitrate_kbps     = 100;   % clamp lower bound
max_bitrate_kbps     = 5000;  % clamp upper bound

% ------------------ Variables for InterArrival grouping -------------------
current_group_send_max    = NaN;
current_group_send_first  = NaN;
current_group_arrival_end = NaN;
current_group_arrival_first = NaN;
current_group_size        = 0;

prev_group_send_max       = NaN;
prev_group_arrival_end    = NaN;
prev_group_size           = 0;
last_group_complete       = false;

% ------------------ Variables for Trendline filter -----------------------
time_over_using   = -1;
overuse_counter   = 0;
trendline_thresh  = initial_threshold;
prev_trend        = 0.0;      % For detecting slope changes
num_of_deltas     = 0;        % Count deltas used in slope
accumulated_delay = 0.0;      % Summation for smoothing
smoothed_delay    = 0.0;      % Exponential smoothing of delay
first_arrival_ms  = -1;
last_update_ms    = -1;

% Buffers for linear regression
arr_time_buf   = [];
smooth_del_buf = [];

% ------------------ Arrays to store results per group --------------------
groupCount     = 0;   % index into per-group outputs
groupTime      = [];  % x-axis = current_group_arrival_end
groupDelta     = [];  % (arrival_time_delta - send_time_delta)
groupRawSlope  = [];
groupModSlope  = [];
groupThresh    = [];
groupState     = [];  % -1=Underuse, 0=Normal, +1=Overuse

% ------------------ Array for storing the "current bitrate" -------------
groupBitrate   = [];  % store simplified AIMD-based current bitrate

% ------------------ Initialize the simplified current bitrate -----------
current_bitrate = initial_bitrate_kbps;

% =========================================================================
% MAIN LOOP OVER PACKETS
% =========================================================================
for i = 1:N
    send_t   = ts_ue(i);
    arrive_t = ts_server(i);
    size_i   = pkt_size(i);

    % ------------------------ If first packet, init group ----------------
    if i == 1
        current_group_send_max    = send_t;
        current_group_send_first  = send_t;
        current_group_arrival_end = arrive_t;
        current_group_arrival_first = arrive_t;
        current_group_size        = size_i;
        continue;
    end

    % Check if we remain in same group or start new group
    belongs_to_burst = false;
    arrival_delta    = arrive_t - current_group_arrival_end;
    send_delta       = send_t   - current_group_send_max;

    if send_delta == 0
        belongs_to_burst = true;
    else
        propagation_delta = arrival_delta - send_delta;
        if (propagation_delta < 0 && arrival_delta <= burst_delta_thresh_ms && ...
           (arrive_t - current_group_arrival_first) < max_burst_duration_ms)
            belongs_to_burst = true;
        end
    end

    % Decide if new group
    new_group = false;
    if ~belongs_to_burst
        if (send_t - current_group_send_first) > send_time_group_length_ms
            new_group = true;
        end
    end

    calculated_deltas = false;
    send_time_delta    = NaN;
    arrival_time_delta = NaN;

    % ------------------ If new group => finalize the previous group -------
    if new_group
        if last_group_complete
            % Compute InterArrival deltas between prev & current
            send_time_delta    = (current_group_send_max - prev_group_send_max);
            arrival_time_delta = (current_group_arrival_end - prev_group_arrival_end);

            if arrival_time_delta >= 0
                % Check offset
                system_time_delta = 0; % omitted
                if (arrival_time_delta - system_time_delta) < arrival_time_offset_limit
                    calculated_deltas = true;
                end
            end
        end

        % Move current->prev
        prev_group_send_max    = current_group_send_max;
        prev_group_arrival_end = current_group_arrival_end;
        prev_group_size        = current_group_size;
        last_group_complete    = true;

        % Begin a new current group
        current_group_send_max    = send_t;
        current_group_send_first  = send_t;
        current_group_arrival_end = arrive_t;
        current_group_arrival_first = arrive_t;
        current_group_size        = size_i;
    else
        % Still in the same group
        current_group_send_max    = max(current_group_send_max, send_t);
        current_group_arrival_end = arrive_t;
        current_group_size        = current_group_size + size_i;
    end

    % ------------------ If we got valid deltas => Trendline update --------
    if calculated_deltas
        % new group => push data
        groupCount  = groupCount + 1;
        groupEndT   = prev_group_arrival_end; 
        % We'll treat the "end of the old group" as the x-axis for data
        groupTime(groupCount,1) = groupEndT;

        d_ms = (arrival_time_delta - send_time_delta);
        groupDelta(groupCount,1) = d_ms;

        if first_arrival_ms < 0
            first_arrival_ms = groupEndT;
        end

        % Exponential smoothing
        accumulated_delay = accumulated_delay + d_ms;
        smoothed_delay    = smoothing_coef * smoothed_delay ...
                          + (1 - smoothing_coef)*accumulated_delay;

        % Save to buffer
        x_ms = (groupEndT - first_arrival_ms);
        arr_time_buf   = [arr_time_buf, x_ms];
        smooth_del_buf = [smooth_del_buf, smoothed_delay];

        % Keep window_size
        if length(arr_time_buf) > window_size
            arr_time_buf(1)   = [];
            smooth_del_buf(1) = [];
        end

        % Slope calculation if buffer is full
        slope      = prev_trend;
        mod_slope  = 0;  % default
        stateVal   = 0;  % -1=Under,0=Normal,+1=Over

        if length(arr_time_buf) == window_size
            x_mean = mean(arr_time_buf);
            y_mean = mean(smooth_del_buf);
            num = sum((arr_time_buf - x_mean).*(smooth_del_buf - y_mean));
            den = sum((arr_time_buf - x_mean).^2);
            if den ~= 0
                slope = num/den;
            end

            num_of_deltas = min(num_of_deltas+1, 1000);
            mod_slope     = num_of_deltas * slope * threshold_gain;

            % Over/Underuse detection
            if last_update_ms < 0
                last_update_ms = groupEndT;
            end

            if mod_slope > trendline_thresh
                % Potential Overuse
                if time_over_using < 0
                    time_over_using = send_time_delta/2; 
                else
                    time_over_using = time_over_using + send_time_delta;
                end
                overuse_counter = overuse_counter + 1;
                if time_over_using > overusing_time_th && overuse_counter > 1
                    stateVal = +1; % Overuse
                end
            elseif mod_slope < -trendline_thresh
                % Underuse
                stateVal = -1;
                time_over_using = -1;
                overuse_counter = 0;
            else
                % Normal
                stateVal = 0;
                time_over_using = -1;
                overuse_counter = 0;
            end

            % Adaptive threshold
            dt_ms = min(groupEndT - last_update_ms, 100);
            if abs(mod_slope) <= (trendline_thresh + adapt_offset_max_ms)
                if abs(mod_slope) < trendline_thresh
                    k = k_down;
                else
                    k = k_up;
                end
                trendline_thresh = trendline_thresh + ...
                    k*(abs(mod_slope) - trendline_thresh)*dt_ms;
                trendline_thresh = max(threshold_min, ...
                                       min(threshold_max, trendline_thresh));
            end

            last_update_ms = groupEndT;
            prev_trend     = slope;
        end

        groupRawSlope(groupCount,1) = slope;
        groupModSlope(groupCount,1) = mod_slope;
        groupThresh(groupCount,1)   = trendline_thresh;
        groupState(groupCount,1)    = stateVal;

        % -----------------------------------------------------------------
        % --------------- Simplified AIMD-like Bitrate Update -------------
        % Now that we have a final Overuse/Underuse/Normal for this group,
        % we apply a basic version of "rate control".
        %
        % In real GCC:
        %   Overuse => immediate drop ~0.85 x throughput
        %   Normal  => slow additive increase
        %   Underuse=> typically hold or do minimal action
        %
        % We'll do:
        %   Overuse => current_bitrate = current_bitrate * beta_factor
        %   Normal  => current_bitrate = current_bitrate + add_increase_kbps
        %   Underuse=> hold
        % We clamp to [min_bitrate_kbps, max_bitrate_kbps].
        % -----------------------------------------------------------------
        if stateVal == +1
            % Overuse => reduce
            current_bitrate = current_bitrate * beta_factor;
        elseif stateVal == 0
            % Normal => add
            current_bitrate = current_bitrate + add_increase_kbps;
        else
            % Underuse => hold
            % (some advanced logic might do partial adjustments)
        end

        % clamp
        current_bitrate = max(current_bitrate, min_bitrate_kbps);
        current_bitrate = min(current_bitrate, max_bitrate_kbps);

        % store result
        groupBitrate(groupCount,1) = current_bitrate;
    end
end

% =========================================================================
% PLOTTING 
% We have data for 'groupCount' final groups. Each group's x-axis = groupTime.
% =========================================================================
figure(4); clf;

% 1) \Delta plot
subplot(5,1,1);
plot(groupTime, groupDelta, 'b.-');
grid on;
xlabel('Arrival End Time of Group [ms]');
ylabel('\Delta [ms]');
title('recv\_delta - send\_delta (per-group)');

% 2) Raw slope
subplot(5,1,2);
plot(groupTime, groupRawSlope, 'r.-');
grid on;
xlabel('Arrival End Time of Group [ms]');
ylabel('Raw Slope');
title('Trendline Raw Slope');

% 3) Modified slope vs. threshold
subplot(5,1,3); hold on;
plot(groupTime, groupModSlope, 'g.-','DisplayName','Modified Slope');
plot(groupTime, groupThresh,   'k--','DisplayName','Adaptive Thresh');
legend('Location','Best');
grid on;
xlabel('Arrival End Time of Group [ms]');
ylabel('Slope / Threshold');
title('Modified Slope vs. Adaptive Threshold');

% 4) Overuse/Underuse/Stable State
subplot(5,1,4);
plot(groupTime, groupState, 'm.-');
grid on;
ylim([-1.5,1.5]);
xlabel('Arrival End Time of Group [ms]');
ylabel('State');
title('Overuse State (-1=Under,0=Normal,+1=Over)');

% 5) Current Bitrate
subplot(5,1,5);
plot(groupTime, groupBitrate, 'c.-');
grid on;
xlabel('Arrival End Time of Group [ms]');
ylabel('Bitrate [kbps]');
title('Simplified AIMD: Current Bitrate');

end
