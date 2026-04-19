# ANMN NRS AIMS Realtime Data Pipeline

## Overview

This pipeline ingests near-realtime ocean sensor data (temperature, salinity, turbidity, current speed, etc.) from AIMS (Australian Institute of Marine Science) buoys at sites like **Darwin**, **Yongala**, and **Beagle Gulf**, transforms the raw NetCDF files into IMOS/CF-compliant format, and loads them into AODN's data system.

---

## 🔵 Extract

**Source:** AIMS web service RSS/XML feeds and data API

```
https://data.aims.gov.au/gbroosdata/services/rss/netcdf/level{qc}/300
```

The pipeline runs twice per execution — once for **QC level 0** (raw data) and once for **QC level 1** (quality-controlled data). Each run is fully independent.

### 1. RSS Feed Parsing (`parse_aims_xml`)

The RSS feed is an XML document listing every available sensor channel from the AIMS system. The function downloads and parses it using Python's `xml.etree.ElementTree`.

The feed is structured as a flat list of `<item>` elements (starting at index 3, after header nodes). Each item maps to one sensor channel. The parser walks the items in a single pass, building a dictionary keyed by `channel_id`:

| XML node index | Field extracted |
|---|---|
| `node[0]` | `title` |
| `node[1]` | `link` |
| `node[6]` | `metadata_uuid` |
| `node[7]` | `uom` (unit of measure) |
| `node[8]` | `from_date` — earliest data available for this channel |
| `node[9]` | `thru_date` — latest data available for this channel |
| `node[10]` | `platform_name` |
| `node[11]` | `site_name` |
| `node[12]` | `channel_id` (primary key) |
| `node[13]` | `parameter` |
| `node[14]` | `parameter_type` |
| `node[15]` | `trip_id` (SOOP TRV only; derived from `from_date` for all other feeds) |

The result is an in-memory dict like:
```python
{
  "84329": {
    "channel_id": "84329",
    "platform_name": "Darwin Buoy",
    "site_name": "NRS Darwin",
    "parameter": "Sea Temperature",
    "from_date": "2009-04-21T10:43:54Z",
    "thru_date": "2024-03-01T00:00:00Z",
    ...
  },
  ...
}
```

The function is decorated with `@lru_cache(maxsize=100)` — so within a single run, calling it twice with the same URL returns the cached result without a second HTTP request.

Network failures are handled by `urlopen_with_retry`, which retries up to **10 times** with exponential backoff (3s, 6s, 12s, …).

---

### 2. State Tracking (pickle files)

The pipeline must be **incremental** — it only downloads data that has arrived since the last run. This state is persisted in two pickle files stored in `$data_wip_path`:

| File | Purpose |
|---|---|
| `aims_qc0.pickle` | Tracks last-downloaded date per channel for QC level 0 |
| `aims_qc1.pickle` | Tracks last-downloaded date per channel for QC level 1 |

Each pickle file is a plain Python `dict` of `{ channel_id: last_downloaded_date_str }`.

**Key functions:**

- **`has_channel_already_been_downloaded(channel_id, level_qc)`** — returns `True` if an entry exists for this channel (used to distinguish first-ever download from incremental updates).

- **`get_last_downloaded_date_channel(channel_id, level_qc, from_date)`** — returns the stored date for a channel, or falls back to the feed's own `from_date` if the channel has never been downloaded. If the pickle file is missing or corrupt, it also falls back gracefully rather than crashing.

- **`save_channel_info(channel_id, aims_xml_info, level_qc, end_date)`** — called after a successful download. Writes the processed `end_date` into the pickle so the next run skips already-fetched data.

- **`delete_channel_id_from_pickle` / `delete_platform_entries_from_pickle`** — manual utilities to force a channel or entire platform to be re-downloaded from scratch (useful when AIMS reprocesses historical data).

**`create_list_of_dates_to_download`** ties feed metadata and pickle state together:

1. Reads `last_dl_date` from the pickle (falls back to `from_date` for new channels).
2. If `last_dl_date >= thru_date`: nothing to do — returns empty lists and skips the channel.
3. Otherwise, generates a list of **monthly intervals** using `dateutil.rrule.MONTHLY`, starting from the **1st of the month** of `last_dl_date` (so any partial month is always re-fetched cleanly).
4. The final interval's end date is snapped to `thru_date` exactly, so the download never overshoots the available data.

```
Example — channel last downloaded on 2024-01-15, thru_date 2024-03-20:

  Interval 1:  2024-01-01  →  2024-02-01
  Interval 2:  2024-02-01  →  2024-03-01
  Interval 3:  2024-03-01  →  2024-03-20  ← snapped to thru_date
```

Each interval is then passed individually to `download_channel`. If a month succeeds, `save_channel_info` records its end date. If a month fails, the loop breaks — the pickle is **not** updated, so the failed month will be retried on the next run.

---

### 3. Download (`download_channel`)

For each monthly interval, the pipeline constructs a URL:

```
https://data.aims.gov.au/gbroosdata/services/data/rtds/{channel_id}/level{qc}/raw/raw/{from}/{thru}/netcdf/2
```

