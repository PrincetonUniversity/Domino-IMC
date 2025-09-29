# usage: python3 parse_gNBlog.py -file ../../data_zoom/data_exp1109/

import re
from datetime import datetime, timezone
import time
import os
import argparse
from pathlib import Path

def get_start_datetime(file_path):
    """Extract start datetime from log file"""
    with open(file_path, 'r') as f:
        for i, line in enumerate(f):
            if i >= 20:  # Stop searching after 20 lines
                break
            if "# Rotated on" in line:
                match = re.search(r'# Rotated on (\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})', line)
                if match:
                    return datetime.strptime(match.group(1), '%Y-%m-%d %H:%M:%S')
    return None

def parse_timestamp(timestamp_str, base_datetime):
    """Convert HH:MM:SS.mmm timestamp to Unix timestamp using base datetime"""
    # Parse the time components
    time_obj = datetime.strptime(timestamp_str, '%H:%M:%S.%f')
    
    # Create a full datetime using the base date
    full_datetime = base_datetime.replace(
        hour=time_obj.hour,
        minute=time_obj.minute,
        second=time_obj.second,
        microsecond=time_obj.microsecond
    )
    
    # Convert to Unix timestamp (seconds since epoch)
    unix_timestamp = int(full_datetime.timestamp())
    
    # Convert to microseconds
    timestamp_us = unix_timestamp * 1000000 + time_obj.microsecond
    
    return timestamp_us

def parse_pusch_line(line, base_datetime):
    """Extract PUSCH information from a line"""
    pusch_info = {}
    
    # Updated pattern to handle variable spacing
    pattern = r'(\d{2}:\d{2}:\d{2}\.\d{3}) \[PHY\] UL (\w+) (\w+) (\w+)\s+(\d+)\.(\d+) PUSCH:'
    match = re.search(pattern, line)
    
    if match:
        timestamp_str, user_id, cell_id, rnti, frame_idx, slot_idx = match.groups()
        pusch_info['timestamp_us'] = parse_timestamp(timestamp_str, base_datetime)
        pusch_info['user_id'] = user_id
        pusch_info['cell_id'] = cell_id
        pusch_info['rnti'] = rnti
        pusch_info['frame_idx'] = int(frame_idx)
        pusch_info['slot_idx'] = int(slot_idx)
        
        try:
            # Extract parameters keeping original format for prb and symb
            if 'harq=' in line:
                pusch_info['harq'] = int(re.search(r'harq=(\d+)', line).group(1))
            
            if 'prb=' in line:
                pusch_info['prb'] = re.search(r'prb=([^\s]+)', line).group(1)
            
            if 'symb=' in line:
                pusch_info['symb'] = re.search(r'symb=([^\s]+)', line).group(1)
            
            if 'tb_len=' in line:
                pusch_info['tb_len'] = int(re.search(r'tb_len=(\d+)', line).group(1))
            
            if 'mod=' in line:
                pusch_info['mod'] = int(re.search(r'mod=(\d+)', line).group(1))
            
            if 'rv_idx=' in line:
                pusch_info['rv_idx'] = int(re.search(r'rv_idx=(\d+)', line).group(1))
            
            if 'cr=' in line:
                pusch_info['cr'] = float(re.search(r'cr=([\d.]+)', line).group(1))
            
            if 'retx=' in line:
                pusch_info['retx'] = int(re.search(r'retx=(\d+)', line).group(1))
            
            if 'snr=' in line:
                pusch_info['snr'] = float(re.search(r'snr=([\d.-]+)', line).group(1))
            
            if 'epre=' in line:
                pusch_info['epre'] = float(re.search(r'epre=(-?[\d.]+)', line).group(1))
                
        except (ValueError, AttributeError) as e:
            print(f"Warning: Error parsing PUSCH line: {line}")
            print(f"Error: {str(e)}")
            return None
    else:
        print(f"Warning: Failed to match PUSCH pattern in line: {line}")
        # Debug: Print line parts
        if '[PHY] UL' in line and 'PUSCH:' in line:
            print("Line contains PUSCH but didn't match pattern. Parts:")
            parts = line.split()
            print(f"Timestamp: {parts[0]}")
            print(f"Type: {parts[1]} {parts[2]}")
            print(f"IDs: {parts[3]} {parts[4]} {parts[5]}")
            print(f"Frame/Slot: {parts[6]}")
            
    return pusch_info

