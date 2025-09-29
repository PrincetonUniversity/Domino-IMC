import cv2
import os
import numpy as np

# Constants
CROP_FRACTION_WIDTH = 0.05  # Adjust as needed
CROP_FRACTION_HEIGHT = 0.05  # Adjust as needed
TARGET_WIDTH = 1920
TARGET_HEIGHT = 1080
SCALE = 10
DARK_THRESHOLD = 30  # Adjust this value to control how dark the pixels need to be

def detect_and_crop_frame(frame, crop_fraction_width, crop_fraction_height, dark_threshold):
    h, w = frame.shape[:2]

    # Convert YUV to Y channel (grayscale equivalent)
    y_channel = frame[:, :, 0]

    # Calculate target width and height after cropping
    target_w = int(TARGET_WIDTH * (1 - crop_fraction_width * 2))
    target_h = int(TARGET_HEIGHT * (1 - crop_fraction_height * 2))

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

def extract_qrcode_area(frame, scale):
    qr_size = int(scale / 100 * frame.shape[1])
    top_right_corner = frame[:qr_size, -qr_size:]
    return top_right_corner

def save_qrcode_images(video_path, output_dir, num_frames=10, dark_threshold=30):
    cap = cv2.VideoCapture(video_path)
    
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    frame_idx = 0
    saved_count = 0
    
    while cap.isOpened() and saved_count < num_frames:
        ret, frame = cap.read()
        if not ret:
            break

        cropped_frame = detect_and_crop_frame(frame, CROP_FRACTION_WIDTH, CROP_FRACTION_HEIGHT, dark_threshold)
        qrcode_area = extract_qrcode_area(cropped_frame, SCALE)

        # Save QR code area image
        output_path = os.path.join(output_dir, f'qrcode_frame_{frame_idx}.png')
        cv2.imwrite(output_path, qrcode_area)
        saved_count += 1

        frame_idx += 1

    cap.release()
    print(f"Saved {saved_count} QR code images to {output_dir}")

if __name__ == "__main__":
    save_qrcode_images('./raw_video/receiver_capture.mp4', 'qrcode_images')
