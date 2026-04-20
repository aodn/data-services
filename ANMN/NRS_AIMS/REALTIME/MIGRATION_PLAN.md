# Migration Plan: ANMN NRS AIMS Pipeline → Prefect Cloud

## Context

The current pipeline runs as a cron-scheduled Python script on a server with shared local filesystem. Migrating to **Prefect Cloud** means:

- Flow runs execute in **ephemeral, stateless workers** — no persistent local disk between runs.
- The `tendo.singleton` concurrency guard won't work — Prefect deployments handle this natively.
- All disk-based state (`$WIP_DIR`, pickle files, `INCOMING_DIR`, `ERROR_DIR`) must move to **S3** or equivalent object storage.
- Global variables and `os.environ`-driven configuration must be replaced with Prefect **Blocks** and flow/task parameters.

---

## Task List

### 🗄️ S3 State Store — Replace Pickle Files

The pickle-based state store is the most critical piece to migrate. The two pickle files (`aims_qc0.pickle`, `aims_qc1.pickle`) are simple `dict[channel_id → last_downloaded_date_str]` objects. Their S3 equivalent is a JSON object at a fixed key.

- [ ] **Create S3 bucket and key convention for state files**
  - Suggested keys: `state/aims_qc0_state.json` and `state/aims_qc1_state.json`
  - Use the same bucket as processed output files for simplicity

- [ ] **Rewrite `_pickle_filename()`** → `_s3_state_key(level_qc)`
  - Returns an S3 key string instead of a local file path
  - Remove the dependency on `$data_wip_path`

