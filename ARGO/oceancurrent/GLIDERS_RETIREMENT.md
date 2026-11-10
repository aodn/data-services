# Gliders retirement: merge after cron cutover (aodn/backlog#9723)

This change removes the four migrated Gliders modules, their four test modules,
the catalogue test helper and their exclusive fixtures. The canonical copies now
live in `aodn/ocean-current-api/scripts/cron/`; fixtures are under
`tests/mnt/oceancurrent/website/gliders/generators/`. The scanner and Argo are unchanged.

## Required merge order

1. Merge the generators, tests and `run_gliders.sh` into `ocean-current-api/main`.
2. Deploy the prepared `chef-private/data_bags/cronjobs/po_gliders_catalogue.json`
   change through the normal infrastructure process.
3. Confirm the effective cron downloads the new entry point and no longer references
   `data-services/master/ARGO/oceancurrent`. Verify a scheduled run published both
   unchanged output paths with valid JSON and healthy monitoring.
4. Only then merge this removal from data-services.

Do not merge this cleanup while the effective cron still downloads the removed
modules. Local deletions are a reviewable retirement diff, not a production cutover.
Before retirement, rollback is to restore the former Chef command. After retirement,
restore the legacy modules before reverting the cron to their former URLs.

Before removal, the four production modules and helper were compared byte for byte
with the destination copies, as were all removed fixtures. The migrated suite is
included in ocean-current-api's existing Python CI job.
