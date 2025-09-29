import re
import csv

# Define the log file and output CSV file names
log_file = 'frame_log.txt'
csv_file = 'frame_log.csv'

# Regular expression pattern to match the log lines
log_pattern = re.compile(
    r'n:(\d+)\s+pts:(\d+)\s+pts_time:([\d.]+)\s+duration:(\d+)\s+duration_time:([\d.]+)\s+'
    r'fmt:(\S+)\s+cl:(\S+)\s+sar:(\d+)/(\d+)\s+s:(\d+)x(\d+)\s+i:(\S)\s+iskey:(\d)\s+type:(\S)\s+absolute_time:([\d.]+)ms'
)

# Read the log file and parse the lines
with open(log_file, 'r') as infile:
    lines = infile.readlines()

# Open the CSV file for writing
with open(csv_file, 'w', newline='') as outfile:
    csv_writer = csv.writer(outfile)
    # Write the header row
    csv_writer.writerow([
        'n', 'pts', 'pts_time', 'duration', 'duration_time',
        'fmt', 'cl', 'sar_num', 'sar_den', 'width', 'height',
        'i', 'iskey', 'type', 'absolute_time_ms'
    ])

    # Process each line and write to the CSV file
    for line in lines:
        match = log_pattern.search(line)
        if match:
            csv_writer.writerow(match.groups())

print(f'Log data has been written to {csv_file}')
