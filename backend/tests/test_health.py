"""Basic health and smoke tests for the ERP API."""
from fastapi.testclient import TestClient
from app.main import app


client = TestClient(app)


def test_root():
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["version"] == "4.3.0"


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert "status" in response.json()


def test_login_requires_credentials():
    response = client.post("/api/auth/login", json={})
    assert response.status_code == 422  # Validation error


def test_protected_endpoint_requires_auth():
    response = client.get("/api/dashboard/summary")
    assert response.status_code == 401
