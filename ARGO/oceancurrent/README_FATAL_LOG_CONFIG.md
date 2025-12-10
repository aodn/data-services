# Fatal Log Monitoring Configuration

## Overview

The `oceancurrent_file_server_api.py` script supports sending fatal error notifications to a monitoring API endpoint using EC2 instance identity authentication.

## Configuration

The API endpoint is configured via a simple text file: `oc_api_endpoint.conf`

### Setup on EC2

Create the configuration file with your monitoring API endpoint:

```bash
# Create directory
sudo mkdir -p /etc/imos

# Create config file with API endpoint
echo "https://replace-to-the-production-domain/api/v1/monitoring/fatal-log" | sudo tee /etc/imos/oc_api_endpoint.conf

# Set proper permissions (readable by all, writable only by root)
sudo chown root:root /etc/imos/oc_api_endpoint.conf
sudo chmod 644 /etc/imos/oc_api_endpoint.conf
```

### Verify Setup

```bash
# Check file exists and has correct permissions
ls -l /etc/imos/oc_api_endpoint.conf
# Expected: -rw-r--r-- 1 root root 69 Dec 10 10:00 /etc/imos/oc_api_endpoint.conf

# Check content
cat /etc/imos/oc_api_endpoint.conf
# Should display: https://replace-to-the-production-domain/api/v1/monitoring/fatal-log

# Test if cron user can read it
sudo -u projectofficer cat /etc/imos/oc_api_endpoint.conf
```

## How It Works

The script automatically looks for the config file in these locations (in order):

1. `/etc/imos/oc_api_endpoint.conf` (system-wide - **recommended**)
2. `./oc_api_endpoint.conf` (local to script)
3. `OC_API_ENDPOINT` environment variable (fallback)

If no configuration is found, fatal log notifications are **gracefully disabled** and the script continues to run normally.

## Authentication

The script uses **EC2 Instance Identity Document** (PKCS7 signature) for authentication:

- Automatically fetched from EC2 metadata service (IMDSv2 with IMDSv1 fallback)
- Cryptographically verifiable by the backend
- Cannot be spoofed from outside AWS
- No credentials needed in the config file

## Behavior

### When Configured ✅

On script startup, you'll see:

```
INFO: EC2 instance identity fetched successfully
INFO: Fatal log notifications enabled - API endpoint: https://...
```

When errors occur:

```
INFO: Sending fatal log notification to monitoring API: https://...
INFO: ✓ Fatal log notification sent successfully (HTTP 200)
```

### When Not Configured ⚠️

On script startup, you'll see:

```
INFO: Fatal log notifications disabled - API endpoint not configured
INFO: To enable: Create /etc/imos/oc_api_endpoint.conf or ./oc_api_endpoint.conf with the API endpoint URL
```

The script **continues to run normally** - only the notifications are disabled.

### When EC2 Metadata Unavailable (Not on EC2) 🖥️

```
INFO: Fatal log notifications disabled - EC2 instance identity not available (not running on EC2 or metadata service unavailable)
```

## Update the Endpoint

To change the API endpoint, simply edit the config file:

```bash
# Method 1: Direct echo
echo "https://new-endpoint.example.com/api/v1/monitoring/fatal-log" | sudo tee /etc/imos/oc_api_endpoint.conf

# Method 2: Edit with text editor
sudo nano /etc/imos/oc_api_endpoint.conf
```

## Security

### File Permissions

The config file should be:

- **Readable by all** users (so the cron job can read it)
- **Writable only by root** (to prevent unauthorized modification)

```bash
# Correct permissions: -rw-r--r-- (644)
sudo chmod 644 /etc/imos/oc_api_endpoint.conf
```
