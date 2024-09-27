#!/usr/bin/env python3
import os
import re
import json

# Specify the directory path
PROFILES_PATH = "/mnt/oceancurrent/website/profiles/"
CURRENT_METERS_PATH = "/mnt/oceancurrent/website/timeseries/ANMN_P48/"


def parse_filename(filename):
    # Extract the part before the extension (if any)
    base_name = filename.split('.')[0]
    # Split the parts before any underscore (to safely ignore _zt or _xyz suffixes)
    main_parts = base_name.split('_')[0]
    parts = main_parts.split('-')
    
    if len(parts) >= 5:  # Check there are enough parts to parse
        date = parts[1]  # Assume the second element is the date
        identifier = '-'.join(parts[2:-1])  # Join the identifier parts
        nominal_depth = parts[-1]  # The last part before _zt or _xyz is the nominal depth
        return identifier, nominal_depth, date
    return None, None, None

def scan_subdirectory(subdir_path):
    result = []
    if os.path.exists(subdir_path) and os.path.isdir(subdir_path):
        for filename in os.listdir(subdir_path):
            # Skip HTML files
            if filename.endswith('.html'):
                continue
            identifier, nominal_depth, date = parse_filename(filename)
            if identifier and nominal_depth and date:  # Ensure all parts were correctly parsed
                result.append({
                    'currentMeterIdentifier': identifier,
                    'instrumentNominalDepth': nominal_depth,
                    'date': date,
                    'filename': filename
                })
    else:
        print("Directory not found or is not a directory:", subdir_path)
    return result

def scan_current_meters():
    result = {}
    # Scan each subdirectory in the specified path
    for subdir_name in os.listdir(CURRENT_METERS_PATH):
        subdir_path = os.path.join(CURRENT_METERS_PATH, subdir_name)
        if os.path.isdir(subdir_path):
            result[subdir_name] = scan_subdirectory(subdir_path)
    return result

def main():

    platform_codes = os.listdir(PROFILES_PATH)

    for platform_code in platform_codes:
        # List all files and directories in the specified directory
        profile_path = os.path.join(PROFILES_PATH, platform_code)

        if not os.path.isdir(profile_path):
            continue

        all_files = os.listdir(profile_path)

        filenames = [f for f in all_files if os.path.isfile(os.path.join(profile_path, f))]

        # Regular expression pattern to match the gtif filenames
        pattern = re.compile(r'(\d{8})_(\d+)_(\d+)\.gif')

        profiles = []
        # Iterate over each gtif
        for filename in filenames:
            match = pattern.match(filename)
            if match:
                date, profile_number, cycle_number = match.groups()
                profiles.append({
                    "date": date,
                    "cycle": cycle_number,
                    "filename": filename
                })

        profiles_json = json.dumps(profiles, indent=4)

        # Write the JSON string to a file in the path of the profile
        profile_json_path = os.path.join(profile_path, "profiles.json")

        with open(profile_json_path, "w") as f:
            f.write(profiles_json)

        print(f"{profile_json_path} created successfully.")

if __name__ == '__main__':
    main()
    data = scan_current_meters()
    print("Final result:", json.dumps(data, indent=4))
    # Optionally, write to a file
    with open(os.path.join(CURRENT_METERS_PATH, 'current_meters.json'), 'w') as f:
        json.dump(data, f, indent=4)
