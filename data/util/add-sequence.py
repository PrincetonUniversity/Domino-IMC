#!/usr/bin/env python3

import csv
import sys

if len(sys.argv) != 3:
    print("usage: %s IN.csv OUT.csv" % sys.argv[0], file=sys.stderr)
    exit(1)

in_file = open(sys.argv[1], newline='')
in_csv = csv.reader(in_file, delimiter=',', quotechar='"')

out_file = open(sys.argv[2], mode='w')
out_csv = csv.writer(out_file, delimiter=',')

highest_seq = {}
row_count = 0
new_seq = 0

for row in in_csv:

    row_count += 1

    if row_count == 1:
        out_csv.writerow(row + ['seq'])
        continue
    

    stream_key = f'{row[4]}/{row[5]}'
    rtp_seq = int(row[6])

    if stream_key not in highest_seq:
        highest_seq[stream_key] = rtp_seq - 1

    seq_incr = rtp_seq - highest_seq[stream_key]

    # handle rtp sequence wrap-around
    if seq_incr < -10000:
        seq_incr = 1

    highest_seq[stream_key] = rtp_seq if rtp_seq > highest_seq[stream_key] else highest_seq[stream_key]
    new_seq += seq_incr

    # write to csv:
    out_csv.writerow(row + [new_seq])