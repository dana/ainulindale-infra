import os
from pathlib import Path
import pytest
from dotenv import load_dotenv

# Search for credentials file in order:
# 1. AINULINDALE_CREDS_FILE env var
# 2. ~/.ainulindale.creds
# 3. .ainulindale.creds in current or parent directory
creds_candidates = [
    os.environ.get("AINULINDALE_CREDS_FILE"),
    str(Path.home() / ".ainulindale.creds"),
    str(Path.cwd() / ".ainulindale.creds"),
    str(Path.cwd() / "live-tests" / ".ainulindale.creds"),
]

for candidate in creds_candidates:
    if candidate and os.path.exists(candidate):
        load_dotenv(candidate)
        break

@pytest.fixture(scope="session")
def creds():
    return {
        "api_base_url": os.getenv("API_BASE_URL", "https://diederich.ai").rstrip("/"),
        "grafana_url": os.getenv("GRAFANA_URL", "https://www.diederich.ai/monitoring").rstrip("/"),
        "grafana_token": os.getenv("GRAFANA_TOKEN", ""),
        "eridian_echo_cookie": os.getenv("ERIDIAN_ECHO_AUTH_COOKIE", "test-synthetic-session-live"),
        "gemini_api_key": os.getenv("GEMINI_API_KEY", ""),
        "michelle_care_url": os.getenv("MICHELLE_CARE_URL", "https://michelle.care").rstrip("/"),
        "michelle_secret_path": os.getenv("MICHELLE_SECRET_PATH", "/this-secret"),
        "minecraft_host": os.getenv("MINECRAFT_HOST", "10.0.0.78"),
        "minecraft_port": int(os.getenv("MINECRAFT_PORT", "25565")),
        "headless_chrome_cdp": os.getenv("HEADLESS_CHROME_CDP", "http://127.0.0.1:9333"),
        "skip_gemini_upload": os.getenv("SKIP_GEMINI_UPLOAD", "0") in ("1", "true", "True"),
    }
