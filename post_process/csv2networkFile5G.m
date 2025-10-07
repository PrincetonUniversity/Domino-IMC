clear;

% Define parameters
expCode = '0625_1';
start_time = 1719341082980-5000; % from UE pcap file, 10s ahead of time
end_time = 1719342286909+5000;
delay_baseline = 15; % ms
n_prb = 51;
bin_size = 1000; % ms
ping_cap = 800*8*50; % in unit of bits/second

% read PHY data
readPath = ['../zoom_data/data_exp' expCode '/UL_tbs_delay_' expCode '.mat'];
load(readPath);

% Open a file for writing
writePath = ['../zoom_data/data_exp' expCode '/network_cap_' expCode '.csv'];
fileID = fopen(writePath, 'w');

% Check if the file was opened successfully
if fileID == -1
    error('Failed to open the file.');
end

% Write header to the file
fprintf(fileID, 'timestamp,capacity,delay\n');

% % Write the first line
% init_cap = calc_5g_tbs(n_prb, 27, 1, 12, 2)/0.0025/1e6; % Mbps, only 1 subframe per 5 ms
% fprintf(fileID, '%s,%f,%d\n', num2str(0), init_cap, delay_baseline);

% Initialize variables
current_bin_start = start_time;
current_bin_end = current_bin_start + bin_size;
current_bin_cap = 0;

% Loop through the arrays and process the data
for i = 1:length(dci_log)
    % Check if the timestamp is within range
    if dci_log(i).ts <= start_time || dci_log(i).ts > end_time
        continue; % Skip this row
    end
    
    % Check if the timestamp is outside the current bin
    if dci_log(i).ts > current_bin_end
        % Write the current bin's data to the file
        fprintf(fileID, '%s,%f,%d\n', num2str(current_bin_start-start_time), current_bin_cap/bin_size*0.001, delay_baseline);
        
        % Move to the next bin
        current_bin_start = current_bin_end;
        current_bin_end = current_bin_start + bin_size;
        current_bin_cap = 0; % Reset the bin capacity
    end
    
    % Calculate the capacity for the current entry and add to the current bin's capacity
    if dci_log(i).n_tx == 0
        temp_tbs = 0;
    else
        temp_tbs = dci_log(i).tbs;
    end
    current_bin_cap = current_bin_cap + temp_tbs;
end

% Write the last bin's data to the file (if any data was added)
if current_bin_cap > 0
    fprintf(fileID, '%s,%f,%d\n', num2str(current_bin_start-start_time), current_bin_cap/bin_size*0.001, delay_baseline);
end

% Close the file
fclose(fileID);