def parse_pdsch_line(line, base_datetime):
    """Extract PDSCH information from a line"""
    pdsch_info = {}
    
    # Updated pattern to handle '-' as user_id and variable spacing
    pattern = r'(\d{2}:\d{2}:\d{2}\.\d{3}) \[PHY\] DL\s+(\S+) (\S+) (\S+)\s+(\d+)\.(\d+) PDSCH:'
    match = re.search(pattern, line)
    
    if match:
        timestamp_str, user_id, cell_id, rnti, frame_idx, slot_idx = match.groups()
        pdsch_info['timestamp_us'] = parse_timestamp(timestamp_str, base_datetime)
        pdsch_info['user_id'] = user_id  # This can now be '-' or alphanumeric
        pdsch_info['cell_id'] = cell_id
        pdsch_info['rnti'] = rnti
        pdsch_info['frame_idx'] = int(frame_idx)
        pdsch_info['slot_idx'] = int(slot_idx)
        
        try:
            # Extract parameters keeping original format for prb and symb
            if 'harq=' in line:
                # Handle special case where harq can be a string like 'si'
                harq_match = re.search(r'harq=(\S+)', line)
                if harq_match:
                    harq_value = harq_match.group(1)
                    # Try to convert to int if possible, otherwise keep as string
                    try:
                        pdsch_info['harq'] = int(harq_value)
                    except ValueError:
                        pdsch_info['harq'] = harq_value
            
            if 'prb=' in line:
                pdsch_info['prb'] = re.search(r'prb=([^\s]+)', line).group(1)
            
            if 'symb=' in line:
                pdsch_info['symb'] = re.search(r'symb=([^\s]+)', line).group(1)
            
            # Handle CW0 prefix for parameters in PDSCH lines
            tb_len_match = re.search(r'tb_len=(\d+)', line)
            if not tb_len_match:
                tb_len_match = re.search(r'CW0: tb_len=(\d+)', line)
            if tb_len_match:
                pdsch_info['tb_len'] = int(tb_len_match.group(1))
            
            mod_match = re.search(r'mod=(\d+)', line)
            if not mod_match:
                mod_match = re.search(r'CW0: .*mod=(\d+)', line)
            if mod_match:
                pdsch_info['mod'] = int(mod_match.group(1))
            
            rv_idx_match = re.search(r'rv_idx=(\d+)', line)
            if not rv_idx_match:
                rv_idx_match = re.search(r'CW0: .*rv_idx=(\d+)', line)
            if rv_idx_match:
                pdsch_info['rv_idx'] = int(rv_idx_match.group(1))
            
            cr_match = re.search(r'cr=([\d.]+)', line)
            if not cr_match:
                cr_match = re.search(r'CW0: .*cr=([\d.]+)', line)
            if cr_match:
                pdsch_info['cr'] = float(cr_match.group(1))
            
            if 'retx=' in line:
                pdsch_info['retx'] = int(re.search(r'retx=(\d+)', line).group(1))
            
            # Note: No SNR and EPRE fields for PDSCH
                
        except (ValueError, AttributeError) as e:
            print(f"Warning: Error parsing PDSCH line: {line}")
            print(f"Error: {str(e)}")
            return None
    else:
        # Try alternative pattern for special cases with more spaces or different format
        alt_pattern = r'(\d{2}:\d{2}:\d{2}\.\d{3}) \[PHY\] DL.*?(\S+) (\S+) (\S+)\s+(\d+)\.(\d+) PDSCH:'
        alt_match = re.search(alt_pattern, line)
        
        if alt_match:
            timestamp_str, user_id, cell_id, rnti, frame_idx, slot_idx = alt_match.groups()
            pdsch_info['timestamp_us'] = parse_timestamp(timestamp_str, base_datetime)
            pdsch_info['user_id'] = user_id  # This can be '-' or alphanumeric
            pdsch_info['cell_id'] = cell_id
            pdsch_info['rnti'] = rnti
            pdsch_info['frame_idx'] = int(frame_idx)
            pdsch_info['slot_idx'] = int(slot_idx)
            
            # Extract other parameters as in the main branch
            # Handle special case where harq can be a string like 'si'
            if 'harq=' in line:
                harq_match = re.search(r'harq=(\S+)', line)
                if harq_match:
                    harq_value = harq_match.group(1)
                    # Try to convert to int if possible, otherwise keep as string
                    try:
                        pdsch_info['harq'] = int(harq_value)
                    except ValueError:
                        pdsch_info['harq'] = harq_value
            
            if 'prb=' in line:
                pdsch_info['prb'] = re.search(r'prb=([^\s]+)', line).group(1)
            
            if 'symb=' in line:
                pdsch_info['symb'] = re.search(r'symb=([^\s]+)', line).group(1)
            
            # Handle CW0 prefix for parameters in PDSCH lines
            tb_len_match = re.search(r'tb_len=(\d+)', line)
            if not tb_len_match:
                tb_len_match = re.search(r'CW0: tb_len=(\d+)', line)
            if tb_len_match:
                pdsch_info['tb_len'] = int(tb_len_match.group(1))
            
            mod_match = re.search(r'mod=(\d+)', line)
            if not mod_match:
                mod_match = re.search(r'CW0: .*mod=(\d+)', line)
            if mod_match:
                pdsch_info['mod'] = int(mod_match.group(1))
            
            rv_idx_match = re.search(r'rv_idx=(\d+)', line)
            if not rv_idx_match:
                rv_idx_match = re.search(r'CW0: .*rv_idx=(\d+)', line)
            if rv_idx_match:
                pdsch_info['rv_idx'] = int(rv_idx_match.group(1))
            
            cr_match = re.search(r'cr=([\d.]+)', line)
            if not cr_match:
                cr_match = re.search(r'CW0: .*cr=([\d.]+)', line)
            if cr_match:
                pdsch_info['cr'] = float(cr_match.group(1))
            
            if 'retx=' in line:
                pdsch_info['retx'] = int(re.search(r'retx=(\d+)', line).group(1))
                
        else:
            print(f"Warning: Failed to match PDSCH pattern in line: {line}")
            # Debug: Print line parts
            if '[PHY] DL' in line and 'PDSCH:' in line:
                print("Line contains PDSCH but didn't match pattern. Parts:")
                parts = line.split()
                if len(parts) >= 7:
                    print(f"Timestamp: {parts[0]}")
                    print(f"Type: {parts[1]} {parts[2]}")
                    print(f"IDs: {' '.join(parts[3:6])}")
                    print(f"Frame/Slot: {parts[6]}")
                else:
                    print("Line has unexpected format, parts:", parts)
            
    return pdsch_info

