%% Data preparation
clear;

% Define parameters
expCode = '0318_4';

% Read CSV files, skipping the first row
sfu_filename = ['../data/data_exp' expCode '/sfu_rtp.csv'];
packets_sfu = readmatrix(sfu_filename, 'Range', 2);

ue_filename = ['../data/data_exp' expCode '/ue_rtp.csv'];
packets_ue = readmatrix(ue_filename, 'Range', 2);

enb_filename = ['../data/data_exp' expCode '/enb_rtp.csv'];
packets_enb = readmatrix(enb_filename, 'Range', 2);

offset = max([packets_ue(1, 1)*1000, packets_enb(1, 1)*1000, packets_sfu(1, 1)*1000]);

%% Data processing
[~, packets_ue_ul] = splitRTP(packets_ue);
[~, packets_enb_ul] = splitRTP(packets_enb);
[~, packets_sfu_ul] = splitRTP(packets_sfu);

% Initialize the merged packet data
packets_merge = [];

% Headers for the new CSV file
headers = {'rtp_ssrc', 'rtp_pt', 'rtp_seq', 'rtp_ts', 'frame_len', 'media_len', 'rtp_tw_seq', 'ts_ms_ue', 'ts_ms_enb', 'ts_ms_sfu', 'one_way_delay_ms', offset};

% Process packets
packets_merge = processPackets(packets_ue_ul, packets_enb_ul, packets_sfu_ul, offset);

% Write the headers and data to a new CSV file
output_filename = ['../data/data_exp' expCode '/rtp_' expCode '.csv'];
writecell(headers, output_filename);
writematrix(packets_merge, output_filename, 'WriteMode', 'append');

%% Helper Functions
function [packets_dl, packets_ul] = splitRTP(packets)
    % splitting RTP packets (in case downlink traffic exists)
    packets_dl = []; 
    packets_ul = packets; % All packets are uplink for now
end

function packets_merge = processPackets(packets_ue_ul, packets_enb_ul, packets_sfu_ul, offset)
    packets_merge = [];
    ueStartIdx = 1;
    enbStartIdx = 1;
    
    for j = 1:size(packets_sfu_ul, 1)
        if ~isnan(packets_sfu_ul(j, 14)) % Column 14 is RTP sequence number
            rtp_seq = packets_sfu_ul(j, 14);
            sfu_ts = packets_sfu_ul(j, 1)*1000 + packets_sfu_ul(j, 2)/1000 - offset;
            
            [ueIdx, ue_ts, packets_ue_data] = findMatchingPacket(packets_ue_ul, rtp_seq, ueStartIdx, offset);
            if ueIdx ~= -1
                ueStartIdx = ueIdx + 1; % Move to the next index for future searches
                
                [enbIdx, enb_ts] = findMatchingPacket(packets_enb_ul, rtp_seq, enbStartIdx, offset);
                if enbIdx ~= -1
                    enbStartIdx = enbIdx + 1;
                    
                    packets_merge = [packets_merge; [packets_ue_data, rtp_seq, ue_ts, enb_ts, sfu_ts, sfu_ts - ue_ts]];
                end
            end
        end
    end
end

function [idx, ts, packets_ue_data] = findMatchingPacket(packets, rtp_seq, startIdx, offset)
    idx = -1;
    ts = NaN;
    packets_ue_data = [];
    for i = startIdx:size(packets, 1)
        if packets(i, 14) == rtp_seq
            idx = i;
            ts = packets(i, 1)*1000 + packets(i, 2)/1000 - offset;
            packets_ue_data = packets(i, 16:21); % Extracting relevant data for merging
            break;
        end
    end
end
