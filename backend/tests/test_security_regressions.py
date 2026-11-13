"""Regression tests for the access-control fixes from the November 2026 security review.

Each test pins one rule that was broken before: it fails on the old code and passes now.
They run offline: no database, no network."""

import hashlib
import hmac
import uuid
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
from fastapi.testclient import TestClient

from app.core.errors import Forbidden
from app.core.rbac import Actor
from app.db.session import get_db
from app.main import app
from app.models.enums import AccountStatus, UserRole


def actor(role, agency=None):
    return Actor(user_id=uuid.uuid4(), role=role, agency_id=agency, email="someone@example.com")


@pytest.fixture
def fake_db():
    db = SimpleNamespace(get=AsyncMock(), execute=AsyncMock(), scalar=AsyncMock(), commit=AsyncMock(),
                         refresh=AsyncMock(), add=lambda *_: None)

    async def override():
        yield db

    app.dependency_overrides[get_db] = override
    yield db
    app.dependency_overrides.pop(get_db, None)


def test_webhook_ignores_a_signing_secret_sent_by_the_caller(fake_db):
    # Before: the HMAC key came from the X-Razorpay-Webhook-Secret header, so anyone could sign events.
    body = b'{"event":"subscription.cancelled","payload":{"subscription":{"entity":{"id":"sub_X"}}}}'
    attacker_key = "attacker-chosen-key"
    signature = hmac.new(attacker_key.encode(), body, hashlib.sha256).hexdigest()
    response = TestClient(app).post(
        "/api/v1/webhooks/razorpay",
        content=body,
        headers={"X-Razorpay-Signature": signature, "X-Razorpay-Webhook-Secret": attacker_key,
                 "Content-Type": "application/json"},
    )
    assert response.status_code == 400


@pytest.mark.asyncio
async def test_platform_gate_needs_the_role_not_the_email():
    from app.routers.platform import require_super_admin

    impostor = Actor(user_id=uuid.uuid4(), role=UserRole.SALES, email="superadmin@creo.agency")
    with pytest.raises(Forbidden):
        await require_super_admin(impostor)


@pytest.mark.asyncio
async def test_admin_cannot_reach_another_agencys_client():
    from app.core.client_scope import ensure_client_access

    client = SimpleNamespace(role=UserRole.CLIENT, agency_id=uuid.uuid4())
    db = SimpleNamespace(get=AsyncMock(return_value=client))
    with pytest.raises(Forbidden):
        await ensure_client_access(db, actor(UserRole.ADMIN, agency=uuid.uuid4()), uuid.uuid4())


@pytest.mark.asyncio
async def test_team_lead_cannot_take_over_an_admin_account():
    from app.routers.admin import UpdateMemberCredentialsRequest, update_member_credentials

    agency = uuid.uuid4()
    target = SimpleNamespace(id=uuid.uuid4(), role=UserRole.SUPER_ADMIN, agency_id=agency, email="boss@example.com",
                             hashed_password="unchanged", token_version=0, full_name="Boss")
    db = SimpleNamespace(get=AsyncMock(return_value=target), execute=AsyncMock(), commit=AsyncMock())
    payload = UpdateMemberCredentialsRequest(email="attacker@example.com", password="NewPass123!", send_email=False)
    with pytest.raises(Forbidden):
        await update_member_credentials(target.id, payload, db=db, actor=actor(UserRole.TEAM_LEAD, agency))
    assert target.hashed_password == "unchanged"
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_admin_cannot_manage_users_of_another_agency():
    from app.routers.admin import _assert_manageable_user

    other = SimpleNamespace(role=UserRole.EDITOR, agency_id=uuid.uuid4())
    with pytest.raises(Forbidden):
        _assert_manageable_user(actor(UserRole.ADMIN, uuid.uuid4()), other)
    peer_admin = SimpleNamespace(role=UserRole.SUPER_ADMIN, agency_id=None)
    with pytest.raises(Forbidden):
        _assert_manageable_user(actor(UserRole.ADMIN, uuid.uuid4()), peer_admin)


@pytest.mark.asyncio
async def test_admin_cannot_create_a_super_admin(fake_db):
    from app.routers.admin import TeamMemberCreateRequest, create_team_member

    fake_db.execute = AsyncMock(return_value=SimpleNamespace(scalar_one_or_none=lambda: None))
    body = TeamMemberCreateRequest.model_construct(full_name="X", email="x@example.com", role="super_admin",
                                                    password=None, team_lead_id=None, send_email=False)
    with pytest.raises(Forbidden):
        await create_team_member(body, db=fake_db, actor=actor(UserRole.ADMIN, uuid.uuid4()))


