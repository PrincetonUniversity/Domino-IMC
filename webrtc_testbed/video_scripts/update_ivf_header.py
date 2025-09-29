import sys
import struct

def update_ivf_header(filename):
    with open(filename, 'rb+') as f:
        # Read the IVF header
        header = f.read(32)
        
        # Verify it's an IVF file
        if header[:4] != b'DKIF':
            print(f"Error: {filename} is not a valid IVF file")
            return

        # Read current values
        width, height = struct.unpack('<HH', header[12:16])
        time_base_denominator, time_base_numerator = struct.unpack('<II', header[16:24])
        current_num_frames = struct.unpack('<I', header[24:28])[0]

        print(f"Current header info:")
        print(f"Width: {width}, Height: {height}")
        print(f"Time base: {time_base_numerator}/{time_base_denominator}")
        print(f"Number of frames: {current_num_frames}")

        # Count frames
        frame_count = 0
        while True:
            frame_header = f.read(12)
            if len(frame_header) < 12:
                break  # End of file
            frame_size = struct.unpack('<I', frame_header[:4])[0]
            frame_count += 1
            f.seek(frame_size, 1)  # Skip frame data

        print(f"\nActual number of frames: {frame_count}")

        # Update header with correct frame count
        f.seek(24)
        f.write(struct.pack('<I', frame_count))

        print(f"Updated header with new frame count: {frame_count}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <ivf_filename>")
    else:
        update_ivf_header(sys.argv[1])