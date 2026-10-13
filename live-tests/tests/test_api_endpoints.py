import pytest
import httpx

def test_api_happy_endpoint(creds):
    base = creds['api_base_url']
    url = f"{base}/api/v1/happy"
    with httpx.Client(timeout=10.0, follow_redirects=True) as client:
        res = client.get(url)
        assert res.status_code == 200, f"Failed GET {url}: {res.status_code}"
        data = res.json()
        assert "system_time_utc" in data
        assert "load_average" in data
        load = data["load_average"]
        assert "one_minute" in load
        assert "five_minutes" in load
        assert "fifteen_minutes" in load

def test_api_echo_contract(creds):
    base = creds['api_base_url']
    url = f"{base}/api/v1/echo"
    with httpx.Client(timeout=10.0, follow_redirects=True) as client:
        payload = {"message": "live-production-test-hello"}
        res = client.post(url, json=payload)
        assert res.status_code == 200
        assert res.json() == {"message": "live-production-test-hello", "length": len("live-production-test-hello")}

        res_bad_ct = client.post(url, content="raw text", headers={"Content-Type": "text/plain"})
        assert res_bad_ct.status_code == 415

def test_api_happy_path_contract(creds):
    base = creds['api_base_url']
    url = f"{base}/api/v1/happy-path"
    with httpx.Client(timeout=10.0, follow_redirects=True) as client:
        payload = {"message": "e2e-live-check"}
        res = client.post(url, json=payload)
        assert res.status_code == 200
        data = res.json()
        assert data.get("proof") == "chunk-11-happy-path"
        assert data.get("length") == len("e2e-live-check")

def test_api_redirect_www_to_apex(creds):
    url = "https://www.diederich.ai/api/v1/happy"
    with httpx.Client(timeout=10.0, follow_redirects=False) as client:
        res = client.get(url)
        assert res.status_code in (301, 308)
        assert res.headers.get("location") == "https://diederich.ai/api/v1/happy"
