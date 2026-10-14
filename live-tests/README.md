# Ainulindale Live Production Test Suite

A standalone, portable live test suite for the applications and services deployed on the `elwing` MicroK8s cluster.

This test suite is designed to be copied **whole** to any modern environment (workstation, server, or `elwing` itself) and run independently against cluster endpoints.

---

## Prerequisites

1. **Python 3.12+**
2. **Docker** (optional, required for the headless browser test suite)
3. **Credentials file**: `~/.ainulindale.creds` (or pass `AINULINDALE_CREDS_FILE=/path/to/creds`)

---

## Directory Structure

```text
live-tests/
├── README.md                          # Documentation and instructions
├── requirements.txt                   # Python test dependencies (pytest, httpx, playwright, psutil, etc.)
├── run-live-tests.sh                  # Main entrypoint script (boots browser container, creates venv, runs pytest)
├── run-live-tests-profiled.py         # Telemetry profiler exporting atomic Prometheus textfile metrics
├── fixtures/
│   └── test.mp3                       # Sample audio fixture for Eridian Echo transcription tests
├── docker/
│   ├── Dockerfile.headless-shell      # Headless chromium container spec
│   └── run-headless-browser.sh        # Starts headless browser container on port 9333
├── k8s/
│   └── cleanup-test-artifacts-cronjob.yaml # Kubernetes CronJob deleting stale test data from MongoDB
├── monitoring/
│   ├── grafana-dashboard.json         # Provisioned Grafana dashboard (UID: ainulindale-live-tests)
│   ├── prometheus-alerts.yml          # Prometheus alert rules (Suite, Module, Case failures & staleness)
│   └── telegraf-ainulindale-live-tests.conf # Telegraf file input configuration for Prometheus textfile
├── scripts/
│   └── run-ainulindale-live-tests-cron.sh  # Flocked cron wrapper with automatic git auto-update
├── systemd/
│   ├── ainulindale-live-tests.service # Systemd oneshot unit executing tests
│   └── ainulindale-live-tests.timer   # Systemd timer triggering suite every 10 minutes
└── tests/
    ├── conftest.py                    # Pytest fixtures and credential ingestion
    ├── test_api_endpoints.py          # FastAPI contracts (/api/v1/happy, /api/v1/echo, /api/v1/happy-path, redirects)
    ├── test_web_and_ingress.py        # Static web, privacy, terms, Dana share (/s/), Michelle Care (/this-secret/)
    ├── test_grafana.py                # Grafana SA token CRUD (creates and deletes test folders/dashboards)
    ├── test_minecraft.py              # ATM9 Minecraft TCP socket reachability on 10.0.0.78:25565
    ├── test_eridian_echo.py           # Eridian Echo guest and authenticated upload & lifecycle tests
    └── test_browser_e2e.py            # Playwright headless browser E2E interaction over CDP
```

---

## Running the Tests

### Standard Execution
```bash
./run-live-tests.sh
```

### Profiled Execution with Prometheus Metric Export
To profile execution duration, peak memory RSS, and CPU utilization while exporting Prometheus textfile metrics:
```bash
./run-live-tests.sh --profile
# or set the environment variable:
PROFILE_TELEMETRY=1 ./run-live-tests.sh
```

You can target specific test files or pass pytest arguments:
```bash
# Skip Gemini transcription upload to save API quota:
SKIP_GEMINI_UPLOAD=1 ./run-live-tests.sh

# Run only API contract tests:
./run-live-tests.sh tests/test_api_endpoints.py

# Profile only headless browser tests:
./run-live-tests.sh --profile tests/test_browser_e2e.py
```

---

## Scheduled Execution on Elwing (Every 10 Minutes)

The test suite runs automatically every 10 minutes directly on `elwing` outside of GitOps / K8s:
1. **Runner Script**: `scripts/run-ainulindale-live-tests-cron.sh` uses `flock` to guarantee non-overlapping runs and automatically syncs `origin/main` when clean.
2. **Systemd Service**: `systemd/ainulindale-live-tests.service` executes the runner under user `dana` with `docker` group permissions.
3. **Systemd Timer**: `systemd/ainulindale-live-tests.timer` fires every 10 minutes (`OnUnitActiveSec=10min`, `Persistent=true`).
4. **Metric Collection**: Writes Prometheus metrics to `/var/lib/node_exporter/textfile_collector/ainulindale_live_tests.prom` (falls back to `./ainulindale_live_tests.prom` if unwriteable).
5. **Telegraf Scrape**: Telegraf on `elwing` reads the textfile via `monitoring/telegraf-ainulindale-live-tests.conf` and forwards to Prometheus on `thalos:9090`.

---

## Monitoring & Alerting

* **Grafana Dashboard**: Available at `http://192.168.1.247:3000/d/ainulindale-live-tests` (UID: `ainulindale-live-tests`).
  - Suite status card and test counts (passed/failed/skipped)
  - Wall-clock duration per test module and individual test function
  - Real-time pass/fail state timeline matrix
  - Peak resident memory (RSS in MB) and average CPU % utilization per test file
* **Prometheus Alerts**:
  - `AinulindaleLiveTestSuiteFailed` (Critical): Entire test suite status is 0.
  - `AinulindaleLiveTestModuleFailed` (Major): Any test file module fails.
  - `AinulindaleLiveTestCaseFailed` (Major): Any individual test case fails.
  - `AinulindaleLiveTestsStale` (Warning): No telemetry recorded in >20 minutes.

---

## Credentials Format (`~/.ainulindale.creds`)

```bash
GRAFANA_URL="https://www.diederich.ai/monitoring"
GRAFANA_TOKEN="glsa_..."

ERIDIAN_ECHO_AUTH_COOKIE="test-synthetic-session-live"
GEMINI_API_KEY="AIzaSy..."

API_BASE_URL="https://diederich.ai"
MICHELLE_CARE_URL="https://michelle.care"
MICHELLE_SECRET_PATH="/this-secret"
MINECRAFT_HOST="10.0.0.78"
MINECRAFT_PORT="25565"
```
