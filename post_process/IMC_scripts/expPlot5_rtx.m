%% Parameters
clear;close all

% Define experiment and application codes
expCode = '0420';
appCode = '1745461047';
linktype = 'U'; % 'U' for uplink, 'D' for downlink
tbs_threshold = 1; % TBs smaller than this are considered proactive (kbits)
enb2sfu_delay = 1.1; % ms
% relative_plot_period = [232371, 232510]; % HARQ RTX
% relative_plot_period = [200215, 200340]; % HARQ RTX
relative_plot_period = [009217, 009404]; % RLC RTX

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
set(gcf, 'Position', [100, 100, 1200, 800]);

% Determine which data to use based on linktype
if strcmpi(linktype, 'U')
    data = ulData;
    direction_label = 'Uplink';
else % 'D'
    data = dlData;
    direction_label = 'Downlink';
end

% Plot delay spread
plotBarRTX(data, config);

sgtitle(['WebRTC ' direction_label ' PHY RTX Analysis - Exp: ' expCode], 'FontSize', 14);