def parse_mac_ul_line(line, base_datetime):
    """Extract MAC UL information from a line"""
    mac_info = {}
    
    # Extract timestamp and basic information
    match = re.search(r'(\d{2}:\d{2}:\d{2}\.\d{3}) \[MAC\] UL (\w+) (\w+)', line)
    if match:
        timestamp_str, user_id, cell_id = match.groups()
        mac_info['timestamp_us'] = parse_timestamp(timestamp_str, base_datetime)
        mac_info['user_id'] = user_id
        mac_info['cell_id'] = cell_id
        
        # Extract BSR information
        sbsr_match = re.search(r'SBSR:lcg=(\d+) bs=(\d+)', line)
        lbsr_match = re.search(r'LBSR:bitmap=(\w+)((?:\s+bs\(\d+\)=\d+)*)', line)
        
        if sbsr_match:
            mac_info['bsr_type'] = 'short'
            mac_info['lcg'] = int(sbsr_match.group(1))
            mac_info['bs'] = int(sbsr_match.group(2))
        elif lbsr_match:
            mac_info['bsr_type'] = 'long'
            mac_info['bitmap'] = lbsr_match.group(1)
            
            # Extract bs values for LCG 0 and 7
            bs_values = re.findall(r'bs\((\d+)\)=(\d+)', line)
            mac_info['bsr_0'] = ''  # Default empty value
            mac_info['bsr_7'] = ''  # Default empty value
            
            for lcg, value in bs_values:
                lcg = int(lcg)
                if lcg == 0:
                    mac_info['bsr_0'] = int(value)
                elif lcg == 7:
                    mac_info['bsr_7'] = int(value)
            
        # Extract PAD information
        pad_match = re.search(r'PAD:len=(\d+)', line)
        if pad_match:
            mac_info['pad_len'] = int(pad_match.group(1))
            
    return mac_info

