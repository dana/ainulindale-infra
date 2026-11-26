import httpx


def test_eridian_echo_disabled(creds):
    """Verify Eridian Echo endpoints return 404 (disabled to eliminate attack surface)."""
    base_url = creds["api_base_url"]
    with httpx.Client(timeout=15.0, follow_redirects=True) as client:
        # UI endpoint returns 404
        res = client.get(f"{base_url}/api/v1/eridian-echo/")
        assert res.status_code == 404

        # Jobs API endpoint returns 404
        res_jobs = client.get(f"{base_url}/api/v1/eridian-echo/jobs")
        assert res_jobs.status_code == 404

        # Static assets return 404
        res_assets = client.get(f"{base_url}/api/v1/assets/eridian-echo/eridian-echo.css")
        assert res_assets.status_code == 404

