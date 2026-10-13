import os
import time
import uuid
from pathlib import Path
import pytest
import httpx

FIXTURE_MP3 = Path(__file__).resolve().parent.parent / "fixtures" / "test.mp3"

def test_eridian_echo_guest_flow(creds):
    base_url = creds["api_base_url"]
    echo_url = f"{base_url}/api/v1/eridian-echo/"
    jobs_url = f"{base_url}/api/v1/eridian-echo/jobs"

    with httpx.Client(timeout=15.0, follow_redirects=True) as client:
        # 1. Fetch index page, assert cookie is established
        res = client.get(echo_url)
        assert res.status_code == 200
        assert "Eridian Echo" in res.text
        assert "Guest user" in res.text
        session_cookie = client.cookies.get("eridian_echo_session")
        assert session_cookie is not None

        # 2. Fetch jobs list for new guest (should be empty)
        res_jobs = client.get(jobs_url)
        assert res_jobs.status_code == 200
        assert isinstance(res_jobs.json(), list)

def test_eridian_echo_authenticated_session(creds):
    base_url = creds["api_base_url"]
    echo_url = f"{base_url}/api/v1/eridian-echo/"
    cookie_val = creds.get("eridian_echo_cookie")

    if not cookie_val:
        pytest.skip("No ERIDIAN_ECHO_AUTH_COOKIE specified")

    with httpx.Client(timeout=15.0, follow_redirects=True, cookies={"eridian_echo_session": cookie_val}) as client:
        res = client.get(echo_url)
        assert res.status_code == 200
        assert "Welcome, Live Test Runner" in res.text
        assert "Sign Out" in res.text

def test_eridian_echo_job_lifecycle_and_upload(creds):
    if creds.get("skip_gemini_upload"):
        pytest.skip("Skipping Gemini upload test per SKIP_GEMINI_UPLOAD flag")

    if not FIXTURE_MP3.exists():
        pytest.skip(f"Test MP3 fixture not found at {FIXTURE_MP3}")

    base_url = creds["api_base_url"]
    upload_url = f"{base_url}/api/v1/eridian-echo/upload"
    jobs_url = f"{base_url}/api/v1/eridian-echo/jobs"
    cookie_val = creds.get("eridian_echo_cookie")

    cookies = {"eridian_echo_session": cookie_val} if cookie_val else {}
    test_filename = f"livetest-{uuid.uuid4().hex[:8]}.mp3"

    with httpx.Client(timeout=60.0, follow_redirects=True, cookies=cookies) as client:
        # If no cookie provided, establish a session first
        if not cookie_val:
            init_res = client.get(f"{base_url}/api/v1/eridian-echo/")
            assert init_res.status_code == 200

        # Upload the file
        with open(FIXTURE_MP3, "rb") as f:
            files = {"file": (test_filename, f, "audio/mpeg")}
            upload_res = client.post(upload_url, files=files)

        assert upload_res.status_code == 200, f"Upload failed: {upload_res.text}"
        job_data = upload_res.json()
        assert "id" in job_data
        job_id = job_data["id"]
        assert job_data["filename"] == test_filename
        assert job_data["status"] in ("queued", "processing", "succeeded")

        # Poll job status (up to 45 seconds for Gemini processing)
        terminal_status = None
        for _ in range(15):
            time.sleep(3)
            get_job_res = client.get(f"{jobs_url}/{job_id}")
            assert get_job_res.status_code == 200
            current_job = get_job_res.json()
            status = current_job.get("status")
            if status in ("succeeded", "failed"):
                terminal_status = status
                break

        assert terminal_status in ("succeeded", "failed", "processing", "queued"), "Invalid job status"
        if terminal_status == "succeeded":
            assert current_job.get("transcript") is not None
            print(f"Transcription succeeded: {len(current_job.get("transcript"))} chars")

        # Delete the job (clean up test artifact)
        del_res = client.delete(f"{jobs_url}/{job_id}")
        assert del_res.status_code in (200, 204)

        # Verify job is gone
        verify_del = client.get(f"{jobs_url}/{job_id}")
        assert verify_del.status_code == 404
