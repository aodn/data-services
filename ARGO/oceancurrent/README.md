# ARGO Profiles JSON Generator for the Ocean Current website

This script processes directories containing `.gif` files and generates a `profiles.json` file per argo platform directory with metadata extracted from the filenames. The filenames follow a specific pattern, and the extracted information includes the date, profile number, and cycle number.

## Directory Structure

The script expects a directory structure as follows:

/mnt/oceancurrent/website/profiles/
├── platform_code1/
│ ├── YYYYMMDD_profileNumber_cycleNumber.gif
│ ├── YYYYMMDD_profileNumber_cycleNumber.html
│ └── ...
├── platform_code2/
│ ├── YYYYMMDD_profileNumber_cycleNumber.gif
│ ├── YYYYMMDD_profileNumber_cycleNumber.html
│ └── ...
└── ...


Where:
- `YYYYMMDD` is the date.
- `profileNumber` is the profile number.
- `cycleNumber` is the cycle number.

## Script Overview

The script performs the following steps:
1. Lists all platform codes in the specified `PROFILES_PATH` directory.
2. For each platform code, lists all files in the corresponding directory.
3. Filters the filenames to include only `.gif` files.
4. Extracts the date, profile number, and cycle number from each filename using a regular expression.
5. Creates a `profiles.json` file per directory containing the extracted information.

## Usage

### Running the Script

1. Confirm the `PROFILES_PATH` variable in the script to point to the base directory containing the platform code directories.
2. Run the script using Python as a cronjob:

```bash
python3 argo_oceancurrent.py
```

## Unittesting
Run the unittests with ```pytest```

# File Server API for JSON Generator for the Ocean Current website
Script `oceancurrent_file_server_api.py` is used for scanning `.gif` files in the Ocean Current file server for selected subproducts and products. JSON files are generated as per subproducts. The JSON file format is designed as below:
```JSON
[
    {
        "path": "/SST_4hr/SST/Adelaide", # /{product folder}/{subproduct folder}/{region}
        "productId": "fourHourSst-sst", # subproduct ID which align with Ocean Current front-end https://github.com/aodn/ocean-current-frontend/blob/main/src/constants/product.ts
        "region": "Adelaide", # region folder
        "depth": null, # this is used for some products which contains depth attribute
        "files": [
            {
                "name": "2024041918.gif" # scanned gif file existed in the file path "/SST_4hr/SST/Adelaide"
            }
        ]
    },
    {
        "path": "/SST_4hr/SST/SAgulfs",
        "productId": "fourHourSst-sst",
        "region": "SAgulfs",
        "depth": null,
        "files": [
            {
                "name": "2024051010.gif"
            }
        ]
    }
]
```

**A selected product** is a product which has been implemented on Ocean Current website. Similarly, **a selected subproduct** is a subproduct which has been implemented on Ocean Current website. To scan the `.gif` files under particular product folders, `FILE_PATH_CONFIG` should be a dictionary in which has the file path configurations.

The following pseudo code explain the scanning logic:
```
FUNCTION recursive_scan(folder, current_layer, include_rules, max_layer, filetype_mode, filetype_pattern):
    INITIALIZE empty list results
    
    # 1. If scan finished, i.e., reach the max_layer, stop the scanning
    IF current_layer > max_layer:
        RETURN results

    # 2. If there’s a filter for this layer, and the folder name doesn’t match it, skip it
    IF include_rules contains key current_layer:
        IF folder.name does NOT match ANY pattern in include_rules[current_layer]:
            RETURN results

    # 3. Otherwise, walk through each entry in this folder
    FOR EACH item IN list_directory(folder):
        IF item is a directory:
            # 4. only recurse further if we haven’t hit max depth
            IF current_layer < max_layer:
                CALL recursive_scan(item,
                                    current_layer + 1,
                                    include_rules,
                                    max_layer,
                                    filetype_mode,
                                    filetype_pattern)
                APPEND all returned paths into results

        ELSE IF item is a file:
            # 5. collect files exactly at max_layer
            IF current_layer == max_layer:
                IF filetype_mode == "suffix":
                    IF file’s extension equals filetype_pattern:
                        ADD item to results
                ELSE:
                    IF file’s name matches filetype_pattern (regex):
                        ADD item to results
    # 6. save the scanned files in memory for further generating JSON
    RETURN results

```

Global variable `FILE_PATH_CONFIG` should be defined at the beginning of the script. A `FILE_PATH_CONFIG` is a list of dictories of pre-defined congirations for selected products. It should strictly with these fields:

field | description | example value
----|----|----|
`productId` | String. The product ID defined in Ocean Current front-end https://github.com/aodn/ocean-current-frontend/blob/main/src/constants/product.ts. **Note:** use the key from the children | `fourHourSst-sstFilled`
`include` | List. Specify the folder name and the layer that needed to be included in the scanning. **Note:** supports regex. The format should be a list of dict. | `"include":{"path": "SST_4hr", "layer": 1},{"path": "SST_Filled", "layer": 2}]`
`filetype` | String. Specify the file type that needed to be scanned. In string format. Can be a suffix, a fixed file name, or a regex. | `"^T_.*.gif$"`
`max_layer` | Integer. The index of last subfolder that need to be scanned. For example, a gif file stored in "\Product\Subproduct\Region\example.gif" (a relative path to the root path of the file system). The `max_layer` is 3. | 3

Optional fields include:

- `region_layer`: Integer. The layer which indicates the regions of the product. For example, given a path "\Product\Subproduct\Region\example.gif", the `region_layer` is 3.
- `depth_layer`: Integer. The layer which indicates the depth of the product. For example, given a path "\Product\Subproduct\Region\Depth\example.gif", the `depth_layer` is 4.
- `save_in_product_folder`: Boolean. True as save the generated JSON file in the product folder. In some cases, there is no product folder but only regional folders in the root path, in that case, the JSON file will be stored at the root path of the file system. 

## Supporting Products
Currently, the script is adaptive to these products:

|subproduct | saved path|
| ---- | ---- | 
|**Four hour SST** | |
`fourHourSst-sstFilled` | `\SST_4hr\SST_Filled\SST_Filled.json`
`fourHourSst-sst` | `\SST_4hr\SST\SST.json`
`fourHourSst-sstAge` | `\SST_4hr\SST_Age\SST_Age.json`
`fourHourSst-windSpeed` | `\SST_4hr\Wind\Wind.json`
| **6-Day SST & Centiles** | |
`sixDaySst-sst` | `DR_SST_daily\SST\SST.json` and `STATE_daily\SST\SST.json`
`sixDaySst-sstAnomaly` | `\DR_SST_daily\SST_ANOM\SST_ANOM.json` and `\STATE_daily\SST_ANOM\SST_ANOM.json`
`sixDaySst-centiles` | `\DR_SST_daily\pctiles\pctiles.json` and `\STATE_daily\pctiles\pctiles.json`
| **SealCTD** | | 
`sealCtd-sealTrack` | `\AATAMS\sealCtd-sealTrack.json`
`sealCtd-sealTrack-video` | `\AATAMS\sealCtd-sealTrack-video.json`
`sealCtd-timeseriesTemperature` | `AATAMS\sealCtd-timeseriesTemperature.json`
`sealCtd-timeseriesSalinity` | `\AATAMS\sealCtd-timeseriesSalinity.json`
| **Adjusted Sea Level Anom.** | |
`adjustedSeaLevelAnomaly-sla` | `\STATE_daily\SLA\SLA.json`
`adjustedSeaLevelAnomaly-centiles` | `\STATE_daily\SLA_pctiles\SLA_pctiles.json`
`adjustedSeaLevelAnomaly-sst` | `\adjustedSeaLevelAnomaly-sst.json` and `\adjustedSeaLevelAnomaly-sst-year.json`
| **Ocean Color** | |
`oceanColour-chlA` | `\STATE_daily\CHL\CHL.json` and `\oceanColour-chlA.json` and `\oceanColour-chlA-year.json`
`oceanColour-chlAAge` | `\STATE_daily\CHL_AGE\CHL_AGE.json`
| **Current Meters** | | 
`currentMetersCalendar-48` | `\timeseries\currentMetersCalendar-48.json`
`currentMetersCalendar-49` | `\timeseries\currentMetersCalendar-49.json`
`currentMetersRegion-48` | `\timeseries\currentMetersRegion-48.json`
`currentMetersRegion-49` | `\timeseries\currentMetersRegion-49.json`
`currentMetersPlot-48` | `\timeseries\currentMetersPlot-48.json`
`currentMetersPlot-49` | `\timeseries\currentMetersPlot-49.json`


## Gliders asset indexes

The scanner discovers legacy assets under `/mnt/oceancurrent/website/gliders/`.
These proposed product IDs follow the existing `product-subproduct` convention;
registering the JSON files in `ocean-current-api` is a separate future task.
This change does not register products in the API, frontend or Elasticsearch.

