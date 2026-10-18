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

The scanner discovers assets under `/mnt/oceancurrent/website/gliders/`.
Registering these proposed product IDs in `ocean-current-api` is a separate
future task; this change does not integrate Gliders into the API or frontend.

| Product ID | JSON path relative to the website root | Assets |
| --- | --- | --- |
| `gliders-mission` | `/gliders/gliders-mission.json` | Standard mission GIFs |
| `gliders-mission-video` | `/gliders/gliders-mission-video.json` | Standard mission MP4s |
| `gliders-navigation` | `/gliders/gliders-navigation.json` | Navigation GIFs |
| `gliders-navigation-video` | `/gliders/gliders-navigation-video.json` | Navigation MP4s |
| `gliders-ts` | `/gliders/gliders-ts.json` | GIFs directly under `missionTS/` |
| `gliders-yearmaps` | `/gliders/gliders-yearmaps.json` | GIFs directly under `yearmaps/` |

Mission directory names start with a letter and contain letters, digits,
underscores or hyphens, followed by an eight-digit mission date. The date can
have a single-letter suffix or a `_1` / `_2` mission leg. Supported periods are
`_4d`, `_12d` and `_30d`, with optional `_nrt` before or after the period:

- `TasEastCoast20260922_nrt_4d`
- `Brisbane20180306A_4d`
- `JervisBay20180503a_nrt_12d`
- `Perth20110626_1_4d`
- `Cooktown20160217_4d_nrt`

Navigation directories use the same format with a `nav` prefix and are excluded
from standard mission indexes. Only files directly inside matching directories
are indexed. GIF and MP4 extensions are case insensitive; HTML, JSON, PHP,
unsupported periods, scientific variant suffixes and auxiliary folders are excluded.
Missing periods or animations are allowed. An index is written only when matching
assets exist; the existing scanner does not remove stale indexes when assets disappear.

Each mission directory is preserved in `path` and used verbatim as `region`,
so identical filenames from different missions remain distinguishable. `depth`
is null; T-S and annual-map records also have null `region`. Example record:

```json
{
    "path": "/gliders/TasEastCoast20260922_nrt_4d",
    "productId": "gliders-mission",
    "region": "TasEastCoast20260922_nrt_4d",
    "depth": null,
    "files": [{"name": "2026101500.gif"}]
}
```

Merging activates these configurations on the next scheduled run because the
production job downloads the scanner from `master`. Gliders runs after existing
products and writes up to six indexes under `gliders/`; check the existing runtime
and memory logs after deployment. No cron or deployment changes are required.

## Gliders mission catalogue

`gliders_catalogue.py` independently converts the four mission tables in the
legacy catalogue into `gliders/gliders-catalogue.json`, relative to the website
root. This contains mission metadata, **not** the generic image inventory schema;
do not add it to `FILE_PATH_CONFIG` or the generic API image-index configuration.
API integration is a separate task.

The source is `/mnt/oceancurrent/website/gliders/index.html`, published at
<https://oceancurrent.aodn.org.au/gliders/index.html>. A search of this repository
and its documented OceanCurrent pipeline found no maintained structured source
for this catalogue. Existing Gliders GIF/MP4 indexes describe assets, not mission
metadata. The parser uses the existing `beautifulsoup4` dependency with Python's
HTML parser; it does not fetch remote resources or inspect scientific files.

### JSON schema (version 1)

The top-level object contains `schema_version`, `source_url`, `missions` and
`orders`. `missions` is an array sorted by `id`, with one record per exact
published mission name and processing-version string. Optional scalar fields are
`null`; unavailable visualisations are empty arrays.

