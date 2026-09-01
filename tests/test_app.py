from fastapi.testclient import TestClient

from app import app


client = TestClient(app)


def test_health():
    response = client.get("/health")

    assert response.status_code == 200
    assert response.text == "Healthy\n"


def test_ready_without_secret(monkeypatch):
    monkeypatch.delenv("APP_SECRET", raising=False)

    response = client.get("/ready")

    assert response.status_code == 503
    assert response.text == "Not ready\n"


def test_ready_with_secret(monkeypatch):
    monkeypatch.setenv("APP_SECRET", "test-secret")

    response = client.get("/ready")

    assert response.status_code == 200
    assert response.text == "Ready\n"

def test_secret_without_configured_secret(monkeypatch):
    monkeypatch.delenv("APP_SECRET", raising=False)

    response = client.get("/secret")

    assert response.status_code == 503
    assert response.text == "Service unavailable\n"


def test_secret_without_api_key(monkeypatch):
    monkeypatch.setenv("APP_SECRET", "test-secret")

    response = client.get("/secret")

    assert response.status_code == 401
    assert response.text == "Unauthorized\n"


def test_secret_with_wrong_api_key(monkeypatch):
    monkeypatch.setenv("APP_SECRET", "test-secret")

    response = client.get(
        "/secret",
        headers={"X-API-Key": "wrong-secret"},
    )

    assert response.status_code == 401
    assert response.text == "Unauthorized\n"


def test_secret_with_correct_api_key(monkeypatch):
    monkeypatch.setenv("APP_SECRET", "test-secret")

    response = client.get(
        "/secret",
        headers={"X-API-Key": "test-secret"},
    )

    assert response.status_code == 200
    assert response.text == "Secret access granted\n"


def test_unknown_endpoint():
    response = client.get("/does-not-exist")

    assert response.status_code == 404