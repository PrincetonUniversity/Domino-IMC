%% Parameters
clear;close all

% Define experiment and application codes
expCode = '0426';
% appCode = '1745693934';
% appCode = '1745696580';
% appCode = '1745699530';
appCode = '1746214121';

enb2sfu_delay = 0.0; % ms
time_offset = 10; % ms

% Define relative plot period
relative_plot_period = [000001, 1800000];
% Load data
[ulData, dlData, config] = loadWebRTCData_noPHY(expCode, appCode, enb2sfu_delay);


xlim_delay = [1, 1000];  % Changed to [1, 1000] as requested
xlim_bitrate = [0, 15.2];
xlim_fr = [0, 60];
xlim_jb = [0, 800];
xlim_resolution = [0, 1080];  % Added for the resolution plot


% Set up figure properties
figSize = [800, 400];
figPos = [100, 100];

%% CDF of Delay
figure('Position', [figPos, figSize]);
hold on;

% Get delay data with time offset
ul_delay = ulData.data_packets(:, 16) + time_offset;
dl_delay = dlData.data_packets(:, 16) + time_offset;

% if strcmp(expCode, '0426')
%     dl_delay(1:10) = 40:10:130;
% end

% Compute CDFs
[F_ul_delay, X_ul_delay] = compute_cdf(ul_delay);
[F_dl_delay, X_dl_delay] = compute_cdf(dl_delay);

% Plot CDFs
plot(X_ul_delay, F_ul_delay, 'b-', 'LineWidth', 4);  % Changed LineWidth to 4
plot(X_dl_delay, F_dl_delay, 'r-', 'LineWidth', 4);  % Changed LineWidth to 4

% Add labels and legend
xlabel('Delay (ms)');
xlim(xlim_delay);
xticks([1,10,100,1000]);
set(gca, 'XScale', 'log');  % Set x-axis to log scale as requested
ylabel('CDF');
yticks(0:0.25:1);
% No title
legend('UL', 'DL', 'Location', 'southeast', 'fontsize', 26);
set(gca, 'FontSize', 32);
grid on;
hold off;

%% CDF of Bitrate
figure('Position', [figPos(1)+figSize(1)+20, figPos(2), figSize]);
hold on;

% Get bitrate data (starting from index 10 as specified)
ul_bitrate = ulData.file_appout(10:end, 14);
dl_bitrate = dlData.file_appout(10:end, 14);

% Convert to Mbps for better readability
ul_bitrate = ul_bitrate / 1e6;
dl_bitrate = dl_bitrate / 1e6;

% Compute CDFs
[F_ul_bitrate, X_ul_bitrate] = compute_cdf(ul_bitrate);
[F_dl_bitrate, X_dl_bitrate] = compute_cdf(dl_bitrate);

% Plot CDFs
plot(X_ul_bitrate, F_ul_bitrate, 'b-', 'LineWidth', 4);  % Changed LineWidth to 4
plot(X_dl_bitrate, F_dl_bitrate, 'r-', 'LineWidth', 4);  % Changed LineWidth to 4

% Add labels and legend
xlabel('Bitrate (Mbps)');
xlim(xlim_bitrate);
ylabel('CDF');
yticks(0:0.25:1);
% No title
legend('UL', 'DL', 'Location', 'southeast');
set(gca, 'FontSize', 32);
grid on;
hold off;

%% CDF of Framerate
figure('Position', [figPos(1), figPos(2)+figSize(2)+20, figSize]);
hold on;

% Get framerate data (starting from index 10 as specified)
ul_framerate = ulData.file_appin(10:end, 34);
dl_framerate = dlData.file_appin(10:end, 34);

% Compute CDFs
[F_ul_framerate, X_ul_framerate] = compute_cdf(ul_framerate);
[F_dl_framerate, X_dl_framerate] = compute_cdf(dl_framerate);

% Plot CDFs
plot(X_ul_framerate, F_ul_framerate, 'b-', 'LineWidth', 4);  % Changed LineWidth to 4
plot(X_dl_framerate, F_dl_framerate, 'r-', 'LineWidth', 4);  % Changed LineWidth to 4

% Add labels and legend
xlabel('Framerate (fps)');
xlim(xlim_fr);
ylabel('CDF');
yticks(0:0.25:1);
% No title
legend('UL', 'DL', 'Location', 'southeast');
set(gca, 'FontSize', 32);
grid on;
hold off;


%% CDF of Video and Audio Jitter Buffer
figure('Position', [figPos(1)+figSize(1)+20, figPos(2)+figSize(2)+20, figSize]);
hold on;

