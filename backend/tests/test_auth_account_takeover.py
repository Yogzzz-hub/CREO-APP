"""Regression: no anonymous request may set an existing account's password.

POST /auth/direct-reset-password once took {email, new_password} with no OTP or reset token, so anyone
who knew an email (admins included) could take the account over."""

from types import SimpleNamespace
from unittest.mock import AsyncMock

from fastapi.testclient import TestClient

from app.core.security import hash_password, verify_password
from app.db.session import get_db
from app.main import app
from app.models.enums import AccountStatus, UserRole
from app.routers import auth


def test_anonymous_direct_password_reset_is_not_possible(monkeypatch):
    victim = SimpleNamespace(
        email="admin-dummy@example.com", role=UserRole.ADMIN, account_status=AccountStatus.ACTIVE,
        hashed_password=hash_password("Original-Pass-123"), token_version=0,
        email_verified_at=None, must_reset_password=False,
    )
    monkeypatch.setattr(auth, "_get_user_by_email", AsyncMock(return_value=victim))
    db = SimpleNamespace(commit=AsyncMock(), refresh=AsyncMock())

    async def fake_db():
        yield db

    app.dependency_overrides[get_db] = fake_db
    try:
        response = TestClient(app).post(
            "/api/v1/auth/direct-reset-password",
            json={"email": victim.email, "new_password": "Attacker-Pass-123"},
        )
    finally:
        app.dependency_overrides.pop(get_db, None)

    assert response.status_code in (404, 405), response.text
    assert verify_password("Original-Pass-123", victim.hashed_password)
    db.commit.assert_not_awaited()