| Field | Meaning |
| --- | --- |
| `id` | URL-quoted exact `mission_name`, then `@`, then URL-quoted `processing_version` (or `unknown` when absent). Stable for that published name/version; independent of catalogue row numbering. |
| `mission_name` | Exact catalogue name, including historical case, leg and `_nrt` suffixes. |
| `mission_id` | Name with only the terminal `_nrt` removed, to associate NRT and non-NRT publications. Other suffixes remain significant. This is a catalogue identity, not a scientific deployment identifier. |
| `catalogue_numbers` | All original `N` values for this record, as numerically sorted strings. Identical rows sometimes have different numbers. |
| `processing_version` | Exact processing text with surrounding whitespace removed, e.g. `5.00`, `3.0.` or `5.`. Never converted to a number. |
| `is_nrt` | Boolean based on the catalogue's terminal `_nrt` naming convention. False means a non-NRT catalogue publication; it does not independently certify scientific quality or delayed-mode status. |
| `dates_raw` | Original deployment date text with whitespace normalised. Always retained, even when parsing fails. |
| `start_date`, `end_date` | ISO dates for recognised `DD Mon - DD Mon YYYY` ranges. The trailing year is the end year; a wrapped month uses the previous start year. Unrecognised or invalid ranges leave both null. No dates are inferred from mission names. |
| `latitude`, `longitude` | Signed decimal degrees: the catalogue's degrees south become negative latitude; degrees east retain their sign. Header units are checked before conversion. |
| `duration_days`, `distance_travelled_km` | Nonnegative numeric values from `days` and `km`. The latter is travelled distance, **not** distance alongshore to Darwin. Nonfinite and out-of-range numbers become null. |
| `glider_id` | Published glider identifier. |
| `visualisations` | `details` and `animations` arrays of `{ "label": "4", "url": "https://..." }`. Labels and linked targets are preserved, including available 4/12/30-day pages and MP4s; no missing periods are invented. |
| `temperature_salinity_url` | Published T-S reference, which can be an HTML page rather than an image. |
| `scientific_data_url` | Published mission scientific data link only; null if absent. |

`orders` maps `deployment_date`, `mission_name`,
`distance_alongshore_to_darwin` and `event_based_sampling` to ordered arrays of
record IDs. These retain the first occurrence in each respective source table,
including its membership omissions. Event membership and alongshore ordering
must use these lists; no numeric distance-to-Darwin is inferred. Year headings
and totals are excluded. Repeated occurrences do not duplicate a record or its
position within a view. These orders may have different lengths.

### Local execution and tests

Use an environment with the repository's `beautifulsoup4` dependency installed.
Both paths are required to prevent an accidental production run; the output's
parent directory must already exist. For example, using a local source copy:

```bash
python3 ARGO/oceancurrent/gliders_catalogue.py \
  --input /tmp/gliders-index.html \
  --output /tmp/gliders-catalogue.json
python3 -m pytest -q ARGO/oceancurrent/test_gliders_catalogue.py
```

The standard library runner is also supported:

```bash
cd ARGO/oceancurrent
python3 -m unittest test_gliders_catalogue
```

`--source-url` optionally changes the base used to resolve relative links; local
input paths never become public URLs. Output is deterministic for identical
input and base URL, with no generated timestamp. The generator parses and
validates before writing, uses a temporary file alongside the output, then
atomically replaces the destination. Parsing, validation or replacement failures
leave the previous catalogue intact, remove the temporary file and exit nonzero.

### Refresh and limitations

No cron, deployment, scanner or scientific processing changes are included.
A future separately reviewed scheduling change should run this generator after
the legacy catalogue has finished publishing, with explicit input and output
paths, in the existing OceanCurrent job environment. It should log the record
count and failures and alert on unexpected count reductions. Avoid reading a
partially written HTML file: use the publisher's completion signal or a completed
snapshot. Start with a manual comparison before enabling recurring refreshes;
refresh at the legacy catalogue's publication cadence rather than running a new
service.

The four table anchors, column headers and coordinate units are deliberately
validated. Missing tables, empty main views and conflicting metadata for the
same name/version fail the run. The event table may be empty. Year/summary rows
and incomplete or unrecognised mission rows are skipped. This is a structural
sanity check, not proof that a partially published catalogue is complete: there
is no fixed mission-count threshold. Historical letter suffixes and `_1`/`_2`
legs are supported; new naming/header conventions need parser review. Scientific
and visualisation links are preserved but their availability is not checked.
The source's precision and errors remain authoritative; no scientific metadata,
annual-map hotspots or missing links are inferred.

Future `ocean-current-api` work should define a dedicated catalogue response and
loader for this schema, retain the four order lists and mission/version identity,
and associate visualisation references with the existing Gliders asset indexes.
The catalogue must not be interpreted as an image index. Endpoints, frontend
browsing and caching/refresh behaviour remain separate integration work.
