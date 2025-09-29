import struct
import sys
from collections import defaultdict

def analyze_ivf(file_path):
    with open(file_path, 'rb') as f:
        # Read IVF header
        signature = f.read(4)
        version = struct.unpack('<H', f.read(2))[0]
        header_size = struct.unpack('<H', f.read(2))[0]
        fourcc = f.read(4)
        width = struct.unpack('<H', f.read(2))[0]
        height = struct.unpack('<H', f.read(2))[0]
        timescale = struct.unpack('<I', f.read(4))[0]
        frame_rate = struct.unpack('<I', f.read(4))[0]
        frame_count = struct.unpack('<I', f.read(4))[0]
        f.read(4)  # Skip reserved

        print(f"Signature: {signature}")
        print(f"Version: {version}")
        print(f"Header size: {header_size}")
        print(f"FourCC: {fourcc}")
        print(f"Width: {width}")
        print(f"Height: {height}")
        print(f"Timescale: {timescale}")
        print(f"Frame rate: {frame_rate}")
        print(f"Frame count: {frame_count}")

        if signature != b'DKIF':
            print("WARNING: Invalid file signature")
        if header_size != 32:
            print("WARNING: Unexpected header size")
        if timescale != 90000:
            print("WARNING: Unexpected timescale (expected 90000)")
        if frame_rate == 0:
            print("WARNING: Frame rate is 0")

        # Read frame data
        frame_number = 0
        file_position = 32  # Start after the header
        prev_timestamp = None
        timestamp_diffs = []
        frame_sizes = []
        timestamp_counts = defaultdict(int)

        while True:
            f.seek(file_position)
            frame_header = f.read(12)
            if len(frame_header) < 12:
                break

            frame_size, timestamp = struct.unpack('<I8s', frame_header)
            timestamp = int.from_bytes(timestamp, 'little')

            frame_sizes.append(frame_size)
            timestamp_counts[timestamp] += 1

            if prev_timestamp is not None:
                timestamp_diff = timestamp - prev_timestamp
                timestamp_diffs.append(timestamp_diff)
                if timestamp_diff < 0:
                    print(f"WARNING: Negative timestamp difference at frame {frame_number}")
                elif timestamp_diff == 0:
                    print(f"WARNING: Zero timestamp difference at frame {frame_number}")

            prev_timestamp = timestamp

            # Read a small part of the frame data
            frame_data = f.read(min(16, frame_size))
            
            file_position += 12 + frame_size
            frame_number += 1

        print(f"\nTotal frames: {frame_number}")
        print(f"File size: {file_position} bytes")

        if frame_number != frame_count and frame_count != 0:
            print(f"WARNING: Actual frame count ({frame_number}) doesn't match header frame count ({frame_count})")

        if timestamp_diffs:
            avg_timestamp_diff = sum(timestamp_diffs) / len(timestamp_diffs)
            print(f"Average timestamp difference: {avg_timestamp_diff}")
            print(f"Min timestamp difference: {min(timestamp_diffs)}")
            print(f"Max timestamp difference: {max(timestamp_diffs)}")

        print(f"Average frame size: {sum(frame_sizes) / len(frame_sizes):.2f} bytes")
        print(f"Min frame size: {min(frame_sizes)} bytes")
        print(f"Max frame size: {max(frame_sizes)} bytes")

        duplicate_timestamps = [ts for ts, count in timestamp_counts.items() if count > 1]
        if duplicate_timestamps:
            print(f"WARNING: Found {len(duplicate_timestamps)} duplicate timestamps")

        if frame_rate > 0:
            expected_duration = (frame_number * 90000) / frame_rate
            actual_duration = prev_timestamp
            print(f"Expected duration based on frame rate: {expected_duration}")
            print(f"Actual duration based on last timestamp: {actual_duration}")
            if abs(expected_duration - actual_duration) > 90000:  # More than 1 second difference
                print("WARNING: Significant difference between expected and actual duration")

        # Histogram of timestamp differences
        if timestamp_diffs:
            print("\nTimestamp difference histogram:")
            hist = defaultdict(int)
            for diff in timestamp_diffs:
                hist[diff // 1000] += 1  # Group by milliseconds
            for ms, count in sorted(hist.items()):
                print(f"{ms} ms: {'#' * (count * 50 // len(timestamp_diffs))}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python ivf_analyzer.py <path_to_ivf_file>")
        sys.exit(1)
    
    analyze_ivf(sys.argv[1])