def parse_mac_dl_line(line, base_datetime):
    """Extract MAC DL information from a line"""
    mac_info = {}
    
    # Extract timestamp and basic information, allowing for '-' as user_id
    match = re.search(r'(\d{2}:\d{2}:\d{2}\.\d{3}) \[MAC\] DL (\S+) (\S+)', line)
    if match:
        timestamp_str, user_id, cell_id = match.groups()
        mac_info['timestamp_us'] = parse_timestamp(timestamp_str, base_datetime)
        mac_info['user_id'] = user_id  # This can be '-' or alphanumeric
        mac_info['cell_id'] = cell_id
        
        # Extract PAD information
        pad_match = re.search(r'PAD:len=(\d+)', line)
        if pad_match:
            mac_info['pad_len'] = int(pad_match.group(1))
            
    return mac_info

def parse_log_file_ul(input_file, output_file):
    """Parse the log file for UL data and write extracted information to output file"""
    current_pusch_info = None
    pusch_count = 0
    parsed_count = 0
    timestamp_adjusted_count = 0
    prev_timestamp = None
    prev_slot_idx = None
    
    base_datetime = get_start_datetime(input_file)
    if not base_datetime:
        print(f"Warning: Could not find start datetime in {input_file}")
        return
    
    # Create/open output file and write header if needed
    if not os.path.exists(output_file):
        with open(output_file, 'w', newline='', encoding='utf-8') as f_out:
            header = ",".join([
                "Timestamp_us", "User_ID", "Cell_ID", "RNTI", "Frame_Idx", "Slot_Idx",
                "HARQ", "PRB", "Symb", "TB_Len", "Mod", "RV_Idx", "CR", "Retx", "SNR",
                "EPRE", "BSR_Type", "BSR_LCG", "BSR_BS", "BSR_Bitmap", "BSR(0)",
                "BSR(7)", "PAD_Len"
            ]) + "\n"
            f_out.write(header)
    
    # Read all lines from the input file
    with open(input_file, 'r') as f_in:
        lines = f_in.readlines()
    
    # Process the file
    output_lines = []
    current_line_idx = None
    # Track original timestamps for MAC matching
    original_timestamps = {}  # key: (timestamp, user_id, cell_id), value: adjusted_timestamp
    
    for line in lines:
        line = line.strip()
        if not line or line.startswith('        '):  # Skip empty lines and hex dumps
            continue
        
        if '[PHY] UL' in line and 'PUSCH:' in line:
            pusch_count += 1
            pusch_info = parse_pusch_line(line, base_datetime)
            
            if pusch_info:
                parsed_count += 1
                original_timestamp = pusch_info['timestamp_us']
                
                # Check if we need to adjust the timestamp
                current_slot = pusch_info['slot_idx']
                current_timestamp = pusch_info['timestamp_us']
                
                if current_slot in [9, 19] and prev_timestamp is not None and prev_slot_idx is not None:
                    if current_timestamp == prev_timestamp:
                        # Increment timestamp by 0.5ms (500 microseconds)
                        pusch_info['timestamp_us'] += 500
                        timestamp_adjusted_count += 1
                        # Store original timestamp for MAC matching
                        key = (original_timestamp, pusch_info['user_id'], pusch_info['cell_id'])
                        original_timestamps[key] = pusch_info['timestamp_us']
                
                # Update previous timestamp and slot
                prev_timestamp = pusch_info['timestamp_us']
                prev_slot_idx = current_slot
                
                # Write PUSCH info to a new line
                output_fields = [
                    str(pusch_info['timestamp_us']),
                    str(pusch_info['user_id']),
                    str(pusch_info['cell_id']),
                    str(pusch_info['rnti']),
                    str(pusch_info['frame_idx']),
                    str(pusch_info['slot_idx']),
                    str(pusch_info.get('harq', '')),
                    str(pusch_info.get('prb', '')),
                    str(pusch_info.get('symb', '')),
                    str(pusch_info.get('tb_len', '')),
                    str(pusch_info.get('mod', '')),
                    str(pusch_info.get('rv_idx', '')),
                    str(pusch_info.get('cr', '')),
                    str(pusch_info.get('retx', '')),
                    str(pusch_info.get('snr', '')),
                    str(pusch_info.get('epre', '')),
                    '', '', '', '', '', '',  # Empty placeholders for MAC info
                    ''  # Empty placeholder for PAD_Len
                ]
                output_line = ','.join(output_fields)
                output_lines.append(output_line)
                current_line_idx = len(output_lines) - 1
                current_pusch_info = pusch_info
                
        elif '[MAC] UL' in line and current_pusch_info and current_line_idx is not None:
            mac_info = parse_mac_ul_line(line, base_datetime)
            
            # Check both original and adjusted timestamps for matching
            key = (mac_info['timestamp_us'], mac_info['user_id'], mac_info['cell_id'])
            adjusted_timestamp = original_timestamps.get(key)
            
            # Match if timestamps are equal or if the MAC timestamp matches an original timestamp that was adjusted
            if ((mac_info['timestamp_us'] == current_pusch_info['timestamp_us'] or 
                 (adjusted_timestamp and adjusted_timestamp == current_pusch_info['timestamp_us'])) and
                mac_info['user_id'] == current_pusch_info['user_id'] and
                mac_info['cell_id'] == current_pusch_info['cell_id']):
                
                parts = output_lines[current_line_idx].split(',')
                
                # Prepare BSR information
                bsr_fields = [''] * 6  # [type, lcg, bs, bitmap, bsr_0, bsr_7]
                if 'bsr_type' in mac_info:
                    bsr_fields[0] = mac_info['bsr_type']
                    if mac_info['bsr_type'] == 'short':
                        bsr_fields[1] = str(mac_info['lcg'])
                        bsr_fields[2] = str(mac_info['bs'])
                    else:  # long BSR
                        bsr_fields[3] = mac_info['bitmap']
                        bsr_fields[4] = str(mac_info.get('bsr_0', ''))
                        bsr_fields[5] = str(mac_info.get('bsr_7', ''))
                
                # Update the line with BSR and PAD information
                parts[16:22] = bsr_fields
                parts[22] = str(mac_info.get('pad_len', ''))
                output_lines[current_line_idx] = ','.join(parts)
    
    # Write all lines to output file
    with open(output_file, 'a', newline='', encoding='utf-8') as f_out:
        for line in output_lines:
            f_out.write(line.rstrip() + '\n')
    
    print(f"\nStatistics for UL data in {input_file}:")
    print(f"Total PUSCH lines found: {pusch_count}")
    print(f"Successfully parsed PUSCH lines: {parsed_count}")
    print(f"Timestamps adjusted for granularity: {timestamp_adjusted_count}")
    print(f"Percentage of adjusted timestamps: {(timestamp_adjusted_count/parsed_count*100):.2f}%\n" if parsed_count > 0 else "No parsed entries\n")