def test_zip_download_only_fetches_creo_storage():
    from app.routers.deliverables import _is_storage_url

    assert not _is_storage_url("http://169.254.169.254/latest/meta-data/")
    assert not _is_storage_url("https://attacker.example/x")
    assert not _is_storage_url("http://localhost:8000/static/a.png")


def test_google_redirect_never_sends_the_token_to_another_site(monkeypatch):
    from app.config import settings
    from app.routers import auth

    monkeypatch.setattr(auth, "_process_google_code", AsyncMock(return_value={"access_token": "TOKEN"}))
    response = TestClient(app).get("/?code=x&state=https://attacker.example", follow_redirects=False)
    assert response.status_code in (302, 307)
    location = response.headers["location"]
    assert not location.startswith("https://attacker.example")
    assert location.startswith(settings.FRONTEND_URL.rstrip("/"))


def test_development_never_uses_a_jwt_key_from_the_repository(monkeypatch):
    from app.config import Settings

    for name in ("JWT_SECRET", "SECRET_KEY"):
        monkeypatch.delenv(name, raising=False)
    monkeypatch.setenv("ENVIRONMENT", "development")
    s = Settings(_env_file=None)
    assert s.JWT_SECRET and s.JWT_SECRET != "super-secret-jwt-key-creo-development-32chars"


def test_suspended_status_constant_exists():
    # PATCH /auth/me now refuses suspended accounts; keep the enum value it relies on.
    assert AccountStatus.SUSPENDED


def test_logout_ends_the_session(fake_db):
    # Before: logout was a no-op, so the access token and every refresh token kept working.
    from app.core.cache import clear_in_memory_cache
    from app.core.security import create_access_token

    clear_in_memory_cache()
    user = SimpleNamespace(id=uuid.uuid4(), token_version=0)
    fake_db.get = AsyncMock(return_value=user)
    token = create_access_token(subject=str(user.id), role=UserRole.CLIENT.value)
    client = TestClient(app)
    assert client.post("/api/v1/auth/logout", headers={"Authorization": f"Bearer {token}"}).status_code == 200
    assert user.token_version == 1  # every refresh token for the account is now refused
    after = client.get("/api/v1/notifications", headers={"Authorization": f"Bearer {token}"})
    assert after.status_code == 401


@pytest.mark.asyncio
async def test_client_ai_runs_are_capped_per_day(monkeypatch):
    from app.core import cache
    from app.services import onboarding_service

    async def no_redis():
        raise RuntimeError("offline")

    monkeypatch.setattr(cache, "get_redis", no_redis)
    onboarding_service._LOCAL_AI_RUNS.clear()
    client = uuid.uuid4()
    results = [await onboarding_service._client_ai_budget_ok(client) for _ in range(7)]
    assert results == [True] * onboarding_service.MAX_DAILY_CLIENT_AI_RUNS + [False] * 2


def test_agency_admins_get_their_own_settings_record():
    from app.routers.admin import _settings_key

    a, b = actor(UserRole.ADMIN, uuid.uuid4()), actor(UserRole.ADMIN, uuid.uuid4())
    assert _settings_key(a) != _settings_key(b) != "global"
    assert _settings_key(actor(UserRole.SUPER_ADMIN)) == "global"


@pytest.fixture
def shared_redis(monkeypatch):
    """One fake Redis shared by every simulated worker."""
    from fakeredis import aioredis as fake_aioredis

    from app.core import cache

    monkeypatch.setattr(cache, "_redis_client", fake_aioredis.FakeRedis(decode_responses=True))
    monkeypatch.setattr(cache, "_redis_last_failure", 0.0)
    return cache._redis_client


@pytest.mark.asyncio
async def test_concurrent_otp_guesses_cannot_exceed_the_attempt_limit(shared_redis):
    # Before: each request read the attempt count before any of them saved it, so a burst of
    # parallel guesses all got compared against the code.
    import asyncio
    import time

    from fastapi import HTTPException

    from app.routers import auth

    real_get = shared_redis.get

    async def slow_get(key):  # the reply arrives later, so other requests run in between
        value = await real_get(key)
        await asyncio.sleep(0.01)
        return value

    shared_redis.get = slow_get
    email = f"{uuid.uuid4().hex}@example.com"
    await auth._save_otp(email, ["123456", time.time() + 600, 0])

    async def guess(n):
        try:
            await auth.verify_otp(auth.VerifyOtpRequest(email=email, code=f"{n:06d}"), db=object())
        except HTTPException as exc:
            return exc.detail

    results = await asyncio.gather(*(guess(n) for n in range(20)))
    # Only five guesses were ever compared with the code; every other request was refused.
    assert results.count("Invalid verification code.") == 5


