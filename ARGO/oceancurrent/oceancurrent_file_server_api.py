import re
from pathlib import Path
from typing import List, Dict, Any
import logging
import json
import os
import sys
import time
import traceback
from datetime import datetime
import resource

# Define the absolute path of the file directory root path
# Use local test data if DEV_MODE environment variable is set
base_path = "/mnt/oceancurrent/website/"
if os.getenv("DEV_MODE") == "true":
    OCEAN_CURRENT_FILE_ROOT_PATH = f"./ARGO/oceancurrent/tests{base_path}"
else:
    OCEAN_CURRENT_FILE_ROOT_PATH = base_path

# Production logging configuration with fallback
log_format = '%(asctime)s - %(name)s - %(levelname)s - PID:%(process)d - %(funcName)s:%(lineno)d - %(message)s'
handlers = [logging.StreamHandler(sys.stdout)]

# Try to add file handler, fallback to current directory if IMOS log directory is not writable
imos_log_path = '/var/log/imos/oceancurrent_file_server_api.log'
try:
    # Ensure the IMOS log directory exists
    os.makedirs('/var/log/imos', exist_ok=True)
    handlers.append(logging.FileHandler(imos_log_path, mode='a'))
except (PermissionError, OSError):
    # Fallback to current directory
    fallback_log_path = os.path.join(os.getcwd(), 'oceancurrent_file_server_api.log')
    handlers.append(logging.FileHandler(fallback_log_path, mode='a'))
    print(f"Warning: Cannot write to {imos_log_path}, using fallback: {fallback_log_path}")

logging.basicConfig(
    level=logging.INFO,
    format=log_format,
    handlers=handlers
)
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Suppress excessive third-party library logs
logging.getLogger('urllib3').setLevel(logging.WARNING)
logging.getLogger('requests').setLevel(logging.WARNING)

