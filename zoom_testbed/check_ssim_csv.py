import csv

def check_ssim_file(file_path):
    with open(file_path, 'r') as csvfile:
        reader = csv.reader(csvfile)
        
        # Skip the header line
        next(reader)
        
        previous_a = None
        count = 1
        error_found = False
        
        for row in reader:
            a_i = float(row[1])  # Convert the second column to a float
            
            if previous_a is not None:
                if a_i < previous_a:
                    if previous_a - a_i <= 620:
                        print(f"Error at row {count}: a_i={a_i}, previous_a={previous_a}")
                        error_found = True
            
            previous_a = a_i
            count += 1
        
        if not error_found:
            print("All good!")

# Use the function with the specific file path
check_ssim_file('ssim_0601.csv')
