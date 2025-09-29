import cv2
import numpy as np
import pandas as pd
from pylibdmtx.pylibdmtx import decode
from skimage.metrics import structural_similarity as ssim
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
import argparse

# Constants
CROP_FRACTION_WIDTH = 1/20  # Example value, adjust as needed
CROP_FRACTION_HEIGHT = 1/20  # Example value, adjust as needed
SCALE = 20
DARK_THRESHOLD = 30 
BATCH_SIZE = 1000  # Number of frames to process in each batch

def crop_frame(frame, crop_fraction_width, crop_fraction_height):
    h, w = frame.shape[:2]
    cropped_frame = frame[
        int(crop_fraction_height * h):int((1 - crop_fraction_height) * h),
        int(crop_fraction_width * w):int((1 - crop_fraction_width) * w)
    ]
    return cropped_frame

def calculate_ssim_opencv(img1, img2):
    # Ensure images are in the same color space
    quality_ssim = cv2.quality.QualitySSIM_create(img1)
    ssim_index = quality_ssim.compute(img2)
    if len(ssim_index) == 3:  # For RGB images
        return np.mean(ssim_index)
    return ssim_index[0]

def detect_and_crop_frame(frame, crop_fraction_width, crop_fraction_height, dark_threshold):
    h, w = frame.shape[:2]

    # Convert YUV to Y channel (grayscale equivalent)
    y_channel = frame[:, :, 0]

    # Calculate target width and height after cropping
    target_w = int(1280 * (1 - crop_fraction_width * 2))
    target_h = int(720 * (1 - crop_fraction_height * 2))

    # Crop left and right sides equally
    crop_w = int((w - target_w) / 2)
    frame_cropped_lr = frame[:, crop_w:w-crop_w]

    # Update y_channel after left and right crop
    y_channel_cropped_lr = y_channel[:, crop_w:w-crop_w]

    # Detect and crop all-dark rows from the top
    top_crop = 0
    threshold = int(0.90 * y_channel_cropped_lr.shape[1])
    for i in range(y_channel_cropped_lr.shape[0]):
        if np.sum(y_channel_cropped_lr[i, :] < dark_threshold) < threshold:
            top_crop = i
            break
    frame_cropped_tb = frame_cropped_lr[top_crop:, :]

    # Calculate bottom crop to achieve the target height
    crop_h = frame_cropped_tb.shape[0] - target_h
    if crop_h > 0:
        frame_final = frame_cropped_tb[:target_h, :]
    else:
        frame_final = frame_cropped_tb

    return frame_final

def preprocess_image(image):
    # Convert to grayscale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    # Apply Gaussian blur to reduce noise
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    # Apply threshold to get a binary image
    _, thresh = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)
    return thresh

def decode_barcode(frame, scale, shrink_factor=3):
    barcode_size = int(scale / 100 * frame.shape[1])
    top_right_corner = frame[:barcode_size, -barcode_size:]

    preprocessed_image = preprocess_image(top_right_corner)
    decoded_objects = decode(preprocessed_image, shrink=shrink_factor, threshold=10)
    for obj in decoded_objects:
        return obj.data.decode('utf-8')
    return None

def process_original_video(video_path, barcode_df):
    cap = cv2.VideoCapture(video_path)
    frames = []
    barcode_values = []
    
    frame_idx = 0
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break

        cropped_frame = crop_frame(frame, CROP_FRACTION_WIDTH, CROP_FRACTION_HEIGHT)
        barcode_value = decode_barcode(cropped_frame, SCALE)
        expected_barcode_value = str(barcode_df.iloc[frame_idx, 1])
        
        if barcode_value != expected_barcode_value:
            print(f"Error at frame {frame_idx}: expected {expected_barcode_value}, got {barcode_value}")
        
        frames.append(cropped_frame)
        barcode_values.append(barcode_value)
        frame_idx += 1
    
    cap.release()
    return frames, barcode_values

def calculate_ssim_for_frame_pair(cropped_frame, original_frame):
    return calculate_ssim_opencv(cropped_frame, original_frame)

