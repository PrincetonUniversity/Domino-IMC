ts_phy1 = ts_phy';
delay_physync1 = delay_physync';
tbs_physync1 = tbs_physync';

% Combine a and b into a single matrix
data = [ts_phy, delay_physync, tbs_physync];

% Create a table with a and b as columns
dataTable = table(ts_phy1, delay_physync1, tbs_physync1, 'VariableNames', {'ts', 'delay', 'tbs'});

% Write the table to a CSV file with header
writetable(dataTable, 'rlc_dci.csv', 'Delimiter', ',');


%% save pkt data

% Create a table with a and b as columns
dataTable2 = table(ts_ue, ts_sfu, delay_sfu, framelen_pkt, 'VariableNames', {'ts_ue', 'ts_sink', 'delay', 'pkt_size'});

% Write the table to a CSV file with header
writetable(dataTable2, 'rlc_pkt.csv', 'Delimiter', ',');