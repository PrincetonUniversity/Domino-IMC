%% Data preparation

clear;

% Define parameters
expCode = '0615';

% Read CSV files, skipping the first row
ue_filename = ['../data/data_exp' expCode '/ue_icmp.csv'];
packets_ue = readmatrix(ue_filename, 'Range', 2);

sv_filename = ['../data/data_exp' expCode '/server_icmp.csv'];
packets_sv = readmatrix(sv_filename, 'Range', 2);

offset = packets_ue(1, 3)*1000;

%% Data processing

[packets_ue_ul] = splitICMP(packets_ue);
[packets_sv_ul] = splitICMP(packets_sv);

% Initialize the merged packet data
packets_merge = [];

% Headers for the new CSV file
headers = {'icmp_seq', 'pkt_size', 'ts_ms_ue', 'ts_ms_server', 'one_way_delay_ms', 'type', offset};

% Process packets
packets_merge = processPackets(packets_ue_ul, packets_sv_ul, offset);

% Write the headers and data to a new CSV file
output_filename = ['../data/data_exp' expCode '/icmp_' expCode '.csv'];
writecell(headers, output_filename);
writematrix(packets_merge, output_filename, 'WriteMode', 'append');

%% Helper Functions

function [packets_ul] = splitICMP(packets)
    packets_ul = packets;
end

function packets_merge = processPackets(packets_ue_ul, packets_sv_ul, offset)
    packets_merge = [];
    pktIdx = 0;
    
    for j = 1:size(packets_ue_ul, 1)
        if ~isnan(packets_ue_ul(j, 1)) && packets_ue_ul(j, 4)==8
            pktIdx = pktIdx+1;
            icmp_seq = pktIdx;
            pkt_size = packets_ue_ul(j, 2); % bytes
            ue_ts = packets_ue_ul(j, 3)*1000 - offset; % in ms
            sv_ts = packets_sv_ul(j, 3)*1000 - offset;
            type = packets_ue_ul(j,4);

            packets_merge = [packets_merge; [icmp_seq, pkt_size, ue_ts, sv_ts, sv_ts - ue_ts, type]];
        end
    end
end

function [idx, ts] = findMatchingPacket(packets, icmp_seq, startIdx, offset)
    idx = -1;
    ts = NaN;
    for i = startIdx:size(packets, 1)
        if packets(i, 9) == icmp_seq
            idx = i;
            ts = packets(i, 1)*1000 + packets(i, 2)/1000 - offset;
            break;
        end
    end
end