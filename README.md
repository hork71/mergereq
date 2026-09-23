# mergedash

Pulls GitLab merge request data across all projects and upserts it into
Postgres, for the internal MR dashboard. Runs daily under systemd, as the
`mergedash` service user (the same user the Flask dashboard runs under).

## Files

- `mergedash.py` — the sync script (python-gitlab based).
- `run-mergedash.sh` — wrapper invoked by systemd: loads secrets from
  `mergedash.env` and computes the `--since`/`--until` window (yesterday
  through today) for a daily run.
- `mergedash.env.example` — template for secrets. Copy to `mergedash.env`,
  fill in, `chmod 600`. Never commit the filled-in file.
- `systemd/mergedash.service` — oneshot unit that runs the wrapper.
- `systemd/mergedash.timer` — fires the service daily at 06:00.

## Requirements

Installed system-wide (no venv — packages come from the OS/production repos,
already available since the Flask app runs on the same box/user):

- `python-gitlab`
- `python-dateutil`
- `psycopg2`

## Deploy

Run on the target server, as (or via `sudo -u`) the `mergedash` user for the
app files, and as root for the systemd units.

```bash
# 1. Place the app files
#    (mergedash.py, run-mergedash.sh, mergedash.env.example) in
#    /data/apps/mergedash, owned by mergedash:mergedash.
cd /data/apps/mergedash
chmod +x run-mergedash.sh

# 2. Configure secrets
cp mergedash.env.example mergedash.env
$EDITOR mergedash.env        # set GITLAB_TOKEN and PG_DSN (with password)
chmod 600 mergedash.env
chown mergedash:mergedash mergedash.env

# 3. Install the systemd units
sudo cp systemd/mergedash.service systemd/mergedash.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now mergedash.timer
```

## Verify

```bash
# Confirm the timer is scheduled
systemctl list-timers mergedash.timer

# Trigger a run immediately, without waiting for the schedule
sudo systemctl start mergedash.service

# Watch logs (stdout/stderr go to the journal automatically)
journalctl -u mergedash.service -f
```

## Notes

- `--token` on `mergedash.py` is required — there's no built-in default. It
  must come from `mergedash.env`'s `GITLAB_TOKEN`.
- The wrapper always passes `--since`/`--until`; `mergedash.py` requires
  `--since` to run at all (it compares every project's last-activity date
  against it before deciding whether to fetch).
- `mergedash.env` holds a live GitLab token and a Postgres password in
  plaintext — keep it `chmod 600`, owned by `mergedash`, and out of git
  (only `mergedash.env.example` is tracked).
- To change the schedule, edit `OnCalendar=` in `systemd/mergedash.timer`,
  then `sudo systemctl daemon-reload && sudo systemctl restart mergedash.timer`.
- To change the lookback window (currently a fixed "yesterday through
  today"), edit the `SINCE=`/`UNTIL=` lines in `run-mergedash.sh`.
