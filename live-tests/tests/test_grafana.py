import pytest
import httpx
import uuid

def test_grafana_login_page_reachable(creds):
    base = creds['grafana_url']
    url = f"{base}/login"
    with httpx.Client(timeout=10.0, follow_redirects=True) as client:
        res = client.get(url)
        assert res.status_code == 200
        assert "Grafana" in res.text

def test_grafana_service_account_crud(creds):
    token = creds.get("grafana_token")
    if not token:
        pytest.skip("No GRAFANA_TOKEN provided in credentials")

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    test_uid = f"test-{uuid.uuid4().hex[:8]}"
    folder_title = f"LiveTest-{test_uid}"

    with httpx.Client(timeout=10.0, base_url=creds['grafana_url'], headers=headers) as client:
        res_create = client.post("/api/folders", json={"title": folder_title, "uid": test_uid})
        assert res_create.status_code in (200, 201), f"Failed to create folder: {res_create.text}"
        folder_data = res_create.json()
        assert folder_data["uid"] == test_uid

        try:
            res_get = client.get(f"/api/folders/{test_uid}")
            assert res_get.status_code == 200
            assert res_get.json()["title"] == folder_title

            dash_payload = {
                "dashboard": {
                    "id": None,
                    "uid": f"d-{test_uid}",
                    "title": f"Live Dashboard {test_uid}",
                    "tags": ["automated-live-test"],
                    "timezone": "browser",
                    "schemaVersion": 16,
                    "version": 0,
                    "refresh": "25s"
                },
                "folderUid": test_uid,
                "overwrite": True
            }
            res_dash = client.post("/api/dashboards/db", json=dash_payload)
            assert res_dash.status_code == 200, f"Failed to create dashboard: {res_dash.text}"

            res_dash_get = client.get(f"/api/dashboards/uid/d-{test_uid}")
            assert res_dash_get.status_code == 200
            assert res_dash_get.json()["dashboard"]["title"] == f"Live Dashboard {test_uid}"
        finally:
            res_del = client.delete(f"/api/folders/{test_uid}")
            assert res_del.status_code in (200, 202, 204)
