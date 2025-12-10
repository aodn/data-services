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
import requests

# Define the absolute path of the file directory root path
# Use local test data if DEV_MODE environment variable is set
base_path = "/mnt/oceancurrent/website/"
if os.getenv("DEV_MODE") == "true":
    OCEAN_CURRENT_FILE_ROOT_PATH = f"./ARGO/oceancurrent/tests{base_path}"
else:
    OCEAN_CURRENT_FILE_ROOT_PATH = base_path

# EC2 Instance Metadata Service endpoints (IMDSv2)
METADATA_BASE_URL = "http://169.254.169.254/latest"
IMDS_TOKEN_URL = f"{METADATA_BASE_URL}/api/token"
INSTANCE_IDENTITY_PKCS7_URL = f"{METADATA_BASE_URL}/dynamic/instance-identity/pkcs7"

# Backend API endpoint for fatal log notifications
# Reads from config file or environment variable (config file takes precedence)
# Config file location: /etc/imos/oc_api_endpoint.conf or ./oc_api_endpoint.conf
def _load_api_endpoint():
    """Load API endpoint from config file or environment variable."""
    # Try config file locations (in order of preference)
    config_locations = [
        "/etc/imos/oc_api_endpoint.conf",  # System-wide config
        os.path.join(os.path.dirname(__file__), "oc_api_endpoint.conf"),  # Local to script
    ]

    for config_file in config_locations:
        if os.path.exists(config_file):
            try:
                with open(config_file, 'r') as f:
                    endpoint = f.read().strip()
                    if endpoint:
                        return endpoint
            except Exception:
                pass  # Try next location

    # Fallback to environment variable
    return os.getenv("OC_API_ENDPOINT")

OC_API_ENDPOINT = _load_api_endpoint()

# Metadata service timeout
METADATA_TIMEOUT = 2  # seconds
IMDS_TOKEN_TTL_SECONDS = 21600  # 6 hours

# Global cache for PKCS7 signature (fetched once at startup)
_cached_pkcs7 = None

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


def get_imds_token():
    """
    Fetch IMDSv2 session token for secure metadata access.

    Returns:
        Token string or None on error
    """
    try:
        response = requests.put(
            IMDS_TOKEN_URL,
            headers={"X-aws-ec2-metadata-token-ttl-seconds": str(IMDS_TOKEN_TTL_SECONDS)},
            timeout=METADATA_TIMEOUT
        )
        response.raise_for_status()
        return response.text
    except requests.exceptions.RequestException:
        return None


def fetch_instance_identity():
    """
    Fetch PKCS7 signature from EC2 metadata service.
    Uses IMDSv2 for enhanced security, with fallback to IMDSv1.

    Returns:
        PKCS7 signature string or None on error
    """
    try:
        # Get IMDSv2 token (optional, will fallback to IMDSv1 if unavailable)
        token = get_imds_token()
        headers = {}
        if token:
            headers["X-aws-ec2-metadata-token"] = token

        # Fetch PKCS7 signature
        pkcs7_response = requests.get(
            INSTANCE_IDENTITY_PKCS7_URL,
            headers=headers,
            timeout=METADATA_TIMEOUT
        )
        pkcs7_response.raise_for_status()
        return pkcs7_response.text

    except requests.exceptions.RequestException:
        return None


