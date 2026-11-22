# ruff: noqa: E402 -- Validate disposable database settings before application imports.
"""A BDE's chat contacts load more than once when a lead has no email.

Opt in using TEST_DATABASE_URL pointing to a migrated, disposable localhost
database named creo_test_*. This suite never uses the application's configured DB.
"""

import os
import unittest
import uuid
from urllib.parse import urlparse

TEST_URL = os.getenv("TEST_DATABASE_URL", "")
if TEST_URL:
    parsed = urlparse(TEST_URL)
    if parsed.hostname not in ("localhost", "127.0.0.1") or not parsed.path.startswith(
        "/creo_test_"
    ):
        raise RuntimeError("TEST_DATABASE_URL must point to a disposable localhost creo_test_* DB")
    os.environ["DATABASE_URL"] = TEST_URL
    os.environ["DIRECT_DATABASE_URL"] = TEST_URL
    os.environ["DB_USE_NULLPOOL"] = "true"

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.rbac import Actor
from app.models.crm import Lead
from app.models.enums import AccountStatus, UserRole
from app.models.tenant import Agency
from app.models.user import User
from app.routers.chat import get_chat_contacts


@unittest.skipUnless(TEST_URL, "Set TEST_DATABASE_URL to a migrated disposable local DB")
class BdeContactsTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.engine = create_async_engine(TEST_URL, poolclass=NullPool)
        self.factory = async_sessionmaker(self.engine, expire_on_commit=False, autoflush=False)
        self.agency_id, self.bde_id, self.lead_id = uuid.uuid4(), uuid.uuid4(), uuid.uuid4()
        tag = f"bde{self.agency_id.hex[:8]}"
        async with self.factory() as db:
            db.add(Agency(id=self.agency_id, name=tag, slug=tag, status="active"))
            await db.flush()
            db.add(User(
                id=self.bde_id, agency_id=self.agency_id, auth_id=str(self.bde_id),
                email=f"bde-{tag}@example.test", full_name="BDE", role=UserRole.SALES,
                account_status=AccountStatus.ACTIVE,
            ))
            await db.flush()
            db.add(Lead(
                id=self.lead_id, agency_id=self.agency_id, assigned_bde_id=self.bde_id,
                name="No Email Prospect", company_name="Quiet Co", email=None,
            ))
            await db.commit()

    async def asyncTearDown(self):
        await self.engine.dispose()

    async def test_lead_without_email_is_provisioned_once(self):
        actor = Actor(user_id=self.bde_id, role=UserRole.SALES, agency_id=self.agency_id)
        prospect = f"prospect_{self.lead_id}@creo.agency"
        for _ in range(2):  # Before: the second load inserted the same email again and failed.
            async with self.factory() as db:
                contacts = await get_chat_contacts(db=db, actor=actor)
            self.assertEqual([c["email"] for c in contacts if c.get("is_client")], [prospect])
        async with self.factory() as db:
            count = await db.scalar(select(func.count()).select_from(User).where(User.email == prospect))
        self.assertEqual(count, 1)
