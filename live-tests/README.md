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
├── requirements.txt                   # Python test dependencies (pytest, httpx, playwright, etc.)
├── run-live-tests.sh                  # Main entrypoint script (boots browser container, creates venv, runs pytest)
├── fixtures/
│   └── test.mp3                       # Sample audio fixture for Eridian Echo transcription tests
├── docker/
│   ├── Dockerfile.headless-shell      # Headless chromium container spec
│   └── run-headless-browser.sh        # Starts headless browser container on port 9333
├── k8s/
│   └── cleanup-test-artifacts-cronjob.yaml # Kubernetes CronJob deleting stale test data from MongoDB
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

Simply execute the runner:
```bash
./run-live-tests.sh
```

You can pass standard pytest arguments:
```bash
# Skip Gemini transcription upload to save API quota:
SKIP_GEMINI_UPLOAD=1 ./run-live-tests.sh

# Run only API contract tests:
./run-live-tests.sh tests/test_api_endpoints.py

# Run only headless browser tests:
./run-live-tests.sh tests/test_browser_e2e.py
```

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