The response is a `.zip` file which is:
1. Streamed in 1 MiB chunks to a temp file (avoids loading large files into memory).
2. Validated as a real zip file — if not, the channel is aborted and AIMS is contacted.
3. Extracted to a temp directory, yielding a single `.nc` NetCDF file.

If AIMS has no data for that period it returns a file literally named `NO_DATA_FOUND`. The pipeline detects this, logs it, cleans up the temp dir, and **continues to the next month** rather than treating it as an error.

---

## 🟡 Transform

**All transformations happen in-place on the temporary NetCDF file.**

1. **Generic AIMS fixes** (`modify_aims_netcdf`)
   - Renames `time` → `TIME` (dimension and variable).
   - Normalises coordinate variable attributes: `LATITUDE`, `LONGITUDE` get standard names, valid ranges, axis attributes.
   - Sets required IMOS global attributes: `Conventions`, `data_centre`, `project`, `acknowledgement`, `date_created`.
   - Fixes variable units and names to be CF-compliant (e.g., `fluorescence` → `CPHL`, `Seawater_Intake_Temperature` → `TEMP`).
   - Adds IMOS QC convention strings to all `_quality_control` variables.
   - Normalises `long_name` casing.

2. **Site-specific fixes** (`modify_anmn_nrs_netcdf`)
   - Maps platform names (Darwin, Yongala, Beagle) to IMOS site codes (`NRSDAR`, `NRSYON`, `DARBGF`).
   - Sets `site_code`, `platform_code`, `aims_channel_id`.
   - Renames `depth` → `NOMINAL_DEPTH` with correct attributes; sets `DEPTH` (actual) attributes.
   - Sets `coordinates` attribute on the main data variable.

3. **Time conversion** (`convert_time_cf_to_imos`)
   - Converts the time reference epoch to IMOS standard: `days since 1950-01-01 00:00:00 UTC`.

4. **Dimension cleanup** (`remove_dimension_from_netcdf`)
   - Removes the spurious `single` dimension from the file (pure Python equivalent of `ncwa`).
   - Strips `cell_methods` attributes.

5. **Filename fixes**
   - `fix_data_code_from_filename` — corrects the IMOS data-type letter code in the filename (e.g., current direction → `_V_`).
   - `fix_provider_code_from_filename` — replaces `AIMS_` prefix with `IMOS_ANMN_`.
   - `remove_end_date_from_filename` — strips the `_END-*` suffix so monthly files overwrite cleanly.

---

## ✅ Validate

Before loading, each file is checked:

| Check | Function |
|---|---|
| TIME variable is not empty | `is_time_var_empty` |
| TIME values are strictly monotonic | `is_time_monotonic` |
| Main variable contains real data (not all fill values) | `has_var_only_fill_value` |
| Site code is recognised | `get_anmn_nrs_site_name` |
| File passes CF 1.6 + IMOS 1.3 compliance checker | `pass_netcdf_checker` |
| Filename matches IMOS regex `IMOS_ANMN_[A-Z]_` | regex check |

Files failing any check are copied to a `wip/errors/` directory and the channel is **skipped** (not permanently broken — it will be retried next run).

A **data validation unit test** (`AimsDataValidationTest`) runs at startup. It downloads a known reference file and verifies its MD5 checksum to confirm AIMS hasn't changed the format. The pipeline **will not start** if this test fails.

---

## 🔴 Load

1. **Stage to manifest directory** (`move_to_tmp_incoming`)
   - Renames each file to include its MD5 hash (for deduplication/integrity).
   - Moves it into a timestamped `manifest_dir_tmp_YYYYMMDDHHMMSS/` folder.

2. **Write manifest files**
   - File paths in the manifest directory are batched (up to 4096 per manifest file).
   - Each batch is written to a `.manifest` file (e.g., `anmn_nrs_aims_FV01_20240101120000_0.manifest`).
   - Manifests are moved to the `INCOMING_DIR` watched by the AODN pipeline (`AODN/ANMN_NRS_DAR_YON/`).

3. **Update state**
   - `save_channel_info` writes the successfully processed end date back to the pickle file, so the next run starts from where this one left off.

See [MIGRATION_PLAN.md](./MIGRATION_PLAN.md) for the Prefect Cloud migration task list.

---

## Pipeline Flow Diagram

```
AIMS RSS XML Feed
       │
       ▼
  parse_aims_xml()          ← channel metadata + date ranges
       │
       ▼
  [For each channel]
  create_list_of_dates()    ← compare against pickle (state store)
       │
       ▼
  download_channel()        ← HTTP → .zip → .nc (temp dir)
       │
       ▼
  modify_anmn_nrs_netcdf()  ← rename vars, fix units, set IMOS attrs
       │
       ▼
  Validation checks         ← time, data, site code, CF/IMOS compliance
       │
       ├── FAIL → copy to errors/, skip channel
       │
       ▼
  fix filename / rename
       │
       ▼
  move_to_tmp_incoming()    ← hash-renamed file → manifest staging dir
       │
       ▼
  Write .manifest file      → INCOMING_DIR (triggers AODN pipeline)
       │
       ▼
  save_channel_info()       ← update pickle state
```
