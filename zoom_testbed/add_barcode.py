import random
import cv2
import numpy as np
from PIL import Image
from pylibdmtx.pylibdmtx import encode, decode
import argparse
import csv
import os
import ffmpeg

def generate_barcode_value(num_frames):
    if num_frames > 0xFFFF:
        raise ValueError("num_frames must be less than or equal to 65536 for unique 16-bit values")
    unique_values = random.sample(range(0x10000), num_frames)
    return unique_values

def generate_barcode(number):
    encoded = encode(str(number).encode('utf-8'), size='10x10')
    barcode_img = Image.frombytes('RGB', (encoded.width, encoded.height), encoded.pixels)
    barcode_array = np.array(barcode_img)
    # trimmed_barcode_array = barcode_array[4:-4, 4:-4]
    trimmed_barcode_img = Image.fromarray(barcode_array)
    return trimmed_barcode_img

def crop_frame(frame, crop_fraction_width=1/20, crop_fraction_height=1/20):
    frame_height, frame_width = frame.shape[:2]
    crop_x = int(frame_width * crop_fraction_width)
    crop_y = int(frame_height * crop_fraction_height)
    cropped_frame = frame[crop_y:frame_height-crop_y, crop_x:frame_width-crop_x]
    return cropped_frame, crop_x, crop_y

def insert_barcode_to_frame(frame, barcode_img, scale=3.6, threshold=128):
    frame_height, frame_width = frame.shape[:2]
    barcode_width, barcode_height = barcode_img.size
    new_width = int(frame_width * (scale / 100))
    new_height = int(barcode_height * (new_width / barcode_width))
    barcode_img = barcode_img.resize((new_width, new_height), Image.NEAREST)
    # Convert the resized image to grayscale
    barcode_img = barcode_img.convert('L')
    # Apply the threshold to convert to black and white
    barcode_img = barcode_img.point(lambda p: 255 if p > threshold else 0)
    barcode_array = np.array(barcode_img.convert('RGB'))
    frame[0:new_height, frame_width-new_width:frame_width] = barcode_array
    return frame

def pad_frame_to_original(frame, original_width, original_height, crop_x, crop_y):
    padded_frame = cv2.copyMakeBorder(
        frame, crop_y, crop_y, crop_x, crop_x, cv2.BORDER_CONSTANT, value=[0, 0, 0]
    )
    return padded_frame

def process_video(input_video_path, output_video_path, scale=3.6, crop_fraction_width=1/20, crop_fraction_height=1/20):
    cap = cv2.VideoCapture(input_video_path)
    frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = int(cap.get(cv2.CAP_PROP_FPS))
    num_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    frame_indices = generate_barcode_value(num_frames + 1)
    frames = []

    black_frame = np.zeros((frame_height, frame_width, 3), dtype=np.uint8)
    cropped_black_frame, crop_x, crop_y = crop_frame(black_frame, crop_fraction_width, crop_fraction_height)
    barcode_img = generate_barcode(frame_indices[0])
    black_frame_with_barcode = insert_barcode_to_frame(cropped_black_frame, barcode_img, scale)
    padded_black_frame = pad_frame_to_original(black_frame_with_barcode, frame_width, frame_height, crop_x, crop_y)
    
    # Save frame 0 for debugging
    # cv2.imwrite('debug_frame_0.png', cv2.cvtColor(padded_black_frame, cv2.COLOR_RGB2BGR))
    
    frames.append(cv2.cvtColor(padded_black_frame, cv2.COLOR_BGR2RGB))

    frame_idx = 1
    while(cap.isOpened()):
        ret, frame = cap.read()
        if not ret:
            break

        cropped_frame, crop_x, crop_y = crop_frame(frame, crop_fraction_width, crop_fraction_height)
        barcode_img = generate_barcode(frame_indices[frame_idx])
        frame_with_barcode = insert_barcode_to_frame(cropped_frame, barcode_img, scale)
        padded_frame = pad_frame_to_original(frame_with_barcode, frame_width, frame_height, crop_x, crop_y)
        frames.append(cv2.cvtColor(padded_frame, cv2.COLOR_BGR2RGB))
        frame_idx += 1

    cap.release()

    audio_path = os.path.splitext(output_video_path)[0] + '.aac'
    ffmpeg.input(input_video_path).output(audio_path, codec='copy').run()

    temp_video_path = os.path.splitext(output_video_path)[0] + '_temp.mp4'
    process = (
        ffmpeg
        .input('pipe:', format='rawvideo', pix_fmt='rgb24', s=f'{frame_width}x{frame_height}', framerate=fps)
        .output(temp_video_path, pix_fmt='yuv422p10le', vcodec='libx264', **{'profile:v': 'high422'}, video_bitrate='100039k', r=fps) # 1080p '141494k', 720p '100039k'
        .overwrite_output()
        .run_async(pipe_stdin=True)
    )
    
    try:
        for frame in frames:
            process.stdin.write(frame.astype(np.uint8).tobytes())
    except BrokenPipeError:
        print("Error: Broken pipe. The ffmpeg process was interrupted.")
    finally:
        process.stdin.close()
        process.wait()

    video = ffmpeg.input(temp_video_path)
    audio = ffmpeg.input(audio_path)
    combined_output_path = output_video_path
    ffmpeg.output(video, audio, combined_output_path, codec='copy').overwrite_output().run()

    os.remove(audio_path)
    os.remove(temp_video_path)

    return frame_indices

def save_random_numbers_to_csv(frame_indices, output_video_path):
    csv_filename = 'barcode_list.csv'
    with open(csv_filename, mode='w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(["Frame Index", "Barcode Value"])
        for index, number in enumerate(frame_indices):
            writer.writerow([index, number])

def main():
    parser = argparse.ArgumentParser(description="Add barcodes to video frames.")
    parser.add_argument("-i", "--input", required=True, help="Path to the input video file")
    parser.add_argument("-o", "--output", required=True, help="Path to the output video file")
    parser.add_argument("--crop_fraction_width", type=float, default=1/20, help="Fraction of width to crop from each side")
    parser.add_argument("--crop_fraction_height", type=float, default=1/20, help="Fraction of height to crop from each side")
    args = parser.parse_args()

    input_video_path = args.input
    output_video_path = args.output

    scale = 20.0
    frame_indices = process_video(input_video_path, output_video_path, scale, args.crop_fraction_width, args.crop_fraction_height)
    save_random_numbers_to_csv(frame_indices, output_video_path)

if __name__ == "__main__":
    main()
