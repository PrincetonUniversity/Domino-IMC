%% Data preparation
clear;close all

% Define parameters
expCode = '0616_1';

% Load RNTIs of interest
fileName = ['../zoom_data/data_exp' expCode '/UL_rnti_' expCode '.mat'];
RNTIs = load(fileName);
RNTIs_of_interest = RNTIs.rntisAboveThreshold; 

% Read the original csv file: data
linktype = 'U';
filePath = ['../zoom_data/data_exp' expCode '/dci_log_3649440000_origin.csv']; % dci_raw_log_ul_freq_2602000000
data = readtable(filePath, 'FileType', 'text');

% Open the new csv file
output_filePath = ['../zoom_data/data_exp' expCode '/dci_log_3649440000.csv'];


% Filter rows based on dci_format and RNTIs of interest
data_filtered = data(strcmp(data.dci_format, '0_1') & ismember(data.rnti, RNTIs_of_interest), :);

% Calculate tbs_old
tbs_old = arrayfun(@(freq_len, mcs_idx, layers, time_len) calc_5g_tbs(freq_len, mcs_idx, layers, time_len, 1), ...
                   data_filtered.frequency_length, data_filtered.mcs_index, ...
                   data_filtered.nof_layers, data_filtered.time_length);

% Compare tbs_new with data.transport_block_size and print mismatches
% to debug use this code: disp(data_filtered(i, :));
mismatches = find(tbs_old ~= data_filtered.transport_block_size);
if ~isempty(mismatches)
    fprintf('Mismatch found at row indices:\n');
    fprintf('%d\n', mismatches);
else
    fprintf('No mismatches found.\n');
end

% Calculate tbs_new
tbs_new = arrayfun(@(freq_len, mcs_idx, time_len) calc_5g_tbs(freq_len, mcs_idx, 1, time_len, 2), ...
                   data_filtered.frequency_length, data_filtered.mcs_index, data_filtered.time_length);

% Replace data_filtered.transport_block_size with tbs_new
data_filtered.transport_block_size = tbs_new;

% Write the updated table into a csv file
writetable(data_filtered, output_filePath);