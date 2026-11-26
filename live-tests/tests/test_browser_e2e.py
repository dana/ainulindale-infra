import pytest
import os
from playwright.sync_api import sync_playwright

def test_browser_main_site(creds):
    cdp_url = creds.get("headless_chrome_cdp", "http://127.0.0.1:9333")
    base_url = creds["api_base_url"]

    with sync_playwright() as p:
        try:
            browser = p.chromium.connect_over_cdp(cdp_url)
        except Exception as e:
            pytest.skip(f"Could not connect to headless browser CDP at {cdp_url}: {e}")

        context = browser.new_context(ignore_https_errors=True)
        page = context.new_page()

        # 1. Visit main site
        page.goto(f"{base_url}/", wait_until="networkidle")
        assert "diederich.ai" in page.title().lower() or "diederich" in page.content().lower()

        # 2. Visit privacy and terms pages
        page.goto(f"{base_url}/privacy.html")
        assert "privacy" in page.content().lower()

        page.goto(f"{base_url}/terms.html")
        assert "terms" in page.content().lower()

        context.close()
        browser.close()

def test_browser_eridian_echo_ui_interaction(creds):
    cdp_url = creds.get("headless_chrome_cdp", "http://127.0.0.1:9333")
    base_url = creds["api_base_url"]

    with sync_playwright() as p:
        try:
            browser = p.chromium.connect_over_cdp(cdp_url)
        except Exception as e:
            pytest.skip(f"Could not connect to headless browser CDP at {cdp_url}: {e}")

        context = browser.new_context(ignore_https_errors=True)
        page = context.new_page()
        response = page.goto(f"{base_url}/api/v1/eridian-echo/")
        assert response.status == 404

        context.close()
        browser.close()