- [ ] **Rewrite `save_channel_info()`** to write state to S3
  - Read the current JSON state object from S3 (or start with `{}` if it doesn't exist)
  - Update the `channel_id` key with the new date
  - Write the full dict back as JSON via `boto3` `put_object`
  - Use `if_match` / object locking or a Prefect concurrency limit to prevent race conditions if tasks ever run in parallel

- [ ] **Rewrite `get_last_downloaded_date_channel()`** to read from S3
  - Download the JSON state object, parse it, return the date for the channel
  - Preserve the fallback-to-`from_date` behaviour on missing key or missing file (S3 `NoSuchKey` exception)

- [ ] **Rewrite `has_channel_already_been_downloaded()`** to query S3 state
  - Check if the channel key exists in the downloaded JSON

- [ ] **Rewrite `delete_channel_id_from_pickle()`** and **`delete_platform_entries_from_pickle()`** to operate on the S3 JSON
  - These are manual maintenance utilities — they can remain standalone scripts that read/modify/write the S3 JSON object

- [ ] **Cache the S3 state read within a flow run**
  - The current code reads the pickle on every channel. In S3, download the full state dict **once at flow start**, pass it in-memory to each task, and do a **single write back at the end** (or after each successful channel)
  - This avoids excessive S3 GET/PUT calls (one per channel → one per flow run)

---

### 🏗️ Prefect Flow & Task Structure

- [ ] **Decorate `process_qc_level()` as a `@flow`**
  - Entry point becomes `process_qc_level(level_qc: int)`
  - Remove global `logger` — use Prefect's built-in logger: `logger = get_run_logger()`

- [ ] **Decorate `process_monthly_channel()` as a `@task`**
  - Each channel becomes an independent task with its own retry/failure tracking in the Prefect UI
  - Set `retries=2, retry_delay_seconds=60` at the task level to replace the current manual `break`-on-error pattern

- [ ] **Decorate `download_channel()` as a `@task`**
  - The existing `@retry` decorator (from the `retrying` library) can be replaced with Prefect's native `retries` parameter

- [ ] **Remove all `global` variables** (`TMP_MANIFEST_DIR`, `TESTING`, `logger`)
  - Pass `tmp_manifest_dir` as a task parameter
  - Pass `testing: bool` as a flow parameter (exposed in Prefect deployment UI)

- [ ] **Remove `tendo.singleton`**
  - Replace with a [Prefect concurrency limit](https://docs.prefect.io/latest/concepts/concurrency-limiting/) set to `1` on the deployment, preventing concurrent runs natively

- [ ] **Replace the startup unit test (`AimsDataValidationTest`)** with a dedicated Prefect `@task`
  - Run it as the first task in the flow; use `raise_on_failure=True` so the flow aborts if the MD5 check fails
  - This makes the validation visible as a named step in the Prefect UI

---

### 📦 Output — Replace `INCOMING_DIR` Manifest with S3

The current pipeline stages files into a local `INCOMING_DIR` which triggers the downstream AODN ingest. In Prefect Cloud, the worker has no access to that directory.

- [ ] **Upload transformed NetCDF files directly to S3** instead of `move_to_tmp_incoming()`
  - Use the same `{name_no_date}.{md5}.nc` naming convention
  - Target bucket/prefix to be agreed with the downstream AODN pipeline team

- [ ] **Replace `.manifest` file generation** with an S3 event notification or SQS message
  - Option A: Upload files to a dedicated S3 prefix; downstream pipeline uses S3 event notifications to trigger ingest
  - Option B: Write a manifest JSON to a known S3 key after each flow run (mirrors the current `.manifest` file approach)
  - Confirm the preferred handoff mechanism with the AODN pipeline team before implementing

- [ ] **Replace `ERROR_DIR`** with an S3 prefix (e.g., `errors/ANMN_NRS_DAR_YON/`)
  - Failed files are uploaded there instead of `shutil.copy` to a local path
  - The check `len(os.listdir(ANMN_NRS_ERROR_DIR)) >= 2` becomes a `list_objects_v2` count check at flow start

---

### ⚙️ Configuration & Secrets

- [ ] **Create a Prefect `S3Bucket` Block** for the output/state bucket
  - Store bucket name and credentials; reference in the flow via `S3Bucket.load("aims-data")`

- [ ] **Create a Prefect `Secret` Block** for any AIMS API credentials if required in future

- [ ] **Replace `$DATA_SERVICES_DIR/lib/netcdf/imos_env`** dotenv file
  - Move IMOS global attribute values (`CONVENTIONS`, `DATA_CENTRE`, `PROJECT`, etc.) to Prefect **Variables** or a config JSON in S3
  - Remove the `dotenv.load_dotenv()` call from `modify_aims_netcdf()`

- [ ] **Replace all `os.environ.get(...)` calls** for `WIP_DIR`, `INCOMING_DIR`, `ERROR_DIR` with Prefect Block references or flow parameters

---

### 🐳 Worker Environment & Dependencies

The pipeline has heavy native dependencies that must be available on the Prefect worker.

- [ ] **Build a custom Docker image** for the Prefect worker containing:
  - `netCDF4`, `numpy`, `requests`, `dateutil`, `retrying`, `dotenv`, `compliance-checker`
  - `ioos-compliance-checker` with CF 1.6 and IMOS 1.3 checker plugins installed
  - `boto3` / `s3fs` for S3 state and output
  - `aims_realtime_util.py`, `dest_path.py`, `util.py` (currently on `$PYTHONPATH` via `$DATA_SERVICES_DIR/lib/python`)

- [ ] **Package `aims_realtime_util`, `dest_path`, and `util`** as an installable Python package (or include in the Docker image `PYTHONPATH`)

- [ ] **Configure the Prefect deployment to use the custom Docker image**

---

### 🗓️ Scheduling & Deployment

- [ ] **Create two Prefect deployments** (one per QC level), or a single deployment with `level_qc` as a parameter
- [ ] **Set a schedule** matching the current cron frequency
- [ ] **Set `concurrency_limit: 1`** on each deployment to replace `singleton`
- [ ] **Add a Prefect notification** (email/Slack) on flow failure to replace the `aims.log` monitoring instruction

---

## State Migration Summary

| Current | Prefect Cloud replacement |
|---|---|
| `aims_qc0.pickle` on `$data_wip_path` | `s3://bucket/state/aims_qc0_state.json` |
| `aims_qc1.pickle` on `$data_wip_path` | `s3://bucket/state/aims_qc1_state.json` |
| Python `pickle` serialisation | Plain JSON (`json.dumps/loads`) |
| Read/write on every channel | Read once at flow start, write back per successful channel |
| Falls back to `from_date` if file missing | Falls back to `from_date` on S3 `NoSuchKey` |
| Manual deletion via helper functions | Same helpers rewritten to mutate S3 JSON object |
| `$data_wip_path/errors/` | `s3://bucket/errors/ANMN_NRS_DAR_YON/` |
| `INCOMING_DIR` manifest trigger | S3 event notification or manifest JSON in S3 |
| `tendo.singleton` concurrency guard | Prefect deployment concurrency limit = 1 |
| `aims.log` file monitoring | Prefect Cloud UI + failure notifications |
