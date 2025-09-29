#!/usr/bin/env python3

import re
import sys

if len(sys.argv) != 2:
    print("usage: python parse_rx_frame_log.py <filename>")
    sys.exit(1)

with open(sys.argv[1]) as f:
    lines = f.readlines()

print('frame_index,ts_ms')

for line in lines:
    
    match_index_time = re.search(r'n:\s*(\d+).+absolute_time:([\d\.]+)', line)
    
    if match_index_time and len(match_index_time.groups()) == 2:
        print(f'{match_index_time.group(1)},{match_index_time.group(2)}')
