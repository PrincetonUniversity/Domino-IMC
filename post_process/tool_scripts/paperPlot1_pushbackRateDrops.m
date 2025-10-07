%% Parameters
% Define parameters - use the same as in the original script
clear;close all
expCode = '0416';
appCode = '1744748558';
% expCode = '0417';
% appCode = '1744753467';
experiment_name = ['webrtc-' expCode];
time_drifting = 1; % 1ms
header_len = 34; % 34 bytes
enb2sfu_delay = 0.0;

% Determine slot duration based on experiment code
scs30k = {'0404', '0407', '0412', '0413', '0419'};
scs15k = {'0406', '0405', '0414', '0416', '0417', '0418'};
% Check if expCode is a member of either array
if ismember(expCode, scs30k)
    slot_duration = 0.5; % SCS: 30KHz
elseif ismember(expCode, scs15k)
    slot_duration = 1; % SCS: 15KHz
else
    % Default value or error handling if needed
    warning('Unknown expCode: %s. Using default slot_duration.', expCode);
    slot_duration = NaN; % or some default value
end

% Determine duplex mode based on experiment code
fdd_codes = {'0416', '0417'}; % Add '0417' to FDD list
tdd_codes = {'0404', '0405', '0406', '0407', '0412', '0413', '0414'}; % All others to TDD list
% Check expCode
if ismember(expCode, fdd_codes)
    duplex_mode = 'FDD';
elseif ismember(expCode, tdd_codes)
    duplex_mode = 'TDD';
else
    warning('Unknown expCode: %s. Using default duplex mode.', expCode);
    duplex_mode = 'unknown';
end

% Moving average window size for packet delay
window_size = 10;

% Bin sizes for different metrics
bin_sz_phy = 50;  % PHY data bin size (ms)
% bin_sz_app = 50;  % App data bin size (ms)
bin_sz_wrapper = 50; % Bin size for capacity comparison (ms)

% Define relative plot period
relative_plot_period = [0, 2300000];

%% Load data for both uplink and downlink
% Read RNTIs from file
datapath = '~/Documents/data/athena/';
rnti_file_path = [datapath 'data_exp' expCode '/rnti.txt'];
RNTIs_of_interest = readmatrix(rnti_file_path);

% Create a struct to store all data
ulData = struct();
dlData = struct();

% Load data for both links
linktypes = {'U', 'D'};
data_structs = {ulData, dlData};

for i = 1:length(linktypes)
    linktype = linktypes{i};
    data_struct = data_structs{i};
    
    % Set direction-specific parameters
    if strcmp(linktype, 'U')
        dir_prefix = 'UL';
        pkts_file_suffix = '-join-pkts-up.csv';
        appout_rtp = '-out-rtp-2.csv';
        appin_rtp = '-in-rtp-1.csv';
        apppc_file = '-pc-2.csv';
        gcc_file = '-gcc-2.csv';
        direction_title = 'Uplink';
    else % 'D'
        dir_prefix = 'DL';
        pkts_file_suffix = '-join-pkts-down.csv';
        appout_rtp = '-out-rtp-1.csv';
        appin_rtp = '-in-rtp-2.csv';
        apppc_file = '-pc-1.csv';
        gcc_file = '-gcc-1.csv';
        direction_title = 'Downlink';
    end
    
    % Read packets data
    pktname = [datapath '/data_exp' expCode '/' experiment_name pkts_file_suffix];
    headers = readcell(pktname, 'Range', '1:1');
    data_packets = readmatrix(pktname, 'Range', 2);
    ts_pktOffset = data_packets(1, 1)*1000;
    
    % Read PHY data
    phyname = [datapath '/data_exp' expCode '/' dir_prefix '_tbs_delay_' expCode '.mat'];
    phy_data = load(phyname);
    ts_dcilog = [phy_data.dci_log.ts] - ts_pktOffset - time_drifting; % in unit of ms
    
    % Read app logs
    appout = [datapath '/data_exp' expCode '/' appCode appout_rtp];
    appin = [datapath '/data_exp' expCode '/' appCode appin_rtp];
    apppc = [datapath '/data_exp' expCode '/' appCode apppc_file];
    
    % Read app-out
    outheaders = readcell(appout, 'Range', '1:1');
    opts = detectImportOptions(appout);
    opts.VariableNamesLine = 1;
    temp_table = readtable(appout, opts);
    video_idx = strcmp(temp_table.kind, 'video');
    file_appout = readmatrix(appout);
    file_appout = file_appout(video_idx, :);
    ts_appout = file_appout(:, 1) - file_appout(1, 1) + data_packets(1, 14);
    data_table_appout = temp_table(video_idx, :);
    quality_cell = data_table_appout.quality_limitation_reason;
    
    % Read app-in
    inheaders = readcell(appin, 'Range', '1:1');
    opts = detectImportOptions(appin);
    opts.VariableNamesLine = 1;
    temp_table = readtable(appin, opts);
    video_idx = strcmp(temp_table.kind, 'video');
    file_appin = readmatrix(appin, 'Range', 2);
    file_appin = file_appin(video_idx, :);
    ts_appin = file_appin(:, 1) - file_appin(1, 1) + data_packets(1, 14);
    
    % Read PC data
    pcheaders = readcell(apppc, 'Range', '1:1');
    file_apppc = readmatrix(apppc, 'Range', 2);
    ts_apppc = file_apppc(:, 1) - file_apppc(1, 1) + data_packets(1, 14);
    
    % Read GCC data
    gcc_filename = [datapath 'data_exp' expCode '/' appCode gcc_file];
    if exist(gcc_filename, 'file')
        % Read the CSV file
        opts = detectImportOptions(gcc_filename);
        opts.VariableNamesLine = 1;
        opts.DataLines = 2;
        opts.Delimiter = ',';
        
        % Convert all numeric cell columns to double arrays
        numericCols = {'timestamp_ms', 'modified_trend', 'threshold', 'target_bitrate_bps', ...
                      'loss_based_target_rate_bps', 'pushback_target_rate_bps', ...
                      'stable_target_rate_bps', 'fraction_loss', 'peer_id', ...
                      'outstanding_bytes', 'time_window_ms', 'data_window_bytes'};
        
        % Set all specified numeric columns to type 'double'
        for j = 1:length(numericCols)
            colName = numericCols{j};
            if any(strcmp(opts.VariableNames, colName))
                opts = setvartype(opts, colName, 'double');
            end
        end
        
        gcc_data = readtable(gcc_filename, opts);
        
        % Convert any remaining cell columns to numeric if needed
        for j = 1:length(numericCols)
            colName = numericCols{j};
            if ismember(colName, gcc_data.Properties.VariableNames) && iscell(gcc_data.(colName))
                gcc_data.(colName) = cellfun(@str2double, gcc_data.(colName));
            end
        end
        
        % Normalize timestamps
        first_timestamp = gcc_data.timestamp_ms(1);
        gcc_data.timestamp_ms = gcc_data.timestamp_ms - first_timestamp;
    else
        gcc_data = [];
        warning('GCC data file %s does not exist.', gcc_filename);
    end
    
    % Save data to the appropriate struct
    if strcmp(linktype, 'U')
        ulData.data_packets = data_packets;
        ulData.ts_dcilog = ts_dcilog;
        ulData.dci_log = phy_data.dci_log;
        ulData.ts_appout = ts_appout;
        ulData.file_appout = file_appout;
        ulData.quality_cell = quality_cell;
        ulData.ts_appin = ts_appin;
        ulData.file_appin = file_appin;
        ulData.ts_apppc = ts_apppc;
        ulData.file_apppc = file_apppc;
        ulData.ts_pktOffset = ts_pktOffset;
        ulData.direction = direction_title;
        ulData.gcc_data = gcc_data;
    else
        dlData.data_packets = data_packets;
        dlData.ts_dcilog = ts_dcilog;
        dlData.dci_log = phy_data.dci_log;
        dlData.ts_appout = ts_appout;
        dlData.file_appout = file_appout;
        dlData.quality_cell = quality_cell;
        dlData.ts_appin = ts_appin;
        dlData.file_appin = file_appin;
        dlData.ts_apppc = ts_apppc;
        dlData.file_apppc = file_apppc;
        dlData.ts_pktOffset = ts_pktOffset;
        dlData.direction = direction_title;
        dlData.gcc_data = gcc_data;
    end