def parse_log_file_dl(input_file, output_file):
    """Parse the log file for DL data and write extracted information to output file"""
    current_pdsch_info = None
    pdsch_count = 0
    parsed_count = 0
    special_id_count = 0  # Count PDSCH lines with '-' as user_id
    timestamp_adjusted_count = 0
    prev_timestamp = None
    prev_slot_idx = None
    
    base_datetime = get_start_datetime(input_file)
    if not base_datetime:
        print(f"Warning: Could not find start datetime in {input_file}")
        return
    
    # Create/open output file and write header if needed
    if not os.path.exists(output_file):
        with open(output_file, 'w', newline='', encoding='utf-8') as f_out:
            header = ",".join([
                "Timestamp_us", "User_ID", "Cell_ID", "RNTI", "Frame_Idx", "Slot_Idx",
                "HARQ", "PRB", "Symb", "TB_Len", "Mod", "RV_Idx", "CR", "Retx",
                "PAD_Len"  # No SNR or EPRE in DL, and no BSR info
            ]) + "\n"
            f_out.write(header)
    
    # Read all lines from the input file
    with open(input_file, 'r') as f_in:
        lines = f_in.readlines()
    
    # Process the file
    output_lines = []
    current_line_idx = None
    # Track original timestamps for MAC matching
    original_timestamps = {}  # key: (timestamp, user_id, cell_id), value: adjusted_timestamp
    
    for line in lines:
        line = line.strip()
        if not line or line.startswith('        '):  # Skip empty lines and hex dumps
            continue
        
        if '[PHY] DL' in line and 'PDSCH:' in line:
            pdsch_count += 1
            pdsch_info = parse_pdsch_line(line, base_datetime)
            
            if pdsch_info:
                parsed_count += 1
                # Count special cases with '-' as user_id
                if pdsch_info['user_id'] == '-':
                    special_id_count += 1
                    
                original_timestamp = pdsch_info['timestamp_us']
                
                # Check if we need to adjust the timestamp
                current_slot = pdsch_info['slot_idx']
                current_timestamp = pdsch_info['timestamp_us']
                
                if current_slot in [9, 19] and prev_timestamp is not None and prev_slot_idx is not None:
                    if current_timestamp == prev_timestamp:
                        # Increment timestamp by 0.5ms (500 microseconds)
                        pdsch_info['timestamp_us'] += 500
                        timestamp_adjusted_count += 1
                        # Store original timestamp for MAC matching
                        key = (original_timestamp, pdsch_info['user_id'], pdsch_info['cell_id'])
                        original_timestamps[key] = pdsch_info['timestamp_us']
                
                # Update previous timestamp and slot
                prev_timestamp = pdsch_info['timestamp_us']
                prev_slot_idx = current_slot
                
                # Write PDSCH info to a new line
                output_fields = [
                    str(pdsch_info['timestamp_us']),
                    str(pdsch_info['user_id']),
                    str(pdsch_info['cell_id']),
                    str(pdsch_info['rnti']),
                    str(pdsch_info['frame_idx']),
                    str(pdsch_info['slot_idx']),
                    str(pdsch_info.get('harq', '')),
                    str(pdsch_info.get('prb', '')),
                    str(pdsch_info.get('symb', '')),
                    str(pdsch_info.get('tb_len', '')),
                    str(pdsch_info.get('mod', '')),
                    str(pdsch_info.get('rv_idx', '')),
                    str(pdsch_info.get('cr', '')),
                    str(pdsch_info.get('retx', '')),
                    ''  # Empty placeholder for PAD_Len
                ]
                output_line = ','.join(output_fields)
                output_lines.append(output_line)
                current_line_idx = len(output_lines) - 1
                current_pdsch_info = pdsch_info
                
        elif '[MAC] DL' in line and current_pdsch_info and current_line_idx is not None:
            mac_info = parse_mac_dl_line(line, base_datetime)
            
            # Check both original and adjusted timestamps for matching
            key = (mac_info['timestamp_us'], mac_info['user_id'], mac_info['cell_id'])
            adjusted_timestamp = original_timestamps.get(key)
            
            # Match if timestamps are equal or if the MAC timestamp matches an original timestamp that was adjusted
            if ((mac_info['timestamp_us'] == current_pdsch_info['timestamp_us'] or 
                 (adjusted_timestamp and adjusted_timestamp == current_pdsch_info['timestamp_us'])) and
                mac_info['user_id'] == current_pdsch_info['user_id'] and
                mac_info['cell_id'] == current_pdsch_info['cell_id']):
                
                parts = output_lines[current_line_idx].split(',')
                
                # Update the line with PAD information (only PAD info for DL MAC)
                parts[14] = str(mac_info.get('pad_len', ''))
                output_lines[current_line_idx] = ','.join(parts)
    
    # Write all lines to output file
    with open(output_file, 'a', newline='', encoding='utf-8') as f_out:
        for line in output_lines:
            f_out.write(line.rstrip() + '\n')
    
    print(f"\nStatistics for DL data in {input_file}:")
    print(f"Total PDSCH lines found: {pdsch_count}")
    print(f"Successfully parsed PDSCH lines: {parsed_count}")
    print(f"PDSCH lines with special ID '-': {special_id_count}")
    print(f"Timestamps adjusted for granularity: {timestamp_adjusted_count}")
    print(f"Percentage of adjusted timestamps: {(timestamp_adjusted_count/parsed_count*100):.2f}%\n" if parsed_count > 0 else "No parsed entries\n")