FILE_PATH_CONFIG = [
    {
        "productId": "fourHourSst-sstFilled",
        "include":[
            {"path": "SST_4hr", "layer": 1},
            {"path": "SST_Filled", "layer": 2}
        ],
        "filetype": ".gif",
        "region_layer": 3,
        "max_layer": 3
    },
    {
        "productId": "fourHourSst-sst",
        "include":[
            {"path": "SST_4hr", "layer": 1},
            {"path": "^SST$", "layer": 2}
        ],
        "filetype": ".gif",
        "region_layer": 3,
        "max_layer": 3
    },
    {
        "productId": "fourHourSst-sstAge",
        "include":[
            {"path": "SST_4hr", "layer": 1},
            {"path": "SST_Age", "layer": 2}
        ],
        "filetype": ".gif",
        "region_layer": 3,
        "max_layer": 3
    },
    {
        "productId": "fourHourSst-windSpeed",
        "include":[
            {"path": "SST_4hr", "layer": 1},
            {"path": "Wind", "layer": 2}
        ],
        "filetype": ".gif",
        "region_layer": 3,
        "max_layer": 3
    },
    {
        "productId": "sixDaySst-sst",
        "include":[
            {"path": "DR_SST_daily", "layer": 1},
            {"path": "^SST$", "layer": 2}
        ],
        "filetype": ".gif",
        "region_layer": 3,
        "max_layer": 3
    },
    {
        "productId": "sixDaySst-sst",
        "include":[
            {"path": "STATE_daily", "layer": 1},
            {"path": "^SST$", "layer": 2}
        ],
        "filetype": ".gif",
        "region_layer": 3,
        "max_layer": 3
    },
    {
        "productId": "sixDaySst-sstAnomaly",
        "include":[
            {"path": "DR_SST_daily", "layer": 1},
            {"path": "SST_ANOM", "layer": 2}
        ],
        "filetype": ".gif",
        "region_layer": 3,
        "max_layer": 3
    },
    {
        "productId": "sixDaySst-sstAnomaly",
        "include":[
            {"path": "STATE_daily", "layer": 1},
            {"path": "SST_ANOM", "layer": 2}
        ],
        "filetype": ".gif",
        "region_layer": 3,
        "max_layer": 3
    },
    {
        "productId": "sixDaySst-centile",
        "include":[
            {"path": "DR_SST_daily", "layer": 1},
            {"path": "pctiles", "layer": 2}
        ],
        "filetype": ".gif",
        "region_layer": 3,
        "max_layer": 3
    },
    {
        "productId": "sixDaySst-centile",
        "include":[
            {"path": "STATE_daily", "layer": 1},
            {"path": "pctiles", "layer": 2}
        ],
        "filetype": ".gif",
        "region_layer": 3,
        "max_layer": 3
    },
    {
        "productId": "currentMetersCalendar-49",
        "include":[
            {"path": "timeseries", "layer": 1},
            {"path": "ANMN_P49", "layer": 2}
        ],
        "filetype": ".gif",
        "max_layer": 2,
        "save_in_product_folder": True
    },
    {
        "productId": "currentMetersCalendar-48",
        "include":[
            {"path": "timeseries", "layer": 1},
            {"path": "ANMN_P48", "layer": 2}
        ],
        "filetype": ".gif",
        "max_layer": 2,
        "save_in_product_folder": True
    },
    {
        "productId": "currentMetersRegion-49",
        "include":[
            {"path": "timeseries", "layer": 1},
            {"path": "ANMN_P49", "layer": 2},
            {"path": "mapst", "layer": 3}
        ],
        "filetype": ".gif",
        "max_layer": 3,
        "save_in_product_folder": True
    },
    {
        "productId": "currentMetersRegion-48",
        "include":[
            {"path": "timeseries", "layer": 1},
            {"path": "ANMN_P48", "layer": 2},
            {"path": "mapst", "layer": 3}
        ],
        "filetype": ".gif",
        "max_layer": 3,
        "save_in_product_folder": True
    },
    {
        "productId": "currentMetersPlot-49",
        "include":[
            {"path": "timeseries", "layer": 1},
            {"path": "ANMN_P49", "layer": 2},
            {
                "path": "^(?!mapst$|time_error_check$).*$",
                "layer": 3
            }
        ],
        "filetype": ".gif",
        "region_layer": 3,
        "depth_layer": 4,
        "max_layer": 4,
        "save_in_product_folder": True
    },
    {
        "productId": "currentMetersPlot-48",
        "include":[
            {"path": "timeseries", "layer": 1},
            {"path": "ANMN_P48", "layer": 2},
            {
                "path": "^(?!mapst$|time_error_check$).*$",
                "layer": 3
            }
        ],
        "filetype": ".gif",
        "region_layer": 3,
        "depth_layer": 4,
        "max_layer": 4,
        "save_in_product_folder": True
    },
    {
        "productId": "sealCtd-sealTracks",
        "include":[
            {"path": "AATAMS", "layer": 1},
            {"path": "GAB|NSW|POLAR", "layer": 2},
            {"path": "tracks", "layer": 3}
        ],
        "filetype": ".gif",
        "region_layer": 2,
        "max_layer": 3,
        "save_in_product_folder": True
    },
    {
        "productId": "sealCtd-sealTracks-video",
        "include":[
            {"path": "AATAMS", "layer": 1},
            {"path": "GAB|NSW|POLAR", "layer": 2},
            {"path": "tracks", "layer": 3}
        ],
        "filetype": ".mp4",
        "region_layer": 2,
        "max_layer": 3,
        "save_in_product_folder": True
    },
    {
        "productId": "sealCtd-timeseriesTemperature",
        "include":[
            {"path": "AATAMS", "layer": 1},
            {"path": "GAB|NSW|POLAR", "layer": 2},
            {"path": "timeseries", "layer": 3}
        ],
        "filetype": "^T_.*.gif$",
        "region_layer": 2,
        "max_layer": 3,
        "save_in_product_folder": True
    },
    {
        "productId": "sealCtd-timeseriesSalinity",
        "include":[
            {"path": "AATAMS", "layer": 1},
            {"path": "GAB|NSW|POLAR", "layer": 2},
            {"path": "timeseries", "layer": 3}
        ],
        "filetype": "^S_.*.gif$",
        "region_layer": 2,
        "max_layer": 3,
        "save_in_product_folder": True
    },
    {
        "productId": "sealCtdTags-10days",
        "include": [
            {"path": "AATAMS", "layer": 1},
            {"path": "SATTAGS", "layer": 2},
            {"path": "10days", "layer": 4},
        ],
        "filetype": ".gif",
        "max_layer": 4,
        "save_in_product_folder": True
    },
    {
        "productId": "sealCtdTags-temperature",
        "include": [
            {"path": "AATAMS", "layer": 1},
            {"path": "SATTAGS", "layer": 2},
        ],
        "filetype": "T.gif",
        "max_layer": 3,
        "save_in_product_folder": True
    },
    {
        "productId": "sealCtdTags-salinity",
        "include": [
            {"path": "AATAMS", "layer": 1},
            {"path": "SATTAGS", "layer": 2},
        ],
        "filetype": "S.gif",
        "max_layer": 3,
        "save_in_product_folder": True
    },
    {
        "productId": "sealCtdTags-ts",
        "include": [
            {"path": "AATAMS", "layer": 1},
            {"path": "SATTAGS", "layer": 2},
        ],
        "filetype": "TS.gif",
        "max_layer": 3,
        "save_in_product_folder": True
    },
    {
        "productId": "sealCtdTags-timeseries",
        "include": [
            {"path": "AATAMS", "layer": 1},
            {"path": "SATTAGS", "layer": 2},
        ],
        "filetype": "timeseries.gif",
        "max_layer": 3,
        "save_in_product_folder": True
    },
    {
        "productId": "adjustedSeaLevelAnomaly-sla",
        "include":[
            {"path": "STATE_daily", "layer": 1},
            {"path": "^SLA$", "layer": 2}
        ],
        "filetype": ".gif",
        "region_layer": 3,
        "max_layer": 3,
    },
    {
        "productId": "adjustedSeaLevelAnomaly-centiles",
        "include":[
            {"path": "STATE_daily", "layer": 1},
            {"path": "SLA_pctiles", "layer": 2}
        ],
        "filetype": ".gif",
        "region_layer": 3,
        "max_layer": 3,
    },
    {
        "productId": "oceanColour-chlA",
        "include": [
            {"path": "STATE_daily", "layer": 1},
            {"path": "^CHL$", "layer": 2}
        ],
        "filetype": ".gif",
        "region_layer": 3,
        "max_layer": 3
    },
    {
        "productId": "oceanColour-chlAAge",
        "include": [
            {"path": "STATE_daily", "layer": 1},
            {"path": "CHL_AGE", "layer": 2}
        ],
        "filetype": ".gif",
        "region_layer": 3,
        "max_layer": 3
    },
    {
        "productId": "oceanColour-chlA",
        "include": [
            {"path": ".*(_chl)$", "layer": 1}
        ],
        "filetype": ".gif",
        "region_layer": 1,
        "max_layer": 1,
        "save_in_product_folder": True
    },
    {
        "productId": "oceanColour-chlA-year",
        "include": [
            {"path": ".*(_chl)$", "layer": 1},
            {"path": "^\\d{4}$", "layer": 2}
        ],
        "filetype": ".gif",
        "region_layer": 1,
        "max_layer": 2,
        "save_in_product_folder": True
    },
    {
        "productId": "adjustedSeaLevelAnomaly-sst",
        "include":[
            {
            "path": "^(GAB|ht|NE|NW|SE|SO|SW|Adelaide|AlbEsp|Bris-Syd|Brisbane|Brisbane2|Broome|CGBR|CLeeu|Coffs|DonPer|EGAB|Kimberley|LordHoweS|NGBR|NWS|Ningaloo|Perth|RechEyre|Rottnest|SAgulfs|SGBR|SNSW|Syd-Hob|Tas|TasE|TimorP|XmasI)$",
            "layer": 1
            },
        ],
        "filetype": ".gif",
        "region_layer": 1,
        "max_layer": 1,
        "save_in_product_folder": True
    },
    {
        "productId": "adjustedSeaLevelAnomaly-sst-year",
        "include":[
            {
            "path": "^(ht|Adelaide|AlbEsp|Bris-Syd|Brisbane|Brisbane2|Broome|CGBR|CLeeu|Coffs|DonPer|EGAB|Kimberley|LordHoweS|NGBR|NWS|Ningaloo|Perth|RechEyre|Rottnest|SAgulfs|SGBR|SNSW|Syd-Hob|Tas|TasE|TimorP|XmasI)$",
            "layer": 1
            },
            {"path": "^\\d{4}$",
            "layer": 2}
        ],
        "filetype": ".gif",
        "region_layer": 1,
        "max_layer": 2,
        "save_in_product_folder": True
    },
    {
        "productId": "tidalCurrents-spd",
        "include": [
            {"path": "tides", "layer": 1},
            {"path": ".*(_spd)$", "layer": 2},
            {"path": "^\\d{4}$", "layer": 3}
        ],
        "filetype": ".gif",
        "region_layer": 2,
        "max_layer": 3,
        "save_in_product_folder": True
    },
    {
        "productId": "tidalCurrents-sl",
        "include": [
            {"path": "tides", "layer": 1},
            {"path": ".*(_hv)$", "layer": 2},
            {"path": "^\\d{4}$", "layer": 3}
        ],
        "filetype": ".gif",
        "region_layer": 2,
        "max_layer": 3,
        "save_in_product_folder": True
    },
    {
        "productId": "EACMooringArray",
        "include": [
            {"path": "EAC_array_figures", "layer": 1},
            {"path": "SST", "layer": 2},
            {"path": "Brisbane", "layer": 3}
        ],
        "filetype": ".gif",
        "region_layer": 3,
        "max_layer": 3,
        "save_in_product_folder": True
    }
]

