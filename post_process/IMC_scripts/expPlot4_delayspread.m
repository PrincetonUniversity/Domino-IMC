%% Parameters
clear;close all

% Define experiment and application codes
% expCode = '0418';
% appCode = '1745261055';
% linktype = 'U'; % 'U' for uplink, 'D' for downlink
% tbs_threshold = 1; % TBs smaller than this are considered proactive (kbits)
% enb2sfu_delay = 4.8; % ms
% relative_plot_period = [232180, 232285];

% 100 MHz
% expCode = '0419';
% appCode = '1745262410';
% linktype = 'U'; % 'U' for uplink, 'D' for downlink
% tbs_threshold = 1; % TBs smaller than this are considered proactive (kbits)
% enb2sfu_delay = 5.4; % ms
% relative_plot_period = [232233, 232338];

expCode = '0418';
appCode = '1745461047';
linktype = 'D'; % 'U' for uplink, 'D' for downlink
tbs_threshold = 11; % TBs smaller than this are considered proactive (kbits)
enb2sfu_delay = 1.1; % ms
relative_plot_period = [232000, 232500];

% Load data
[ulData, dlData, config] = loadWebRTCData(expCode, appCode, enb2sfu_delay);

%% Process data for time period
% Calculate UL plot period based on UL data start time
ul_start_time = floor(ulData.data_packets(1,14));
ul_plot_period = [ul_start_time + relative_plot_period(1), ul_start_time + relative_plot_period(2)];

% Calculate DL plot period based on DL data start time
dl_start_time = floor(dlData.data_packets(1,14));
dl_plot_period = [dl_start_time + relative_plot_period(1), dl_start_time + relative_plot_period(2)];

% Process data with appropriate direction parameters
ulData = processDataForTimePeriod(ulData, ul_plot_period, config, 'UL');
dlData = processDataForTimePeriod(dlData, dl_plot_period, config, 'DL');

%% Create figure based on linktype
figure;
set(gcf, 'Position', [100, 100, 1400, 900]);

% Determine which data to use based on linktype
if strcmpi(linktype, 'U')
    data = ulData;
    direction_label = 'Uplink';
else % 'D'
    data = dlData;
    direction_label = 'Downlink';
end

% Plot delay spread
plotDelaySpread(data, tbs_threshold, config);

sgtitle(['WebRTC ' direction_label ' Packet Delay Analysis - Exp: ' expCode], 'FontSize', 14);