def get_log_files(folder_path):
    """Get all gnb log files in chronological order"""
    files = []
    base_file = None
    timestamp_pattern = r'\.(\d{8})\.(\d{2}:\d{2}:\d{2})$'
    
    for file in os.listdir(folder_path):
        if file.startswith('gnb0_webrtc.log'):
            full_path = os.path.join(folder_path, file)
            if file == 'gnb0_webrtc.log':
                base_file = full_path
            else:
                match = re.search(timestamp_pattern, file)
                if match:
                    date_str, time_str = match.groups()
                    timestamp = datetime.strptime(f"{date_str} {time_str}", '%Y%m%d %H:%M:%S')
                    files.append((timestamp, full_path))
    
    # Sort files by timestamp
    files.sort(key=lambda x: x[0])
    sorted_files = [f[1] for f in files]
    
    # Add base file at the end if it exists
    if base_file:
        sorted_files.append(base_file)
    
    return sorted_files

def main():
    parser = argparse.ArgumentParser(description='Parse gNB log files')
    parser.add_argument('-file', required=True, help='Path to the data folder')
    args = parser.parse_args()
    
    # Convert relative path to absolute path
    folder_path = os.path.abspath(args.file)
    ul_output_file = os.path.join(folder_path, 'gnb_ul_webrtc_parsed.csv')
    dl_output_file = os.path.join(folder_path, 'gnb_dl_webrtc_parsed.csv')
    
    # Delete output files if they exist
    if os.path.exists(ul_output_file):
        os.remove(ul_output_file)
    if os.path.exists(dl_output_file):
        os.remove(dl_output_file)
    
    # Process each log file in order
    log_files = get_log_files(folder_path)
    for log_file in log_files:
        print(f"Processing {log_file}...")
        parse_log_file_ul(log_file, ul_output_file)
        parse_log_file_dl(log_file, dl_output_file)

if __name__ == "__main__":
    main()