def recursive_scan(folder: Path,
                   current_layer: int,
                   include_rules: Dict[int, List[re.Pattern]],
                   max_layer: int,
                   filetype_mode: str, # string suffix or file name or name regex
                   filetype_pattern: Any) -> List[Path]:
    results = []
    if current_layer > max_layer:
        return results
    if current_layer in include_rules and \
       not any(rx.match(folder.name) for rx in include_rules[current_layer]):
        return results

    for item in folder.iterdir():
        if item.is_dir():
            if current_layer < max_layer:
                results.extend(
                    recursive_scan(item,
                                   current_layer + 1,
                                   include_rules,
                                   max_layer,
                                   filetype_mode,
                                   filetype_pattern)
                )
        elif item.is_file() and current_layer == max_layer:
            if filetype_mode == "suffix":
                if item.suffix.lower() == filetype_pattern:
                    results.append(item)
            else:
                if filetype_pattern.match(item.name):
                    results.append(item)
    return results


def scan_files_from_config(parent_directory: Path, config: Dict[str, Any]) -> List[Path]:
    include = config.get("include", [])
    file_type = config["filetype"]
    max_layer = config["max_layer"]

    if file_type.startswith("."):
        filetype_mode = "suffix"
        filetype_pattern = file_type.lower()
    else:
        filetype_mode = "regex"
        filetype_pattern = re.compile(file_type, re.IGNORECASE)

    include_lookup = {}
    for item in include:
        layer = item["layer"]
        path_pattern = item["path"]
        path_regex = re.compile(path_pattern)
        include_lookup.setdefault(layer, []).append(path_regex)

    return recursive_scan(
        parent_directory,
        current_layer=0,
        include_rules=include_lookup,
        max_layer=max_layer,
        filetype_mode=filetype_mode,
        filetype_pattern=filetype_pattern
    )