def process_receiver_video(video_path, original_frames, original_barcode_values, output_dir='barcode_debug_images', num_debug_images=10):
    cap = cv2.VideoCapture(video_path)
    results = []

    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    debug_image_count = 0
    previous_original_idx = None
    loop_count = 0

    while cap.isOpened():
        frames_to_process = []
        for i in range(BATCH_SIZE):
            ret, frame = cap.read()
            if not ret:
                break

            frame_idx = loop_count * BATCH_SIZE + i  # Actively assign frame_idx based on loop count and BATCH_SIZE

            cropped_frame = detect_and_crop_frame(frame, CROP_FRACTION_WIDTH, CROP_FRACTION_HEIGHT, DARK_THRESHOLD)
            barcode_value = decode_barcode(cropped_frame, SCALE)

            if debug_image_count < num_debug_images:
                barcode_area = cropped_frame[:int(SCALE / 100 * cropped_frame.shape[1]), -int(SCALE / 100 * cropped_frame.shape[1]):]
                output_path = os.path.join(output_dir, f'barcode_frame_{frame_idx}.png')
                cv2.imwrite(output_path, barcode_area)
                debug_image_count += 1

            if barcode_value not in original_barcode_values:
                print(f"Frame: {frame_idx}, Barcode {barcode_value}, Shrink 3 not working!")
                barcode_value = decode_barcode(cropped_frame, SCALE, 1)
                if barcode_value not in original_barcode_values:
                    print(f"Frame: {frame_idx}, Barcode {barcode_value} not found in original video!")

            if barcode_value in original_barcode_values:
                original_idx = original_barcode_values.index(barcode_value)
                print(f"frame_index: {frame_idx}, Size of receiver frame: {cropped_frame.shape}")

                if original_idx == previous_original_idx:
                    ssim_value = -1
                    results.append([frame_idx, original_idx, barcode_value, ssim_value])
                else:
                    frames_to_process.append((frame_idx, cropped_frame, original_frames[original_idx], original_idx, barcode_value))
                    previous_original_idx = original_idx

        loop_count += 1  # Increment loop count after processing each batch

        if not frames_to_process:
            break

        # Calculate SSIM in parallel
        with ThreadPoolExecutor(max_workers=8) as executor:
            future_to_frame = {executor.submit(calculate_ssim_for_frame_pair, cropped_frame, original_frame): (frame_idx, original_idx, barcode_value) for frame_idx, cropped_frame, original_frame, original_idx, barcode_value in frames_to_process}

            for future in as_completed(future_to_frame):
                frame_idx, original_idx, barcode_value = future_to_frame[future]
                try:
                    ssim_value = future.result()
                    results.append([frame_idx, original_idx, barcode_value, ssim_value])
                except Exception as exc:
                    print(f'Frame {frame_idx} generated an exception: {exc}')

    cap.release()

    # Sort results by Frame Number (Receiver)
    results.sort(key=lambda x: x[0])

    return results



def main(input_video, output_csv):
    # Read barcode list from CSV
    barcode_df = pd.read_csv('barcode_list.csv')

    # Process original video
    original_frames, original_barcode_values = process_original_video('./raw_video/Zoom1_720p_barcode.mp4', barcode_df)

    # Measure the elapsed time for processing the receiver video
    start_time = time.time()
    results = process_receiver_video(input_video, original_frames, original_barcode_values)
    end_time = time.time()
    
    elapsed_time = end_time - start_time
    print(f"Elapsed time for processing receiver video: {elapsed_time:.2f} seconds")

    # Save results to CSV
    results_df = pd.DataFrame(results, columns=['Frame Number (Receiver)', 'Frame Number (Original)', 'Barcode Number', 'SSIM'])
    results_df.to_csv(output_csv, index=False)

    print(f"Processing complete. Results saved to {output_csv}.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Process videos and compare frames using SSIM and barcode decoding.")
    parser.add_argument("-i", "--input_video", required=True, help="Path to the input video file.")
    parser.add_argument("-o", "--output_csv", required=True, help="Path to the output CSV file.")
    
    args = parser.parse_args()
    main(args.input_video, args.output_csv)