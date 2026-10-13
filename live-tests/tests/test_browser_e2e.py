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
    cookie_val = creds.get("eridian_echo_cookie")

    with sync_playwright() as p:
        try:
            browser = p.chromium.connect_over_cdp(cdp_url)
        except Exception as e:
            pytest.skip(f"Could not connect to headless browser CDP at {cdp_url}: {e}")

        context = browser.new_context(ignore_https_errors=True)
        if cookie_val:
            context.add_cookies([{
                "name": "eridian_echo_session",
                "value": cookie_val,
                "domain": "diederich.ai",
                "path": "/api/v1/eridian-echo",
                "secure": True,
                "sameSite": "Lax"
            }])

        page = context.new_page()
        page.goto(f"{base_url}/api/v1/eridian-echo/", wait_until="networkidle")

        # Verify page layout elements
        assert page.locator("h1").inner_text() == "Eridian Echo"
        assert page.locator("#dropzone").is_visible()

        if cookie_val:
            assert "Welcome, Live Test Runner" in page.content()
            assert page.get_by_role("button", name="Sign Out").is_visible()
        else:
            assert "Guest user" in page.content()

        context.close()
        browser.close()
