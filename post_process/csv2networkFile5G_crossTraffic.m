clear;
%% Define parameters
% change every time
expCode = '0620_2';
start_time = 1718931355849 - 5000; % from UE pcap file, 5s ahead of time
end_time = 1718931959563 + 5000;
target_rnti = 17022;
n_ue = 3;

% change if necessary
delay_baseline = 15; % ms
n_prb = 51;
bin_size = 1000; % ms

%% Data preparation
% Read PHY data
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

% Initialize variables
current_bin_start = start_time;
current_bin_end = current_bin_start + bin_size;
current_bin_cap = 0;

% Convert dci_log to a table for easier processing
dci_table = struct2table(dci_log);

% Unwrap sfi values to avoid wrapping issues
unwrapped_sfi = dci_table.sfi;
for i = 2:length(unwrapped_sfi)
    if unwrapped_sfi(i) < unwrapped_sfi(i - 1)
        unwrapped_sfi(i:end) = unwrapped_sfi(i:end) + 1024;
    end
end
dci_table.sfi_unwrapped = unwrapped_sfi;

%% Main loop
% Read the dci_log line by line
i = 1;
while i <= height(dci_table)
    
    % Get the timestamp for the current slot
    slot_timestamp = dci_table.ts(i);
    
    % Check if the timestamp is within range
    if slot_timestamp <= start_time || slot_timestamp > end_time
        i = i + 1;
        continue; % Skip this slot
    end

    % Get the current slot value
    current_slot_value = dci_table.sfi_unwrapped(i) * 20 + dci_table.slot_i(i);

    % Initialize variables for the current slot
    slot_prb_target = 0;
    slot_prb_nontarget = 0;
    slot_tbs_target = 0;
    
    % Get all DCI logs for the current slot
    while i <= height(dci_table) && (dci_table.sfi_unwrapped(i) * 20 + dci_table.slot_i(i)) == current_slot_value
        % Sum PRB allocations and TBS for each RNTI in this slot
        if dci_table.rnti(i) == target_rnti
            slot_prb_target = slot_prb_target + dci_table.prb(i);
            slot_tbs_target = slot_tbs_target + dci_table.tbs(i);
        else
            slot_prb_nontarget = slot_prb_nontarget + dci_table.prb(i);
        end
        i = i + 1;
    end
    
    % Calculate available PRBs for the target UE
    available_prb = slot_prb_target + (n_prb - slot_prb_target - slot_prb_nontarget) / n_ue;
    
    % Calculate the number of bits for the target UE in this slot
    if slot_prb_target > 0
        slot_bits = slot_tbs_target / slot_prb_target * available_prb;
    else
        slot_bits = 0;
    end
    
    % Check if the timestamp is outside the current bin
    if slot_timestamp > current_bin_end
        % Write the current bin's data to the file
        fprintf(fileID, '%s,%f,%d\n', num2str(current_bin_start - start_time), current_bin_cap / bin_size * 0.001, delay_baseline);
        
        % Move to the next bin
        current_bin_start = current_bin_end;
        current_bin_end = current_bin_start + bin_size;
        current_bin_cap = 0; % Reset the bin capacity
    end
    
    % Add the slot capacity to the current bin's capacity
    current_bin_cap = current_bin_cap + slot_bits;
end

% Write the last bin's data to the file (if any data was added)
if current_bin_cap > 0
    fprintf(fileID, '%s,%f,%d\n', num2str(current_bin_start - start_time), current_bin_cap / bin_size * 0.001, delay_baseline);
end

% Close the file
fclose(fileID);
