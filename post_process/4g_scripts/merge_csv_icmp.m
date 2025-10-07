%% Data preparation
clear;

% Define parameters
expCode = '0227';

% Read CSV files, skipping the first row
ue_filename = ['../data/data_exp' expCode '/ue_icmp.csv'];
packets_ue = readmatrix(ue_filename, 'Range', 2);

enb_filename = ['../data/data_exp' expCode '/enb_icmp.csv'];
packets_enb = readmatrix(enb_filename, 'Range', 2);

sfu_filename = ['../data/data_exp' expCode '/sfu_icmp.csv'];
packets_sfu = readmatrix(sfu_filename, 'Range', 2);

offset = packets_ue(1, 1)*1000 + packets_ue(1, 2)/1000;

%% Data processing
[~, packets_ue_ul] = splitICMP(packets_ue);
[~, packets_enb_ul] = splitICMP(packets_enb);
[~, packets_sfu_ul] = splitICMP(packets_sfu);

% Initialize the merged packet data
packets_merge = [];

% Headers for the new CSV file
headers = {'icmp_seq', 'ts_ms_ue', 'ts_ms_enb', 'ts_ms_sfu', 'one_way_delay_ms', offset};

% Process packets
packets_merge = processPackets(packets_ue_ul, packets_enb_ul, packets_sfu_ul, offset);

% Write the headers and data to a new CSV file
output_filename = ['../data/data_exp' expCode '/icmp_' expCode '.csv'];
writecell(headers, output_filename);
writematrix(packets_merge, output_filename, 'WriteMode', 'append');

%% Helper Functions
function [packets_dl, packets_ul] = splitICMP(packets)
    packets_dl = packets(packets(:, 6) == 0, :);
    packets_ul = packets(packets(:, 6) == 8, :);
end

function packets_merge = processPackets(packets_ue_ul, packets_enb_ul, packets_sfu_ul, offset)
    packets_merge = [];
    ueStartIdx = 1;
    enbStartIdx = 1;
    
    for j = 1:size(packets_sfu_ul, 1)
        if ~isnan(packets_sfu_ul(j, 9))
            icmp_seq = packets_sfu_ul(j, 9);
            sfu_ts = packets_sfu_ul(j, 1)*1000 + packets_sfu_ul(j, 2)/1000 - offset;
            
            [ueIdx, ue_ts] = findMatchingPacket(packets_ue_ul, icmp_seq, ueStartIdx, offset);
            if ueIdx ~= -1
                ueStartIdx = ueIdx + 1; % Move to the next index for future searches
                
                [enbIdx, enb_ts] = findMatchingPacket(packets_enb_ul, icmp_seq, enbStartIdx, offset);
                if enbIdx ~= -1
                    enbStartIdx = enbIdx + 1;
                    
                    packets_merge = [packets_merge; [icmp_seq, ue_ts, enb_ts, sfu_ts, sfu_ts - ue_ts]];
                end
            end
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
