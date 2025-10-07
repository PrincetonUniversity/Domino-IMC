%% Data preparation
clear;close all

% Define parameters
expCode = '0623_5';
experiment_name = ['zoom-' expCode];
header_len = 34; % 34 bytes

% read packets data1
filename = ['../zoom_data/data_exp' expCode '/' experiment_name '-join-pkts-up.csv'];
headers1 = readcell(filename, 'Range', '1:1');  % Read only the first row
data_packets1 = readmatrix(filename, 'Range', 2);  % Skip the first row
ts_pktOffset1 = data_packets1(1, 1)*1000;


% read packets data2
expCode = '0624_1';
experiment_name = ['zoom-' expCode];

filename2 = ['../zoom_data/data_exp' expCode '/' experiment_name '-join-pkts-up.csv'];
headers2 = readcell(filename2, 'Range', '1:1');  % Read only the first row
data_packets2 = readmatrix(filename2, 'Range', 2);  % Skip the first row
ts_pktOffset2 = data_packets2(1, 1)*1000;

%% Thrpt/Delay Analysis
ts_ue_st1 = floor(data_packets1(1,12));
plot_period1 = [ts_ue_st1+000001, ts_ue_st1+300000]; 

% obtaining packets data
pkt_st1 = find(data_packets1(:, 13) > plot_period1(1), 1, 'first');
pkt_ed1 = find(data_packets1(:, 13) < plot_period1(2), 1, 'last');

ts_ue1 = data_packets1(pkt_st1:pkt_ed1, 12);
ts_core1 = data_packets1(pkt_st1:pkt_ed1, 13);
delay_core1 = data_packets1(pkt_st1:pkt_ed1, 14);
pkt_len1 = (data_packets1(pkt_st1:pkt_ed1, 7)+header_len)*8;


%2
ts_ue_st2 = floor(data_packets2(1,12));
plot_period2 = [ts_ue_st2+000001, ts_ue_st2+300000]; 

% obtaining packets data
pkt_st2 = find(data_packets2(:, 13) > plot_period2(1), 1, 'first');
pkt_ed2 = find(data_packets2(:, 13) < plot_period2(2), 1, 'last');

ts_ue2 = data_packets2(pkt_st2:pkt_ed2, 12);
ts_core2 = data_packets2(pkt_st2:pkt_ed2, 13);
delay_core2 = data_packets2(pkt_st2:pkt_ed2, 14);
pkt_len2 = (data_packets2(pkt_st2:pkt_ed2, 7)+header_len)*8;


figure(1);
d1 = plot(ts_core1, delay_core1, '-d');hold on
d2 = plot(ts_core2, delay_core2, '-d');hold on
xlabel('Timestamp (ms)', 'FontSize', 20);
ylabel('Delay', 'FontSize', 20);
legend('5','6');
set(gca, 'FontSize', 20);