def send_fatal_log(error_message, source_type=None, additional_context=None):
    """
    Send fatal log notification to the monitoring API.
    Uses cached PKCS7 signature for authentication.

    Args:
        error_message: The error message to send
        source_type: Optional source type identifier (e.g., 'startup', 'scan', 'config')
        additional_context: Optional additional context information

    Returns:
        True if successful, False otherwise
    """
    global _cached_pkcs7

    # Skip if API endpoint is not configured
    if not OC_API_ENDPOINT:
        logger.debug("Skipping fatal log notification - API endpoint not configured")
        return False

    # Skip if we don't have a valid PKCS7 signature (not running on EC2 or disabled)
    if not _cached_pkcs7:
        logger.debug("Skipping fatal log notification - No PKCS7 signature available")
        return False

    # Determine source identifier
    script_name = os.path.basename(__file__)
    if source_type:
        source = f"oceancurrent-file-server-api/{source_type}"
    else:
        source = "oceancurrent-file-server-api"

    # Build context with additional info
    context_parts = [
        f"script={script_name}",
        f"pid={os.getpid()}",
        f"python={sys.version.split()[0]}"
    ]
    if additional_context:
        context_parts.append(additional_context)
    context = ", ".join(context_parts)

    payload = {
        "pkcs7": _cached_pkcs7,
        "timestamp": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "errorMessage": error_message,
        "source": source,
        "context": context
    }

    try:
        logger.info(f"Sending fatal log notification to monitoring API: {OC_API_ENDPOINT}")
        logger.debug(f"Fatal log message: {error_message[:100]}...")  # Log first 100 chars

        response = requests.post(
            OC_API_ENDPOINT,
            json=payload,
            headers={"Content-Type": "application/json"},
            timeout=10
        )

        if response.status_code == 200:
            logger.info(f"✓ Fatal log notification sent successfully (HTTP {response.status_code})")
            return True
        else:
            logger.warning(f"✗ Fatal log notification failed with HTTP {response.status_code}")
            try:
                error_detail = response.json()
                logger.warning(f"API response: {error_detail.get('message', 'Unknown error')}")
            except:
                logger.warning(f"API response: {response.text[:200]}")
            return False

    except requests.exceptions.Timeout:
        logger.warning("✗ Fatal log notification failed - Request timeout")
        return False
    except requests.exceptions.RequestException as e:
        logger.warning(f"✗ Fatal log notification failed - Request error: {str(e)}")
        return False


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
    global _cached_pkcs7
    start_time = time.time()
    script_name = os.path.basename(__file__)
    initial_memory = get_memory_usage()

    # Fetch EC2 instance identity for fatal log notifications
    if not OC_API_ENDPOINT:
        logger.info("Fatal log notifications disabled - API endpoint not configured")
        logger.info("To enable: Create /etc/imos/oc_api_endpoint.conf or ./oc_api_endpoint.conf with the API endpoint URL")
        _cached_pkcs7 = None
    else:
        _cached_pkcs7 = fetch_instance_identity()
        if _cached_pkcs7:
            logger.info(f"Fatal log notifications enabled - API endpoint: {OC_API_ENDPOINT}")
        else:
            logger.info("Fatal log notifications disabled - EC2 instance identity not available (not running on EC2 or metadata service unavailable)")

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
        error_msg = f"Root path does not exist: {parent_folder}"
        logger.error(error_msg)
        send_fatal_log(error_msg, source_type="startup", additional_context="validation=root_path")
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
                error_msg = f"✗ Configuration {product_id} failed: {str(e)}"
                logger.error(error_msg)
                send_fatal_log(error_msg, source_type="scan", additional_context=f"product_id={product_id}")
                traceback_msg = f"Configuration {product_id} traceback: {traceback.format_exc()}"
                logger.error(traceback_msg)
                failed_configs.append(product_id)

    except Exception as e:
        error_msg = f"Critical error during processing: {str(e)}"
        logger.error(error_msg)
        send_fatal_log(error_msg, source_type="scan", additional_context="error_type=critical")
        traceback_msg = f"Critical error traceback: {traceback.format_exc()}"
        logger.error(traceback_msg)
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
        error_msg = f"Script completed with {len(failed_configs)} failed configurations"
        logger.error(error_msg)
        send_fatal_log(error_msg, source_type="completion", additional_context=f"failed_count={len(failed_configs)}, failed_ids={','.join(failed_configs[:5])}")
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
        error_msg = f"Unhandled exception: {str(e)}"
        logger.error(error_msg)
        send_fatal_log(error_msg, source_type="unhandled", additional_context=f"exception_type={type(e).__name__}")
        traceback_msg = f"Unhandled exception traceback: {traceback.format_exc()}"
        logger.error(traceback_msg)
        sys.exit(1)
