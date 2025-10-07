clear;

% Define parameters
expCode = '0616_1';
start_time = 1717968811672-10000; % from UE pcap file, 10s ahead of time
end_time = 1717969415072;
link_direction = 'U';
delay_baseline = 15; % ms
n_prb = 90;
bin_size = 1000; % ms

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

% Write the first line
init_cap = calc_4g_tbs(24,n_prb,link_direction) * 0.001 / 5; % Mbps, only 1 subframe per 5 ms
fprintf(fileID, '%s,%f,%d\n', num2str(0), init_cap, delay_baseline);

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
    current_bin_cap = current_bin_cap + calc_4g_tbs(dci_log(i).mcs, n_prb, link_direction);
end

% Write the last bin's data to the file (if any data was added)
if current_bin_cap > 0
    fprintf(fileID, '%s,%f,%d\n', num2str(current_bin_start-start_time), current_bin_cap/bin_size*0.001, delay_baseline);
end

% Close the file
fclose(fileID);