| Proposed product ID | JSON path relative to the website root | Supported assets |
| --- | --- | --- |
| `gliders-mission` | `/gliders/gliders-mission.json` | Standard mission GIFs |
| `gliders-mission-video` | `/gliders/gliders-mission-video.json` | Standard mission MP4s |
| `gliders-navigation` | `/gliders/gliders-navigation.json` | Navigation GIFs |
| `gliders-navigation-video` | `/gliders/gliders-navigation-video.json` | Navigation MP4s, when available |
| `gliders-ts` | `/gliders/gliders-ts.json` | GIFs directly under `missionTS/` |
| `gliders-yearmaps` | `/gliders/gliders-yearmaps.json` | GIFs directly under `yearmaps/` |

Mission directories begin with an ASCII letter, followed by letters, digits,
underscores or hyphens and an eight-digit mission date. The date may have a
single-letter mission suffix (for example `Brisbane20180306A` or
`JervisBay20180503a`) or an observed numeric leg `_1` / `_2` (for example
`Perth20110626_1`). The visualisation period is `_4d`, `_12d` or `_30d`.
An optional `_nrt` may occur before **or** after the period, but not both:

- `TasEastCoast20260922_nrt_4d`
- `Brisbane20180306A_4d`
- `Perth20110626_1_4d`
- `Cooktown20160217_4d_nrt`

Navigation directories use exactly the same validation with a `nav` prefix.
Anchored patterns exclude `nav*` from standard missions, unsupported periods
and unrecognised directory suffixes. Only files directly inside the matched
directories are scanned. Extensions are case insensitive; HTML, JSON and PHP
files are excluded.

A read-only inventory on 16 October 2026 contained 2,900 directories. The
updated rules match 2,133 standard and 603 navigation directories, adding 52
and 18 respectively. All 42 previously excluded directories linked by the
legacy catalogue now match (all 1,362 distinct linked mission directories are
covered). Those 42 names are retained as a regression fixture in
`fixtures/gliders_historical_missions.txt`. The inventory was checked locally;
no production scanner or production filesystem writes were used.

In addition to the supported `missionTS/` and `yearmaps/`, 162 directories remain
excluded deliberately:

| Directory category | Count | Reason |
| --- | ---: | --- |
| `_tsfoa` | 126 | Separate scientific variant, outside the canonical products |
| `_vtsfc` | 14 | Separate scientific variant |
| `_vtTsS` / `_vtsTS` | 10 | Separate scientific variants |
| `_10d` | 3 | Outside the requested 4/12/30-day periods |
| `missionTS_*` / `yearmaps_*` | 9 | Development, alternate or junk folders; only exact canonical folders are enabled |

Each mission directory is preserved in `path` and used verbatim as `region`.
This is a mission/version identifier, not a geographic region parsed from the
name. Period and NRT status remain encoded in that identifier. `depth` is
always null. T-S and annual-map records have null `region` and `depth` because
the scanner does not extract metadata from their filenames. For example,
`gliders-mission.json` can contain:

```json
[
    {
        "path": "/gliders/TasEastCoast20260922_nrt_4d",
        "productId": "gliders-mission",
        "region": "TasEastCoast20260922_nrt_4d",
        "depth": null,
        "files": [{"name": "2026101500.gif"}]
    }
]
```

Identical filenames in different missions remain in separate records. Missing
periods or animations are simply absent; no complete set of periods is assumed.
The existing runner writes an index only when matching assets exist. It does
not remove an old index if all matching assets subsequently disappear.

### Scheduled scanner impact

After deployment, the existing scheduled scanner automatically processes six
additional configurations, appended after all existing products. No schedule
or scientific generation changes are required. `save_in_product_folder` writes
up to six uniquely named indexes under `gliders/`, replacing those indexes on
subsequent runs. It does not overwrite other product indexes or source assets.

Each configuration lists the website root and `gliders/`, but only opens
matching asset directories, with a maximum directory depth of two. Mission
folders are listed twice (GIF and MP4); asset contents are never read.
Memory scales with matching paths and the generated records for a configuration.
The existing JSON grouping searches records linearly, so many missions and
frames can also increase generation time. No shared scanner behavior was changed.

The opt-in local benchmark is reproducible with:

```bash
TMPDIR=/var/tmp python3 ARGO/oceancurrent/benchmark_gliders.py
```

Use a local temporary filesystem with capacity for about 2.4 million directory
entries. Each scenario uses a fresh subprocess and runs all 48 configurations
through `main()`, with existing development fixtures plus synthetic Gliders.
The no-Gliders baseline runs the same configurations with development fixtures
only. Fixture creation and cleanup are excluded from timing and worker peak RSS.
Monitoring/metadata requests are disabled. No production scanner is invoked.