end

%% Define time period for plotting
% Calculate DL plot period based on DL data start time
dl_start_time = floor(dlData.data_packets(1,14));
dl_plot_period = [dl_start_time + relative_plot_period(1), dl_start_time + relative_plot_period(2)];

% Calculate UL plot period based on UL data start time
ul_start_time = floor(ulData.data_packets(1,14));
ul_plot_period = [ul_start_time + relative_plot_period(1), ul_start_time + relative_plot_period(2)];

% Process data with appropriate direction parameters
dlData = processDataForTimePeriod(dlData, dl_plot_period, RNTIs_of_interest, 'DL');
ulData = processDataForTimePeriod(ulData, ul_plot_period, RNTIs_of_interest, 'UL');

export_datapath = [datapath '/data_exp' expCode '/detection_data/'];
%% Create main figure
figure;
set(gcf, 'Position', [100, 100, 1200, 1600]);  % Increase height to accommodate more subplots

% 1. Downlink average PRB
ax1 = subplot(8, 1, 1);
plotPrbAllocation(dlData, bin_sz_phy, slot_duration, duplex_mode, true, export_datapath);
title('Downlink Average PRB Allocation');

% 2. Downlink TBS vs Packet data vs GCC target bitrate (UEs of interest only, Server-based)
ax2 = subplot(8, 1, 2);
plotCapacityComparison(dlData, bin_sz_phy, true, 'server', true, export_datapath);  % true = UEs of interest only, server-based
title('Downlink Capacity: TBS vs Packet vs Target Bitrate (Server-based, UEs of Interest Only)');

% 3. Downlink packet delay (Server-based)
ax3 = subplot(8, 1, 3);
plotPacketDelay(dlData, window_size, 'server', true, export_datapath);
% Title is set within the plotPacketDelay function

% 4. Downlink packet delay (UE-based)
ax4 = subplot(8, 1, 4);
plotPacketDelay(dlData, window_size, 'ue', true, export_datapath);
% Title is set within the plotPacketDelay function

% 5. Uplink Outstanding Bytes
ax5 = subplot(8, 1, 5);
plotGccOutstandingBytes(ulData, false, export_datapath);
title('Uplink Outstanding Bytes');

% 6. Uplink Data Window Bytes
ax6 = subplot(8, 1, 6);
plotGccWindowBytes(ulData, false, export_datapath);
title('Uplink Data Window Bytes');

% 7. Uplink GCC metrics
ax7 = subplot(8, 1, 7);
plotGccTargetRates(ulData, false, export_datapath);
title('Uplink GCC Bitrate Estimates');

% 8. Uplink outbound resolution and framerate
ax8 = subplot(8, 1, 8);
plotResolutionAndFramerate(ulData, false, export_datapath);
title('Uplink Outbound Resolution and Framerate');

% Link x-axes
linkaxes([ax1, ax2, ax3, ax4, ax5, ax6, ax7, ax8], 'x');

% Add overall title
sgtitle('WebRTC Pushback Rate Feedback Loop', 'FontSize', 14);