def save_result_as_json(files: List[Path], config: Dict[str, Any], parent_directory: Path):
    """
    Save scanning results to JSON grouped by inferred region and depth based on config.
    """
    output: List[Dict[str, Any]] = []
    region_layer = config.get("region_layer")
    depth_layer = config.get("depth_layer")

    for file_path in files:
        rel = file_path.relative_to(parent_directory)
        parts = rel.parts

        region = None
        depth = None
        if region_layer and len(parts) > region_layer - 1:
            if parts[region_layer - 1].endswith("_chl"):
                region = parts[region_layer - 1].replace("_chl", "")
            elif parts[region_layer - 1].endswith("_spd"):
                region = parts[region_layer - 1].replace("_spd", "")
            elif parts[region_layer - 1].endswith("_hv"):
                region = parts[region_layer - 1].replace("_hv", "")
            else:
                region = parts[region_layer - 1]
        if depth_layer and len(parts) > depth_layer - 1:
            depth = parts[depth_layer - 1]

        record_path = str(Path(os.sep, *parts[:-1]))
        rec = next((r for r in output if r["region"] == region and r["path"] == record_path), None)
        if not rec:
            rec = {
                "path": record_path,
                "productId": config["productId"],
                "region": region,
                "depth": depth,
                "files": []
            }
            output.append(rec)
        rec["files"].append({"name": file_path.name})

    first = None
    second = None
    if files:
        rel_parts = files[0].relative_to(parent_directory).parts[:-1]
        if len(rel_parts) >= 1:
            first = rel_parts[0]
        if len(rel_parts) >= 2:
            second = rel_parts[1]

    if config.get("save_in_product_folder"):
        if second and config["productId"] != "oceanColour-chlA-year" and config["productId"] != "adjustedSeaLevelAnomaly-sst-year":
            output_folder = parent_directory / first
        else:
            output_folder = parent_directory
        output_filename = f"{config['productId']}.json"
        logger.info(f"JSON file {output_filename} created in product folder: {first}")
    else:
        if first == parent_directory.name:
            output_folder = parent_directory
            output_filename = f"{config['productId']}.json"
            logger.info(f"JSON file {output_filename} created for product: {config['productId']}")
        elif second:
            output_folder = parent_directory / first / second
            output_filename = f"{second}.json"
            logger.info(f"JSON file {output_filename} created for region: {second}")
        else:
            output_folder = parent_directory / first
            output_filename = f"{first}.json"
            logger.info(f"JSON file {output_filename} created for product: {config['productId']}")

    output_folder.mkdir(parents=True, exist_ok=True)
    output_file = output_folder / output_filename
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(output, f, indent=4)