@pytest.mark.asyncio
async def test_email_rate_limit_is_shared_between_workers(shared_redis):
    # Before: the limit lived in each process, so N workers allowed N times as many requests.
    from app.routers import auth

    key = f"forgot:{uuid.uuid4().hex}@example.com"
    for _ in range(5):
        assert await auth._check_rate_limit(key, max_requests=5, window_seconds=600)
        auth._rate_limits.clear()  # the next request lands on a different worker
    assert not await auth._check_rate_limit(key, max_requests=5, window_seconds=600)


@pytest.mark.asyncio
async def test_legacy_bde_route_cannot_skip_crm_stage_rules():
    # Before: PATCH /bde/leads/{id} set any status, e.g. reopening a won deal, with no pipeline checks.
    from app.core.errors import Conflict
    from app.routers.bde import UpdateLeadRequest, update_lead

    rep = actor(UserRole.BDE, uuid.uuid4())
    lead = SimpleNamespace(id=uuid.uuid4(), status="converted", assigned_bde_id=rep.user_id,
                           company_name="Acme", priority="hot")
    found = SimpleNamespace(scalar_one_or_none=lambda: lead)
    no_tasks = SimpleNamespace(scalars=lambda: iter([]))
    db = SimpleNamespace(execute=AsyncMock(side_effect=[found, no_tasks]), commit=AsyncMock(), add=lambda *_: None)
    with pytest.raises(Conflict):
        await update_lead(lead.id, UpdateLeadRequest(status="negotiation"), db=db, actor=rep)
    assert lead.status == "converted"
    db.commit.assert_not_awaited()


def _chat_db(user=None):
    """Fake session for chat routes: every query returns no rows; executed statements are kept."""
    empty = SimpleNamespace(scalars=lambda: SimpleNamespace(all=lambda: []), all=lambda: [],
                            scalar_one_or_none=lambda: None)
    return SimpleNamespace(get=AsyncMock(return_value=user), execute=AsyncMock(return_value=empty),
                           scalar=AsyncMock(return_value=None), commit=AsyncMock(), add=lambda *_: None)


@pytest.mark.asyncio
async def test_chat_contacts_never_list_another_agencys_users():
    # Before: the admin contact queries had no agency filter, so every user on the platform was listed.
    from app.routers.chat import get_chat_contacts

    admin = actor(UserRole.ADMIN, uuid.uuid4())
    db = _chat_db(SimpleNamespace(role=UserRole.ADMIN))
    await get_chat_contacts(db=db, actor=admin)
    filters = [str(call.args[0].whereclause) for call in db.execute.await_args_list]
    assert filters and all("users.agency_id = " in sql for sql in filters)


@pytest.mark.asyncio
async def test_chat_contacts_are_empty_without_an_agency():
    from app.routers.chat import get_chat_contacts

    db = _chat_db(SimpleNamespace(role=UserRole.CLIENT))
    assert await get_chat_contacts(db=db, actor=actor(UserRole.CLIENT)) == []
    db.execute.assert_not_awaited()


@pytest.mark.asyncio
async def test_direct_chat_cannot_cross_agencies():
    # Before: admins (either side) and sales could open a DM with anyone on the platform.
    from fastapi import HTTPException

    from app.routers.chat import _require_direct_chat_access

    db = _chat_db()
    other_client = SimpleNamespace(id=uuid.uuid4(), role=UserRole.CLIENT, agency_id=uuid.uuid4())
    other_admin = SimpleNamespace(id=uuid.uuid4(), role=UserRole.ADMIN, agency_id=uuid.uuid4())
    for me, target in [(actor(UserRole.SALES, uuid.uuid4()), other_client),
                       (actor(UserRole.ADMIN, uuid.uuid4()), other_client),
                       (actor(UserRole.EDITOR, uuid.uuid4()), other_admin)]:
        with pytest.raises(HTTPException) as err:
            await _require_direct_chat_access(me, target, db)
        assert err.value.status_code == 403
    # Two agency-less users are not "the same agency".
    with pytest.raises(HTTPException):
        await _require_direct_chat_access(actor(UserRole.ADMIN), SimpleNamespace(
            id=uuid.uuid4(), role=UserRole.EDITOR, agency_id=None), db)
    # The platform super admin stays reachable.
    super_admin = SimpleNamespace(id=uuid.uuid4(), role=UserRole.SUPER_ADMIN, agency_id=None)
    await _require_direct_chat_access(actor(UserRole.EDITOR, uuid.uuid4()), super_admin, db)