Both Gliders scenarios contain 2,133 standard and 603 navigation directories,
including historical naming forms and incomplete periods. Each GIF has a paired
ignored HTML file; every directory also has ignored PHP/JSON files. Twenty
percent of directories lack MP4s. There are 760 T-S and 210 annual GIFs.
The deterministic frame distributions repeat every 100 directories:

- Representative: 65% have 24 GIFs, 25% have 100, 8% have 352, and 2% have 913.
- Higher load: 25% have 100 GIFs, 50% have 352, and 25% have 913.

These are illustrative distributions using observed counts, not a census of
production frames. The higher-load case is a stress scenario, not an absolute
upper bound. Synthetic files are empty hard links; only names and metadata are
used by the scanner. Measurements on local disk with warm filesystem caches
and no CPU throttle, on 16 October 2026:

| Measurement | No Gliders baseline | Representative | Higher load |
| --- | ---: | ---: | ---: |
| Total scanner wall time, all 48 configurations | 0.009 s | 11.66 s | 58.91 s |
| Process CPU time | 0.009 s | 11.66 s | 58.86 s |
| Gliders scanning | 0.0005 s | 3.67 s | 17.52 s |
| Gliders JSON generation | 0 s | 7.92 s | 41.13 s |
| Peak process RSS | 31.3 MiB | 262.1 MiB | 1,167.9 MiB |
| Matched Gliders assets | 0 | 238,976 | 1,167,749 |
| Generated Gliders JSON size | 0 | 16.97 MiB | 78.97 MiB |

| Index | Representative assets | Higher-load assets | Representative JSON | Higher-load JSON |
| --- | ---: | ---: | ---: | ---: |
| `gliders-mission` | 183,534 | 906,741 | 13,284,209 bytes | 63,908,699 bytes |
| `gliders-mission-video` | 1,706 | 1,706 | 504,447 bytes | 504,447 bytes |
| `gliders-navigation` | 52,284 | 257,850 | 3,788,006 bytes | 18,177,626 bytes |
| `gliders-navigation-video` | 482 | 482 | 147,354 bytes | 147,354 bytes |
| `gliders-ts` | 760 | 760 | 52,493 bytes | 52,493 bytes |
| `gliders-yearmaps` | 210 | 210 | 14,548 bytes | 14,548 bytes |

The observed existing production baseline was 657 seconds and approximately
1,135 MiB peak RSS, processing about 5.8 million assets. Live cron runs every
two hours with a 50% CPU limit; about 6.7 GB RAM was available at inspection.
The local total times above include only development fixtures for existing
products, **not** the full production workload. As an illustrative allowance,
doubling the added local wall time for the CPU limit gives about 23 seconds
representative / 118 seconds higher load. Adding those to the production
baseline gives approximately 680 / 775 seconds (11.3 / 12.9 minutes), increases
of 3.5% / 17.9%, within the two-hour interval. This scaling is not a measured
production prediction: hardware, cache state, hard-linked metadata and concurrent
filesystem I/O differ. Even budgeting both the old and higher-load memory peaks
additively is roughly 2.3 GiB, below the previously observed available RAM.

JSON generation accounts for about 68–70% of added runtime. Grouping currently
searches earlier records for each file, costing O(files × directory records).
This is measurable overhead but does not justify a shared scanner change for
these measured workloads and scheduling headroom. If real growth makes it a
bottleneck, the smallest separate optimisation is a dictionary keyed by
`(region, path)` while retaining the existing output list, record order and JSON
schema. No shared scanning or grouping functions were changed here.

The measured scenarios support deployment without a resource blocker. Check
duration and memory logs after the first normal scheduled run; production I/O
cost and future growth are still uncertainties. Merging activates the new
configurations on the next run because cron downloads the script from `master`.
No cron, deployment or scientific pipeline changes are included.

Gliders permission, read or write failures use existing per-configuration error
handling: other configurations continue, but the job ultimately exits nonzero
and may send the existing monitoring notification. Missing Gliders directories
produce no matches and no writes. Resource exhaustion or overlapping scheduled
runs remain possible if the real workload exceeds available headroom; appending
Gliders and limiting traversal reduce interference but do not isolate resources.

Run the local OceanCurrent tests (all fixtures are copied or built in temporary
directories) with:

```bash
python3 -m unittest discover -s ARGO/oceancurrent -p 'test_*.py'
```
