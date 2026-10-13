import pytest
import httpx

def test_static_web_home(creds):
    base = creds['api_base_url']
    url = f"{base}/"
    with httpx.Client(timeout=10.0, follow_redirects=True) as client:
        res = client.get(url)
        assert res.status_code == 200
        assert "Welcome to diederich.ai" in res.text or "<html" in res.text

def test_privacy_and_terms_pages(creds):
    base = creds['api_base_url']
    with httpx.Client(timeout=10.0, follow_redirects=True) as client:
        res_privacy = client.get(f"{base}/privacy.html")
        assert res_privacy.status_code == 200
        assert "Privacy Policy" in res_privacy.text or "privacy" in res_privacy.text.lower()

        res_terms = client.get(f"{base}/terms.html")
        assert res_terms.status_code == 200
        assert "Terms" in res_terms.text or "terms" in res_terms.text.lower()

def test_dana_share_ingress(creds):
    base = creds['api_base_url']
    url = f"{base}/s/"
    with httpx.Client(timeout=10.0, follow_redirects=True) as client:
        res = client.get(url)
        assert res.status_code in (200, 403), f"Unexpected status for /s/: {res.status_code}"

def test_michelle_care_ingress(creds):
    url = f"{creds['michelle_care_url']}{creds['michelle_secret_path']}/"
    with httpx.Client(timeout=10.0, follow_redirects=True) as client:
        res = client.get(url)
        assert res.status_code == 200, f"Failed GET {url}: {res.status_code}"
        assert "<html" in res.text.lower()

def test_michelle_care_unauthorized_path(creds):
    url = f"{creds['michelle_care_url']}/"
    with httpx.Client(timeout=10.0, follow_redirects=False) as client:
        res = client.get(url)
        assert res.status_code == 404
