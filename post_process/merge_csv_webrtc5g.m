%% Data preparation
clear;close all;

% Define parameters
expCode = '0423';
linktype = 'U';  % 'U' for uplink, 'D' for downlink
ip_ue = '34.21.77.56'; % Amarisoft: '128.112.92.92', GCP: '34.21.77.56'
ip_core = '10.150.0.3'; % Amarisoft: '128.112.92.92', GCP: '10.150.0.3'
experiment_name = ['webrtc-' expCode];

config.ue_pkts_file = ['../data_webrtc/data_exp' expCode '/' experiment_name '-ue.csv'];
config.core_pkts_file = ['../data_webrtc/data_exp' expCode '/' experiment_name '-core.csv'];
config.join_pkts_up_file = ['../data_webrtc/data_exp' expCode '/' experiment_name '-join-pkts-up.csv'];
config.join_pkts_down_file = ['../data_webrtc/data_exp' expCode '/' experiment_name '-join-pkts-down.csv'];

% Determine direction based on linktype
if strcmp(linktype, 'U')
    direction = 'u';
    output_file = config.join_pkts_up_file;
    direction_title = 'Uplink';
elseif strcmp(linktype, 'D')
    direction = 'd';
    output_file = config.join_pkts_down_file;
    direction_title = 'Downlink';
else
    error('Invalid linktype. Must be ''U'' or ''D''.');
end

% Import data
ue_pkts = readtable(config.ue_pkts_file);
core_pkts = readtable(config.core_pkts_file);

% Create and set 'dir' column for ue_pkts
ue_pkts.dir = cell(height(ue_pkts), 1); % Initialize dir as cell array
ue_pkts.dir(:) = {'d'}; % Default all to 'd'
ue_pkts.dir(strcmp(ue_pkts.ip_dst, ip_ue)) = {'u'}; % Set to 'u' where condition is met
ue_pkts.dir = categorical(ue_pkts.dir); % Convert to categorical

% Create and set 'dir' column for core_pkts
core_pkts.dir = cell(height(core_pkts), 1); % Initialize dir as cell array
core_pkts.dir(:) = {'d'}; % Default all to 'd'
core_pkts.dir(strcmp(core_pkts.ip_dst, ip_core)) = {'u'}; % Set to 'u' where condition is met
core_pkts.dir = categorical(core_pkts.dir); % Convert to categorical

% Select relevant columns
ue_pkts = removevars(ue_pkts, {'encap', 'ip_src', 'ip_dst', 'ip_ttl', 'udp_src', 'udp_dst', ...
    'gtp_ip_src', 'gtp_ip_dst', 'gtp_ip_ttl', 'gtp_udp_src', 'gtp_udp_dst', 'rtp_tw_seq', 'media_len', 'av1_frame_number'});
core_pkts = removevars(core_pkts, {'encap', 'ip_src', 'ip_dst', 'ip_ttl', 'udp_src', 'udp_dst', ...
    'gtp_ip_src', 'gtp_ip_dst', 'gtp_ip_ttl', 'gtp_udp_src', 'gtp_udp_dst', 'rtp_tw_seq', 'media_len', 'av1_frame_number'});

% Filter packets based on direction
ue_dir = ue_pkts(ue_pkts.dir == direction, :);
core_dir = core_pkts(core_pkts.dir == direction, :);

% Rename columns for join
ue_dir.Properties.VariableNames{'ts_s'} = 'ts_s_ue';
ue_dir.Properties.VariableNames{'ts_us'} = 'ts_us_ue';
core_dir.Properties.VariableNames{'ts_s'} = 'ts_s_core';
core_dir.Properties.VariableNames{'ts_us'} = 'ts_us_core';

% Perform the outer join
join_dir = outerjoin(ue_dir, core_dir, ...
    'Keys', {'dir', 'rtp_ssrc', 'rtp_pt', 'rtp_seq', 'rtp_ts', 'frame_len'}, ...
    'MergeKeys', true, ...
    'Type', 'full');

% Remove specified fields
join_dir = removevars(join_dir, {'dir'});

% Filter out rows with NaN timestamps
join_dir = join_dir(~isnan(join_dir.ts_s_ue) & ~isnan(join_dir.ts_s_core), :);

% Calculate timestamps and delay
% For uplink: delay = core_time - ue_time
% For downlink: delay = ue_time - core_time
ts_ms_ue = (join_dir.ts_s_ue - min(join_dir.ts_s_ue)) * 1000 + join_dir.ts_us_ue / 1000;
ts_ms_core = (join_dir.ts_s_core - min(join_dir.ts_s_ue)) * 1000 + join_dir.ts_us_core / 1000;

if strcmp(linktype, 'U')
    owd_ms = ts_ms_core - ts_ms_ue; % Uplink delay
else
    owd_ms = ts_ms_ue - ts_ms_core; % Downlink delay
end

join_dir.ts_ms_ue = ts_ms_ue;
join_dir.ts_ms_core = ts_ms_core;
join_dir.owd_ms = owd_ms;

% Reorder rows in ascending order of timestamp
% For uplink: sort by ue_time (source)
% For downlink: sort by core_time (source)
if strcmp(linktype, 'U')
    join_dir = sortrows(join_dir, 'ts_ms_ue');
else
    join_dir = sortrows(join_dir, 'ts_ms_core');
end

% Add sequence column
join_dir.seq = zeros(height(join_dir), 1);
highest_seq = containers.Map('KeyType', 'char', 'ValueType', 'double');
new_seq = 0;

for i = 1:height(join_dir)
    stream_key = sprintf('%s/%s', join_dir.rtp_ssrc(i), join_dir.rtp_pt(i));
    rtp_seq = join_dir.rtp_seq(i);

    if ~isKey(highest_seq, stream_key)
        highest_seq(stream_key) = rtp_seq - 1;
    end

    seq_incr = rtp_seq - highest_seq(stream_key);

    % Handle rtp sequence wrap-around
    if seq_incr < -10000
        seq_incr = 1;
    end

    if rtp_seq > highest_seq(stream_key)
        highest_seq(stream_key) = rtp_seq;
    end

    new_seq = new_seq + seq_incr;
    join_dir.seq(i) = new_seq;
end

% Save joined data
writetable(join_dir, output_file);

% Plotting
figure(1);
ssrc_pt = strcat(string(join_dir.rtp_ssrc), '/', string(join_dir.rtp_pt));
gscatter(join_dir.ts_ms_ue / 1000 / 60, join_dir.rtp_seq, ssrc_pt);
xlabel('Time [min]');
ylabel('RTP Sequence');
legend('Location', 'Best');
title([direction_title ' - Time vs RTP Sequence']);

figure(2);
cdfplot(join_dir.owd_ms);
xlabel(['One-way Delay [ms] - ' direction_title]);
ylabel('CDF');
title(['CDF of One-way Delay - ' direction_title]);