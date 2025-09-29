import cv2
import numpy as np
import subprocess
import sys
import logging
import os

logging.basicConfig(level=logging.INFO)

def read_metadata(metadata_file):
    metadata = []
    with open(metadata_file, 'r') as f:
        for line in f:
            if line.startswith('width:'):
                width, height = line.strip().split(',')
                width = int(width.split(':')[1])
                height = int(height.split(':')[1])
                metadata.append((0, width, height))
            else:
                timestamp, width, height = map(int, line.strip().split(','))
                metadata.append((timestamp, width, height))
    return metadata

def create_ffmpeg_process(width, height, target_resolution, output_file, segment_number, fps=30):
    target_width, target_height = map(int, target_resolution.split('x'))
    segment_file = f"{output_file}_segment_{segment_number}.mp4"
    ffmpeg_cmd = [
        'ffmpeg',
        '-f', 'rawvideo',
        '-pixel_format', 'yuv420p',
        '-video_size', f'{width}x{height}',
        '-framerate', str(fps),
        '-i', '-',
        '-c:v', 'libx264',
        '-preset', 'medium',
        '-crf', '23',
        '-vf', f'scale={target_width}:{target_height}',
        '-y',
        segment_file
    ]
    return subprocess.Popen(ffmpeg_cmd, stdin=subprocess.PIPE), segment_file

def convert_yuv_to_mp4(yuv_file, metadata_file, output_file, target_resolution, fps=30):
    metadata = read_metadata(metadata_file)
    
    with open(yuv_file, 'rb') as f:
        yuv_data = f.read()

    process = None
    offset = 0
    current_metadata_index = 0
    segment_number = 0
    segment_files = []
    current_width, current_height = metadata[0][1], metadata[0][2]

    try:
        while offset < len(yuv_data):
            timestamp, width, height = metadata[current_metadata_index]
            frame_size = width * height * 3 // 2  # YUV420 format

            if offset + frame_size > len(yuv_data):
                break

            if width != current_width or height != current_height or process is None:
                if process is not None:
                    process.stdin.close()
                    process.wait()
                    logging.info(f"Finished segment {segment_number} at {current_width}x{current_height}")
                
                current_width, current_height = width, height
                process, segment_file = create_ffmpeg_process(width, height, target_resolution, output_file, segment_number, fps)
                segment_files.append(segment_file)
                segment_number += 1

            frame_data = yuv_data[offset:offset + frame_size]
            process.stdin.write(frame_data)
            offset += frame_size

            # Move to next metadata entry if available
            if current_metadata_index + 1 < len(metadata):
                current_metadata_index += 1

    except Exception as e:
        logging.error(f"An error occurred: {str(e)}")
    finally:
        if process is not None:
            process.stdin.close()
            process.wait()
            logging.info(f"Finished final segment at {current_width}x{current_height}")

    # Concatenate all segments
    if len(segment_files) > 1:
        with open('segment_list.txt', 'w') as f:
            for segment in segment_files:
                f.write(f"file '{segment}'\n")
        
        concat_cmd = [
            'ffmpeg',
            '-f', 'concat',
            '-safe', '0',
            '-i', 'segment_list.txt',
            '-c', 'copy',
            '-y',
            output_file
        ]
        subprocess.run(concat_cmd, check=True)
        
        # Clean up segment files
        for segment in segment_files:
            os.remove(segment)
        os.remove('segment_list.txt')
    else:
        os.rename(segment_files[0], output_file)

    logging.info(f"Conversion complete. Output file: {output_file}")

if __name__ == "__main__":
    if len(sys.argv) != 5:
        print("Usage: python3 convert_yuv_to_mp4.py <input_yuv> <input_meta> <output_mp4> <target_resolution>")
        sys.exit(1)

    yuv_file = sys.argv[1]
    metadata_file = sys.argv[2]
    output_file = sys.argv[3]
    target_resolution = sys.argv[4]

    convert_yuv_to_mp4(yuv_file, metadata_file, output_file, target_resolution)