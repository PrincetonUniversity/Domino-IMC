clear;

% Define parameters
expCode = '0609_2';

% read PHY data
readPath = ['../zoom_data/data_exp' expCode '/UL_tbs_delay_' expCode '.mat'];
load(readPath);

% Open a file for writing
writePath = ['../zoom_data/data_exp' expCode '/UL_tbs_delay_' expCode '.csv'];
fileID = fopen(writePath, 'w');

% Check if the file was opened successfully
if fileID == -1
    error('Failed to open the file.');
end

% Write header to the file
fprintf(fileID, 'Timestamp,TBS,PHY_ReTX_Delay(ms),RLC_failure,RLC_initTX_timestamp,mcs,prb\n');

format long g
% Loop through the arrays and write the data
for i = 1:length(dci_log)
    % fprintf(fileID, '%ld,%d,%d,%d,%ld\n', dci_log(i).ts, dci_log(i).tbs, dci_log(i).delay, dci_log(i).RLC_fail, dci_log(i).RLC_init_tx);    
    ts_str = num2str(dci_log(i).ts);
    RLC_init_tx_str = num2str(dci_log(i).RLC_init_tx);
    fprintf(fileID, '%s,%d,%d,%d,%s,%d,%d\n', ts_str, dci_log(i).tbs, dci_log(i).delay, dci_log(i).RLC_fail, RLC_init_tx_str, dci_log(i).mcs, dci_log(i).prb);
end

% Close the file
fclose(fileID);