% Calculate video jitter buffer for uplink
ul_video_jb_delay_diff = diff(ulData.file_appin(:, 18));
ul_video_jb_emitted_diff = diff(ulData.file_appin(:, 21));
ul_video_valid_idx = ul_video_jb_emitted_diff > 0;
ul_video_jb_delay_per_frame = zeros(size(ul_video_jb_delay_diff));
ul_video_jb_delay_per_frame(ul_video_valid_idx) = ul_video_jb_delay_diff(ul_video_valid_idx) ./ ul_video_jb_emitted_diff(ul_video_valid_idx) * 1000;

% Calculate video jitter buffer for downlink
dl_video_jb_delay_diff = diff(dlData.file_appin(:, 18));
dl_video_jb_emitted_diff = diff(dlData.file_appin(:, 21));
dl_video_valid_idx = dl_video_jb_emitted_diff > 0;
dl_video_jb_delay_per_frame = zeros(size(dl_video_jb_delay_diff));
dl_video_jb_delay_per_frame(dl_video_valid_idx) = dl_video_jb_delay_diff(dl_video_valid_idx) ./ dl_video_jb_emitted_diff(dl_video_valid_idx) * 1000;

% Calculate audio jitter buffer for uplink
ul_audio_jb_delay_diff = diff(ulData.audio_appin(:, 18));
ul_audio_jb_emitted_diff = diff(ulData.audio_appin(:, 21));
ul_audio_valid_idx = ul_audio_jb_emitted_diff > 0;
ul_audio_jb_delay_per_frame = zeros(size(ul_audio_jb_delay_diff));
ul_audio_jb_delay_per_frame(ul_audio_valid_idx) = ul_audio_jb_delay_diff(ul_audio_valid_idx) ./ ul_audio_jb_emitted_diff(ul_audio_valid_idx) * 1000;

% Calculate audio jitter buffer for downlink
dl_audio_jb_delay_diff = diff(dlData.audio_appin(:, 18));
dl_audio_jb_emitted_diff = diff(dlData.audio_appin(:, 21));
dl_audio_valid_idx = dl_audio_jb_emitted_diff > 0;
dl_audio_jb_delay_per_frame = zeros(size(dl_audio_jb_delay_diff));
dl_audio_jb_delay_per_frame(dl_audio_valid_idx) = dl_audio_jb_delay_diff(dl_audio_valid_idx) ./ dl_audio_jb_emitted_diff(dl_audio_valid_idx) * 1000;

% Remove extreme outliers (optional, adjust threshold as needed)
ul_video_jb_delay_per_frame = ul_video_jb_delay_per_frame(ul_video_jb_delay_per_frame < 1000);
dl_video_jb_delay_per_frame = dl_video_jb_delay_per_frame(dl_video_jb_delay_per_frame < 1000);
ul_audio_jb_delay_per_frame = ul_audio_jb_delay_per_frame(ul_audio_jb_delay_per_frame < 1000);
dl_audio_jb_delay_per_frame = dl_audio_jb_delay_per_frame(dl_audio_jb_delay_per_frame < 1000);

% Compute CDFs for video
[F_ul_video_jb, X_ul_video_jb] = compute_cdf(ul_video_jb_delay_per_frame);
[F_dl_video_jb, X_dl_video_jb] = compute_cdf(dl_video_jb_delay_per_frame);

% Compute CDFs for audio
[F_ul_audio_jb, X_ul_audio_jb] = compute_cdf(ul_audio_jb_delay_per_frame);
[F_dl_audio_jb, X_dl_audio_jb] = compute_cdf(dl_audio_jb_delay_per_frame);

% Plot CDFs for video (solid lines)
plot(X_ul_video_jb, F_ul_video_jb, 'b-', 'LineWidth', 4);
plot(X_dl_video_jb, F_dl_video_jb, 'r-', 'LineWidth', 4);

% Plot CDFs for audio (dashed lines)
plot(X_ul_audio_jb, F_ul_audio_jb, 'b-.', 'LineWidth', 4);
plot(X_dl_audio_jb, F_dl_audio_jb, 'r-.', 'LineWidth', 4);

% Add labels and legend
xlabel('Jitter Buffer Delay (ms)');
xlim(xlim_jb);
ylabel('CDF');
yticks(0:0.25:1);
% No title
legend('UL Video', 'DL Video', 'UL Audio', 'DL Audio', 'Location', 'southeast', 'FontSize', 22);
set(gca, 'FontSize', 32);
grid on;
hold off;


%% Function to compute CDF
function [F, X] = compute_cdf(data)
    % Remove NaN and Inf values
    data = data(~isnan(data) & ~isinf(data));
    % Sort data
    data_sorted = sort(data);
    % Compute empirical CDF
    n = length(data_sorted);
    F = (1:n)' / n;
    X = data_sorted;
end