def get_memory_usage():
    """Get current memory usage in MB"""
    try:
        usage = resource.getrusage(resource.RUSAGE_SELF)
        # On Linux, ru_maxrss is in KB, on macOS it's in bytes
        if sys.platform == 'darwin':
            return usage.ru_maxrss / 1024 / 1024  # Convert bytes to MB
        else:
            return usage.ru_maxrss / 1024  # Convert KB to MB
    except Exception:
        return 0

def main():
    start_time = time.time()
    script_name = os.path.basename(__file__)
    initial_memory = get_memory_usage()
    
    # Startup logging
    logger.info("=" * 80)
    logger.info(f"STARTING: {script_name}")
    logger.info(f"Process ID: {os.getpid()}")
    logger.info(f"Python version: {sys.version.split()[0]}")
    logger.info(f"Working directory: {os.getcwd()}")
    logger.info(f"Script arguments: {sys.argv}")
    logger.info(f"Environment mode: {'DEV' if os.getenv('DEV_MODE') == 'true' else 'PRODUCTION'}")
    logger.info(f"Ocean current root path: {OCEAN_CURRENT_FILE_ROOT_PATH}")
    logger.info(f"Total configurations to process: {len(FILE_PATH_CONFIG)}")
    logger.info(f"Initial memory usage: {initial_memory:.1f} MB")
    logger.info("=" * 80)
    
    parent_folder = Path(OCEAN_CURRENT_FILE_ROOT_PATH)
    
    # Verify root path exists
    if not parent_folder.exists():
        logger.error(f"Root path does not exist: {parent_folder}")
        sys.exit(1)
    
    logger.info(f"Root path verified: {parent_folder}")
    
    total_files_processed = 0
    successful_configs = 0
    failed_configs = []
    
    try:
        for idx, config in enumerate(FILE_PATH_CONFIG, 1):
            product_id = config['productId']
            progress_pct = (idx / len(FILE_PATH_CONFIG)) * 100
            elapsed_time = time.time() - start_time
            
            logger.info(f"[{progress_pct:.1f}%] Processing configuration {idx}/{len(FILE_PATH_CONFIG)}: {product_id}")
            logger.debug(f"Elapsed time: {elapsed_time:.1f}s, Files processed so far: {total_files_processed}")
            
            try:
                config_start_time = time.time()
                scanned_files = scan_files_from_config(
                    parent_directory=parent_folder,
                    config=config
                )
                config_duration = time.time() - config_start_time
                
                if len(scanned_files) > 0:
                    logger.info(f"✓ Configuration {product_id}: Found {len(scanned_files)} files in {config_duration:.2f} seconds")
                    save_result_as_json(scanned_files, config, parent_folder)
                    successful_configs += 1
                    total_files_processed += len(scanned_files)
                    
                    # Log progress every 5 configurations
                    if idx % 5 == 0 or idx == len(FILE_PATH_CONFIG):
                        current_memory = get_memory_usage()
                        memory_delta = current_memory - initial_memory
                        avg_files_per_config = total_files_processed / successful_configs if successful_configs > 0 else 0
                        estimated_remaining = (len(FILE_PATH_CONFIG) - idx) * (elapsed_time / idx) if idx > 0 else 0
                        logger.info(f"Progress checkpoint - Processed: {idx}/{len(FILE_PATH_CONFIG)} configs, "
                                  f"Total files: {total_files_processed}, Avg files/config: {avg_files_per_config:.1f}, "
                                  f"Est. remaining time: {estimated_remaining:.1f}s, "
                                  f"Memory: {current_memory:.1f}MB (+{memory_delta:+.1f}MB)")
                else:
                    logger.warning(f"⚠ Configuration {product_id}: No files found matching criteria")
                    
            except Exception as e:
                logger.error(f"✗ Configuration {product_id} failed: {str(e)}")
                logger.error(f"Configuration {product_id} traceback: {traceback.format_exc()}")
                failed_configs.append(product_id)
                
    except Exception as e:
        logger.error(f"Critical error during processing: {str(e)}")
        logger.error(f"Critical error traceback: {traceback.format_exc()}")
        sys.exit(1)
    
    # Summary and shutdown logging
    end_time = time.time()
    total_duration = end_time - start_time
    final_memory = get_memory_usage()
    peak_memory_delta = final_memory - initial_memory
    
    logger.info("=" * 80)
    logger.info("EXECUTION SUMMARY:")
    logger.info(f"Total execution time: {total_duration:.2f} seconds")
    logger.info(f"Total configurations processed: {len(FILE_PATH_CONFIG)}")
    logger.info(f"Successful configurations: {successful_configs}")
    logger.info(f"Failed configurations: {len(failed_configs)}")
    if failed_configs:
        logger.info(f"Failed configuration IDs: {', '.join(failed_configs)}")
    logger.info(f"Total files processed: {total_files_processed}")
    logger.info(f"Average files per successful config: {total_files_processed/max(successful_configs, 1):.1f}")
    logger.info(f"Average processing rate: {total_files_processed/total_duration:.1f} files/second")
    logger.info(f"Memory usage - Initial: {initial_memory:.1f}MB, Final: {final_memory:.1f}MB, Delta: {peak_memory_delta:+.1f}MB")
    logger.info(f"COMPLETED: {script_name}")
    logger.info("=" * 80)
    
    if failed_configs:
        logger.error(f"Script completed with {len(failed_configs)} failed configurations")
        sys.exit(1)
    else:
        logger.info("Script completed successfully")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        logger.warning("Script interrupted by user (SIGINT)")
        sys.exit(130)
    except Exception as e:
        logger.error(f"Unhandled exception: {str(e)}")
        logger.error(f"Unhandled exception traceback: {traceback.format_exc()}")
        sys.exit(1)
