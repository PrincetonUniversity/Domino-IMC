 %% Parameters
% Define parameters - use the same as in the original script
clear;close all
% expCode = '0416';
% appCode = '1744748558';
expCode = '0417';
appCode = '1744753467';
% expCode = '0418';
% appCode = '1745261055';
% expCode = '0421';
% appCode = '1745693934';
% expCode = '0422';
% appCode = '1745696580';
% expCode = '0423';
% appCode = '1745699530';
% expCode = '0426';
% appCode = '1746214121';

experiment_name = ['webrtc-' expCode];
time_drifting = 1; % 1ms
header_len = 34; % 34 bytes
enb2sfu_delay = 0.0;

% Moving average window size for packet delay
window_size = 1;
% Bin sizes
bin_sz_phy = 50;  % PHY data bin size (ms)
bin_sz_prb = 50;  % PRB data bin size (ms)
bin_sz_tbs = 50;  % PRB data bin size (ms)
bin_sz_mcs = 200;
enb2sfu_delay = -5.0; % ms

% Define relative plot period
relative_plot_period = [1, 44390000];

% Load data
datapath = '~/Documents/data/athena/';
[ulData, dlData, config] = loadWebRTCData(expCode, appCode, enb2sfu_delay, datapath);

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

export_datapath = [datapath '/data_exp' expCode '/detection_data/'];

%% Feature export from the NR-Scope log and the webrtc log

%% GCC detects overuse
GccOverUse(dlData, true, export_datapath);
GccOverUse(ulData, false, export_datapath);

% DL server outbound bitrate and DL 5G bitrate
CapacityComparison(dlData, bin_sz_phy, true, 'server', true, export_datapath);
% UL UE outbound bitrate and UL 5G bitrate
CapacityComparison(ulData, bin_sz_phy, true, 'ue', false, export_datapath);

%% Target bitrate down; pushback rate down
% Target bitrate UL
GccTargetRates(ulData, false, export_datapath);
% Target bitrate DL
GccTargetRates(dlData, true, export_datapath);

%% Outbound fps/res/quantization down
ResolutionAndFramerate(ulData, false, export_datapath);
ResolutionAndFramerate(dlData, true, export_datapath);

%% ACKs backlogged, no data.

%% Outstanding bytes up
GccOutstandingBytes(ulData, false, export_datapath);
GccOutstandingBytes(dlData, true, export_datapath);

%% Jitter buffer drains
AppJitterBuffer(dlData, true, export_datapath);
AppJitterBuffer(ulData, false, export_datapath);


%% MCS Box
McsBox(dlData, bin_sz_mcs, true, export_datapath);
McsBox(ulData, bin_sz_mcs, false, export_datapath);

%% PRB allocation
PrbAllocation(dlData, bin_sz_phy, config.slot_duration, config.duplex_mode, true, export_datapath);
PrbAllocation(ulData, bin_sz_phy, config.slot_duration, config.duplex_mode, false, export_datapath);

%% TBS by RNTI
TbsByRnti(ulData, bin_sz_phy, config.RNTIs_of_interest, false, export_datapath);

%% UL and DL delay
PacketDelay(ulData, window_size, 'ue', false, export_datapath);
PacketDelay(dlData, window_size, 'ue', true, export_datapath);
PacketDelay(ulData, window_size, 'server', false, export_datapath);
PacketDelay(dlData, window_size, 'server', true, export_datapath);

%% Trends
GccTrendVsThreshold(ulData, false, export_datapath);
GccTrendVsThreshold(dlData, true, export_datapath);

%% Gcc window bytes
GccWindowBytes(ulData, false, export_datapath);
GccWindowBytes(dlData, true, export_datapath);

%% Gcc Numeric states
GccBandwidthState(ulData, false, export_datapath);
GccBandwidthState(dlData, true, export_datapath);

%% HARQ Retransmissions
HARQReTX(dlData, true, export_datapath);
HARQReTX(ulData, false, export_datapath);