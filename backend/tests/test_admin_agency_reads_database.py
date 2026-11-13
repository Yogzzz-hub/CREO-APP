# ruff: noqa: E402 -- Validate disposable database settings before application imports.
"""Admin dashboard, KPI, export and roster reads stay inside the caller's agency.

Opt in using TEST_DATABASE_URL pointing to a migrated, disposable localhost
database named creo_test_*. This suite never uses the application's configured DB.
"""

import json
import os
import unittest
import uuid
from datetime import UTC, datetime, timedelta
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

from fastapi.encoders import jsonable_encoder
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.core.errors import Forbidden
from app.core.rbac import Actor
from app.models.billing import Plan, Subscription
from app.models.enums import (
    AccountStatus,
    DeliverableType,
    PaymentProvider,
    SubscriptionStatus,
    TaskStatus,
    UserRole,
)
from app.models.ops import Announcement
from app.models.tenant import Agency
from app.models.user import ClientProfile, StaffProfile, User
from app.models.work import Task
from app.routers import admin


@unittest.skipUnless(TEST_URL, "Set TEST_DATABASE_URL to a migrated disposable local DB")
class AdminAgencyReadTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.engine = create_async_engine(TEST_URL, poolclass=NullPool)
        self.factory = async_sessionmaker(self.engine, expire_on_commit=False, autoflush=False)
        self.ids = {}
        self.marker = {}
        async with self.factory() as db:
            for name in ("alpha", "beta"):
                agency_id = uuid.uuid4()
                tag = f"{name}{agency_id.hex[:8]}"
                self.marker[name] = tag
                db.add(Agency(id=agency_id, name=tag, slug=tag, status="active"))
                await db.flush()
                ids = {"agency": agency_id}
                for role in (UserRole.CLIENT, UserRole.ADMIN, UserRole.EDITOR, UserRole.SALES, UserRole.FREELANCER):
                    uid = uuid.uuid4()
                    ids[role.value] = uid
                    db.add(User(
                        id=uid, agency_id=agency_id, auth_id=str(uid),
                        email=f"{role.value}-{tag}@example.test", full_name=f"{role.value} {tag}",
                        role=role, account_status=AccountStatus.ACTIVE,
                    ))
                await db.flush()
                db.add(ClientProfile(user_id=ids["client"], company_name=f"Company {tag}"))
                db.add(StaffProfile(user_id=ids["editor"], agency_id=agency_id))
                plan_id = uuid.uuid4()
                db.add(Plan(id=plan_id, agency_id=agency_id, name=tag, display_name=tag, revision_rounds=3))
                await db.flush()
                db.add(Subscription(
                    client_id=ids["client"], agency_id=agency_id, plan_id=plan_id,
                    status=SubscriptionStatus.ACTIVE, gateway=PaymentProvider.STRIPE,
                    amount=100 if name == "alpha" else 900,
                    current_period_start=datetime.now(UTC) - timedelta(days=1),
                    current_period_end=datetime.now(UTC) + timedelta(days=30),
                ))
                db.add(Task(
                    agency_id=agency_id, client_id=ids["client"], assigned_to=ids["editor"],
                    deliverable_type=DeliverableType.STATIC_POST, status=TaskStatus.IN_PRODUCTION,
                    sla_due_at=datetime.now(UTC) - timedelta(hours=1),
                ))
                db.add(Announcement(author_id=ids["admin"], agency_id=agency_id, title=tag, content=tag))
                self.ids[name] = ids
            await db.commit()

    async def asyncTearDown(self):
        await self.engine.dispose()

    def actor(self, name, role=UserRole.ADMIN):
        ids = self.ids[name]
        return Actor(user_id=ids.get(role.value, uuid.uuid4()), role=role, agency_id=ids["agency"])

    async def call(self, route, actor, **kwargs):
        async with self.factory() as db:
            result = await route(db=db, actor=actor, **kwargs)
        body = getattr(result, "body", None)
        return body.decode() if body is not None else json.dumps(jsonable_encoder(result))

    async def test_agency_admin_reads_never_include_another_agency(self):
        alpha, beta = self.actor("alpha"), self.marker["beta"]
        routes = [
            (admin.get_kpis, {"timeframe": "30d"}),
            (admin.export_admin_report, {"report_type": "clients"}),
            (admin.get_revenue_trend, {"timeframe": "30d"}),
            (admin.get_plans_summary, {}),
            (admin.get_dashboard, {"timeframe": "30d"}),
            (admin.get_dispatch_queue, {}),
            (admin.get_sla_breaches, {}),
            (admin.get_sla_performance, {}),
            (admin.get_announcements, {}),
            (admin.get_team_members, {}),
            (admin.list_bde_team, {}),
            (admin.get_sla_escalations, {}),
            (admin.get_admin_sales, {}),
            (admin.get_admin_reports, {}),
            (admin.get_recent_transactions, {}),
            (admin.list_admin_team_roster, {}),
            (admin.list_admin_leave_requests, {}),
            (admin.list_freelancers, {}),
            (admin.list_admin_deliverables, {"client_id": None}),
        ]
        for route, kwargs in routes:
            with self.subTest(route=route.__name__):
                body = await self.call(route, alpha, **kwargs)
                self.assertNotIn(beta, body)
                self.assertNotIn(str(self.ids["beta"]["client"]), body)

    async def test_agency_totals_count_only_the_callers_clients(self):
        kpis = json.loads(await self.call(admin.get_kpis, self.actor("alpha"), timeframe="30d"))
        dashboard = json.loads(await self.call(admin.get_dashboard, self.actor("alpha"), timeframe="30d"))
        # Other test runs may leave rows behind, so compare the two agencies directly.
        beta_kpis = json.loads(await self.call(admin.get_kpis, self.actor("beta"), timeframe="30d"))
        self.assertEqual(kpis["active_clients"], 1)
        self.assertEqual(kpis["mrr_minor"], 100 * 100)
        self.assertEqual(beta_kpis["mrr_minor"], 900 * 100)
        self.assertEqual(dashboard["open_sla_breaches"], 1)

    async def test_admin_without_an_agency_is_refused(self):
        lost = Actor(user_id=uuid.uuid4(), role=UserRole.ADMIN, agency_id=None)
        with self.assertRaises(Forbidden):
            await self.call(admin.get_kpis, lost, timeframe="30d")

    async def test_super_admin_still_sees_every_agency(self):
        root = Actor(user_id=uuid.uuid4(), role=UserRole.SUPER_ADMIN, agency_id=None)
        body = await self.call(admin.export_admin_report, root, report_type="clients")
        self.assertIn(self.marker["alpha"], body)
        self.assertIn(self.marker["beta"], body)
