#!/bin/bash

# Run the first Python command and wait for it to finish
python3 compute_SSIM_multithread_batch.py -i ./raw_video/receiver_0625_1.mp4 -o ssim_0625_1.csv

# Check if the first command was successful
if [ $? -ne 0 ]; then
    echo "The first command failed."
    exit 1
fi

# Run the second Python command and wait for it to finish
python3 compute_SSIM_multithread_batch.py -i ./raw_video/receiver_0624_1.mp4 -o ssim_0624_1.csv

# Check if the second command was successful
if [ $? -ne 0 ]; then
    echo "The second command failed."
    exit 1
fi

# # Run the third Python command and wait for it to finish
# python3 compute_SSIM_multithread_batch.py -i ./raw_video/receiver_0619_3.mp4 -o ssim_0619_3.csv

# # Check if the third command was successful
# if [ $? -ne 0 ]; then
#     echo "The third command failed."
#     exit 1
# fi

echo "All commands executed successfully."