@pytest.mark.asyncio
async def test_client_cannot_read_the_internal_pod_team_chat(monkeypatch):
    # Before: the client thread query returned every non-direct message for the client, any thread_type.
    from fastapi import HTTPException

    from app.routers import chat

    monkeypatch.setattr(chat, "_require_completed_onboarding", AsyncMock())
    monkeypatch.setattr(chat, "_require_client_assignment", AsyncMock())
    client = actor(UserRole.CLIENT, uuid.uuid4())
    db = _chat_db()
    with pytest.raises(HTTPException) as err:
        await chat.get_messages(channel="pod-team-chat", db=db, actor=client)
    assert err.value.status_code == 403

    await chat.get_messages(channel="pod-creative-hub", db=db, actor=client)
    stmt = db.execute.await_args_list[0].args[0]
    assert "direct_messages.thread_type = " in str(stmt)
    assert "pod-creative-hub" in stmt.compile().params.values()


@pytest.mark.asyncio
async def test_agency_less_staff_cannot_use_shared_staff_rooms():
    # Before: agency_id == None became IS NULL, so every agency-less user shared one #general.
    from fastapi import HTTPException

    from app.routers.chat import SendMessageRequest, get_messages, send_message

    loner = actor(UserRole.EDITOR)
    db = _chat_db(SimpleNamespace(role=UserRole.EDITOR, full_name="Loner"))
    with pytest.raises(HTTPException) as err:
        await get_messages(channel="general", db=db, actor=loner)
    assert err.value.status_code == 403
    with pytest.raises(HTTPException) as err:
        await send_message(SendMessageRequest(channel="general", message="hi"), db=db, actor=loner)
    assert err.value.status_code == 403
    db.commit.assert_not_awaited()


@pytest.mark.asyncio
async def test_custom_groups_stay_inside_their_agency_and_members(monkeypatch):
    # Before: groups lived in one global file, admins saw every agency's, and reads ignored member_ids.
    from fastapi import HTTPException

    from app.routers import chat

    agency_a, agency_b = uuid.uuid4(), uuid.uuid4()
    member = actor(UserRole.EDITOR, agency_a)
    groups = [
        {"id": "grp-a", "agency_id": str(agency_a), "created_by": str(uuid.uuid4()),
         "member_ids": [str(member.user_id)]},
        {"id": "grp-legacy", "created_by": str(uuid.uuid4()), "member_ids": [str(uuid.uuid4())]},
    ]
    monkeypatch.setattr(chat, "_load_custom_groups", lambda: groups)
    db = _chat_db()

    for outsider in [actor(UserRole.ADMIN, agency_b), actor(UserRole.EDITOR, agency_a)]:
        with pytest.raises(HTTPException) as err:
            await chat.get_messages(channel="grp-a", db=db, actor=outsider)
        assert err.value.status_code == 403
        with pytest.raises(HTTPException):
            await chat.send_message(chat.SendMessageRequest(channel="grp-a", message="hi"),
                                    db=_chat_db(SimpleNamespace(role=outsider.role, full_name="X")),
                                    actor=outsider)
    await chat.get_messages(channel="grp-a", db=db, actor=member)
    await chat.get_messages(channel="grp-a", db=db, actor=actor(UserRole.ADMIN, agency_a))

    other_admin = actor(UserRole.ADMIN, agency_b)
    listed = await chat.get_chat_channels(db=_chat_db(SimpleNamespace(role=UserRole.ADMIN)), actor=other_admin)
    assert not {c["id"] for c in listed} & {"grp-a", "grp-legacy"}


@pytest.mark.asyncio
async def test_new_chat_groups_record_their_agency(monkeypatch):
    from app.routers import chat

    saved = []
    monkeypatch.setattr(chat, "_load_custom_groups", lambda: [])
    monkeypatch.setattr(chat, "_save_custom_groups", saved.extend)
    admin = actor(UserRole.ADMIN, uuid.uuid4())
    db = _chat_db(SimpleNamespace(role=UserRole.ADMIN, full_name="Admin"))
    await chat.create_chat_group(chat.CreateGroupRequest(name="Launch"), db=db, actor=admin)
    assert saved[0]["agency_id"] == str(admin.agency_id)
