%% Data preparation
clear;

% Define parameters
expCode = '0625_1';
experiment_name = ['zoom-' expCode];

config.ue_pkts_file = ['../data_zoom/data_exp' expCode '/' experiment_name '-ue-pkts.csv'];
config.core_pkts_file = ['../data_zoom/data_exp' expCode '/' experiment_name '-core-pkts.csv'];
config.join_pkts_up_file = ['../data_zoom/data_exp' expCode '/' experiment_name '-join-pkts-up.csv'];

% Import data
ue_pkts = readtable(config.ue_pkts_file);
core_pkts = readtable(config.core_pkts_file);

ue_pkts.dir = categorical(ue_pkts.dir);
core_pkts.dir = categorical(core_pkts.dir);

% Modify 'dir' column
ue_pkts.dir = repmat('d', height(ue_pkts), 1);  % Default to 'd'
ue_pkts.dir(ue_pkts.tp_dst == 8801) = 'u';     % Set to 'u' where tp_dst is 8801
core_pkts.dir = repmat('d', height(core_pkts), 1);  % Default to 'd'
core_pkts.dir(core_pkts.tp_dst == 8801) = 'u';     % Set to 'u' where tp_dst is 8801

% Select relevant columns
ue_pkts = removevars(ue_pkts, {'flow_type', 'ip_proto', 'ip_src', 'tp_src', 'ip_dst', 'tp_dst', 'drop'});
core_pkts = removevars(core_pkts, {'flow_type', 'ip_proto', 'ip_src', 'tp_src', 'ip_dst', 'tp_dst', 'drop'});

% Filter and rename columns for join
ue_up = ue_pkts(ue_pkts.dir == 'u', :);
core_up = core_pkts(core_pkts.dir == 'u', :);

ue_up.Properties.VariableNames{'x_ts_s'} = 'ts_s_ue';
ue_up.Properties.VariableNames{'ts_us'} = 'ts_us_ue';
core_up.Properties.VariableNames{'x_ts_s'} = 'ts_s_core';
core_up.Properties.VariableNames{'ts_us'} = 'ts_us_core';

% Perform the outer join
join_up = outerjoin(ue_up, core_up, ...
    'Keys', {'dir', 'media_type', 'ssrc', 'pt', 'rtp_seq', 'rtp_ts', 'pl_len'}, ...
    'MergeKeys', true, ...
    'Type', 'full');

% Remove specified fields
join_up = removevars(join_up, {'dir', 'media_type', 'pkts_in_frame_ue_up', 'pkts_in_frame_core_up'});

% Filter out rows with NaN timestamps
join_up = join_up(~isnan(join_up.ts_s_ue) & ~isnan(join_up.ts_s_core), :);

% Calculate timestamps and one-way delay
ts_ms_ue = (join_up.ts_s_ue - min(join_up.ts_s_ue)) * 1000 + join_up.ts_us_ue / 1000;
ts_ms_core = (join_up.ts_s_core - min(join_up.ts_s_ue)) * 1000 + join_up.ts_us_core / 1000;
owd_ms = ts_ms_core - ts_ms_ue;

join_up.ts_ms_ue = ts_ms_ue;
join_up.ts_ms_core = ts_ms_core;
join_up.owd_ms = owd_ms;

% Reorder rows in ascending order of ts_ms_ue
join_up = sortrows(join_up, 'ts_ms_ue');

% Add sequence column
join_up.seq = zeros(height(join_up), 1);
highest_seq = containers.Map('KeyType', 'char', 'ValueType', 'double');
new_seq = 0;

for i = 1:height(join_up)
    stream_key = sprintf('%s/%s', join_up.ssrc(i), join_up.pt(i));
    rtp_seq = join_up.rtp_seq(i);

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
    join_up.seq(i) = new_seq;
end

% Save joined data
writetable(join_up, config.join_pkts_up_file);

% % Group and summarize data
% summary_data = groupsummary(join_up, {'pt', 'ssrc', 'media_type'}, 'IncludeEmptyGroups',true, 'n', 'Dur_min', 'mean');
% summary_data.Dur_min = (summary_data.max_ts_ms_ue - summary_data.min_ts_ms_ue) / 1000 / 60;

% Plotting
figure(1);
ssrc_pt = strcat(string(join_up.ssrc), '/', string(join_up.pt));
gscatter(join_up.ts_ms_ue / 1000 / 60, join_up.rtp_seq, ssrc_pt);
xlabel('Time [min]');
ylabel('RTP Sequence');
legend('Location', 'Best');
title('Time vs RTP Sequence');

figure(2);
cdfplot(join_up.owd_ms);
xlabel('One-way Delay [ms]');
ylabel('CDF');
title('CDF of One-way Delay');


