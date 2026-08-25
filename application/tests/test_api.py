from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_root():
    response = client.get("/")

    assert response.status_code == 200

    data = response.json()

    assert data["application"] == "FieldOps API"
    assert data["status"] == "running"


def test_health():
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}


def test_create_site():
    payload = {
        "name": "Test Site",
        "location": "Offshore Block A",
        "country": "Nigeria",
        "status": "active",
    }

    response = client.post("/api/v1/sites", json=payload)

    assert response.status_code == 201

    data = response.json()

    assert data["name"] == "Test Site"
    assert data["country"] == "Nigeria"
    assert "id" in data
    assert "created_at" in data