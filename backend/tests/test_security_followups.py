import uuid
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.core.errors import Forbidden
from app.models.enums import UserRole


@pytest.mark.asyncio
async def test_public_proposal_hides_the_agency_price_floor(monkeypatch):
    from app.routers import revenue_crm as routes

    row = SimpleNamespace(status="viewed")
    monkeypatch.setattr(routes, "shared", AsyncMock(return_value=row))
    monkeypatch.setattr(routes.service, "serialize", lambda _row: {
        "id": "p1", "number": "P-1", "version": 1, "title": "Offer", "status": "viewed",
        "currency": "INR", "valid_until": datetime.now(UTC) + timedelta(days=5),
        "snapshot": {"items": [{"name": "Reels", "unit_price": 900, "minimum_price": 700,
                                "catalog_price": 1000, "service_id": "s1"}], "totals": {}},
    })
    view = await routes.shared_proposal("token", db=SimpleNamespace())
    item = view["snapshot"]["items"][0]
    assert item == {"name": "Reels", "unit_price": 900}


@pytest.mark.asyncio
async def test_admin_cannot_open_another_agencys_taskless_deliverable():
    from app.services import deliverable_workflow

    deliverable = SimpleNamespace(task_id=None, agency_id=uuid.uuid4(), client_id=uuid.uuid4())
    db = SimpleNamespace(get=AsyncMock(return_value=deliverable))
    for agency in (uuid.uuid4(), None):
        actor = SimpleNamespace(user_id=uuid.uuid4(), role=UserRole.ADMIN, agency_id=agency)
        with pytest.raises(Forbidden):
            await deliverable_workflow.get_deliverable_for_review(db, actor, uuid.uuid4())
