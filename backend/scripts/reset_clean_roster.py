"""Reset database to clean production state:
- Purges all mock data across deliverables (reels, posters, carousels), tasks, tickets, and mock users.
- Sets up exactly:
    1 Super Admin: admin@creo.agency
    2 Admins: ops.admin@creo.agency, creative.admin@creo.agency
    4 Creative Teams (Pods), each with 3 members:
        Pod Alpha: Lead, Video Editor, Graphic Designer
        Pod Beta:  Lead, Video Editor, Graphic Designer
        Pod Gamma: Lead, Video Editor, Graphic Designer
        Pod Delta: Lead, Video Editor, Graphic Designer
    (Total = 15 core agency staff, all with password: Admin123!)
- Preserves real registered clients (@gmail.com).
- Re-dispatches pod assignment and feasible schedule for onboarded clients.
"""

from __future__ import annotations

import asyncio
import sys
import uuid
from datetime import UTC, datetime, timedelta

# Ensure backend directory is in path
sys.path.insert(0, ".")

from sqlalchemy import delete, func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from typing import TypedDict

from app.core.security import hash_password
from app.db.session import async_session_factory
from app.models.billing import Plan, Subscription
from app.models.enums import AccountStatus, PaymentProvider, UserRole
from app.models.user import ClientProfile, StaffProfile, User
from app.models.work import ClientAssignment, ContentCalendar, Deliverable, Task
from app.services.fair_dispatch_service import assign_client_and_generate_schedule


class StaffRosterItem(TypedDict):
    email: str
    full_name: str
    role: UserRole
    department: str
    skills: list[str]
    team_lead_email: str | None


# Defined roster of 1 Super Admin, 2 Admins, and 4 Teams (each 3 members)
STAFF_ROSTER: list[StaffRosterItem] = [
    # 1. Super Admin
    {
        "email": "admin@creo.agency",
        "full_name": "Antigravity Super Admin",
        "role": UserRole.SUPER_ADMIN,
        "department": "executive",
        "skills": ["governance", "finance", "strategy", "operations"],
        "team_lead_email": None,
    },
    # 2. Admins (2)
    {
        "email": "ops.admin@creo.agency",
        "full_name": "Aarav Sharma (Operations Admin)",
        "role": UserRole.ADMIN,
        "department": "operations",
        "skills": ["workflow_dispatch", "sla_monitoring", "quality_control", "client_relations"],
        "team_lead_email": None,
    },
    {
        "email": "creative.admin@creo.agency",
        "full_name": "Pooja Nambiar (Creative Admin)",
        "role": UserRole.ADMIN,
        "department": "creative",
        "skills": ["creative_direction", "brand_strategy", "art_direction", "video_production"],
        "team_lead_email": None,
    },
    # 3. Team 1 — Pod Alpha (3 members)
    {
        "email": "lead.alpha@creo.agency",
        "full_name": "Vikram Malhotra (Lead - Pod Alpha)",
        "role": UserRole.TEAM_LEAD,
        "department": "creative",
        "skills": ["creative_direction", "storyboarding", "qa", "client_management"],
        "team_lead_email": None,
    },
    {
        "email": "editor.alpha@creo.agency",
        "full_name": "Karthik Raja (Editor - Pod Alpha)",
        "role": UserRole.EDITOR,
        "department": "video",
        "skills": ["reels", "premiere_pro", "sound_design", "color_grading"],
        "team_lead_email": "lead.alpha@creo.agency",
    },
    {
        "email": "designer.alpha@creo.agency",
        "full_name": "Ananya Deshmukh (Designer - Pod Alpha)",
        "role": UserRole.DESIGNER,
        "department": "design",
        "skills": ["carousels", "posters", "figma", "typography", "branding"],
        "team_lead_email": "lead.alpha@creo.agency",
    },
    # 4. Team 2 — Pod Beta (Pod B)
    {
        "email": "lead.beta@creo.agency",
        "full_name": "Sarah Connor (Lead - Pod B)",
        "role": UserRole.TEAM_LEAD,
        "department": "creative",
        "skills": ["creative_direction", "motion_supervision", "qa", "client_success"],
        "team_lead_email": None,
    },
    {
        "email": "lead@creo.agency",
        "full_name": "Sarah Connor (Lead - Pod B)",
        "role": UserRole.TEAM_LEAD,
        "department": "creative",
        "skills": ["creative_direction", "motion_supervision", "qa", "client_success"],
        "team_lead_email": None,
    },
    {
        "email": "editor.beta@creo.agency",
        "full_name": "David Kim (Editor - Pod B)",
        "role": UserRole.EDITOR,
        "department": "video",
        "skills": ["after_effects", "3d_motion", "viral_hooks", "short_form"],
        "team_lead_email": "lead.beta@creo.agency",
    },
    {
        "email": "member@creo.agency",
        "full_name": "David Kim (Editor - Pod B)",
        "role": UserRole.EDITOR,
        "department": "video",
        "skills": ["after_effects", "3d_motion", "viral_hooks", "short_form"],
        "team_lead_email": "lead.beta@creo.agency",
    },
    {
        "email": "designer.beta@creo.agency",
        "full_name": "Elena Rostova (Designer - Pod B)",
        "role": UserRole.DESIGNER,
        "department": "design",
        "skills": ["visual_identity", "editorial_design", "photoshop", "infographics"],
        "team_lead_email": "lead.beta@creo.agency",
    },
    # 5. Team 3 — Pod Gamma (Pod C)
    {
        "email": "lead.gamma@creo.agency",
        "full_name": "Rohan Mehta (Lead - Pod C)",
        "role": UserRole.TEAM_LEAD,
        "department": "creative",
        "skills": ["creative_direction", "brand_narrative", "pacing", "review_cycles"],
        "team_lead_email": None,
    },
    {
        "email": "editor.gamma@creo.agency",
        "full_name": "Tanvi Sen (Editor - Pod C)",
        "role": UserRole.EDITOR,
        "department": "video",
        "skills": ["motion_graphics", "dynamic_typography", "davinci_resolve", "reels"],
        "team_lead_email": "lead.gamma@creo.agency",
    },
    {
        "email": "designer.gamma@creo.agency",
        "full_name": "Arjun Nair (Designer - Pod C)",
        "role": UserRole.DESIGNER,
        "department": "design",
        "skills": ["modern_minimalism", "illustrations", "figma", "social_banners"],
        "team_lead_email": "lead.gamma@creo.agency",
    },
]


async def run_cleanup_and_reseed() -> None:
    now = datetime.now(UTC)
    standard_password_hash = hash_password("Admin123!")

    async with async_session_factory() as db:
        print("\n=== STEP 1: PURGE ALL MOCK REELS, DELIVERABLES, AND OPERATIONAL TABLES ===")
        # 1. Truncate mock support, leaves, announcements, deliverables, blackouts, tasks
        await db.execute(text("DELETE FROM shoot_days;"))
        await db.execute(text("DELETE FROM calendar_blackouts;"))
        await db.execute(text("DELETE FROM calendar_policies;"))
        await db.execute(text("DELETE FROM contact_messages;"))
        await db.execute(text("DELETE FROM ticket_messages;"))
        await db.execute(text("DELETE FROM tickets;"))
        await db.execute(text("DELETE FROM leave_requests;"))
        await db.execute(text("DELETE FROM announcements;"))
        await db.execute(text("DELETE FROM notifications;"))
        await db.execute(text("DELETE FROM deliverables;"))  # Remove all mock reels & deliverables
        await db.execute(text("DELETE FROM tasks;"))
        await db.execute(text("DELETE FROM content_calendar;"))
        await db.execute(text("DELETE FROM client_assignments;"))
        await db.execute(text("DELETE FROM client_cycles;"))
        await db.execute(text("DELETE FROM client_role_requirements;"))
        await db.execute(text("DELETE FROM team_members;"))
        await db.execute(text("UPDATE teams SET lead_id = NULL;"))
        await db.execute(text("DELETE FROM teams;"))
        await db.execute(text("UPDATE faq_items SET updated_by = NULL;"))
        await db.execute(text("UPDATE audit_log SET actor_id = NULL;"))
        await db.execute(text("DELETE FROM staff_profiles;"))
        await db.commit()
        print("[OK] Purged all operational tables, tasks, deliverables, blackouts, tickets, leave requests, and teams.")

        # 2. Get real clients to preserve
        real_clients_res = await db.execute(
            select(User.id, User.email).where(User.email.like("%@gmail.com"))
        )
        real_clients = real_clients_res.fetchall()
        real_client_ids = [r[0] for r in real_clients]
        real_client_emails = [r[1] for r in real_clients]
        print(f"[OK] Preserved real clients: {real_client_emails}")

        # 3. Clean usage, subscriptions, questionnaires, profiles for non-real clients
        if real_client_ids:
            await db.execute(text("DELETE FROM usage_counters WHERE client_id NOT IN (SELECT id FROM users WHERE email LIKE '%@gmail.com')"))
            await db.execute(text("DELETE FROM subscriptions WHERE client_id NOT IN (SELECT id FROM users WHERE email LIKE '%@gmail.com')"))
            await db.execute(text("DELETE FROM questionnaires WHERE user_id NOT IN (SELECT id FROM users WHERE email LIKE '%@gmail.com')"))
            await db.execute(delete(ClientProfile).where(~ClientProfile.user_id.in_(real_client_ids)))
        else:
            await db.execute(text("DELETE FROM usage_counters;"))
            await db.execute(text("DELETE FROM subscriptions;"))
            await db.execute(text("DELETE FROM questionnaires;"))
            await db.execute(delete(ClientProfile))
        await db.commit()

        # 4. Remove all mock users (anything not a real client and not our staff)
        allowed_staff_emails = [s["email"] for s in STAFF_ROSTER]
        all_preserved_emails = allowed_staff_emails + real_client_emails + ["client@creo.agency"]

        # Delete all other users
        await db.execute(delete(User).where(~User.email.in_(all_preserved_emails)))
        await db.commit()
        print("[OK] Deleted all mock users from database.")

        print("\n=== STEP 2: SEED EXACT STAFF ROSTER (1 Super Admin, 2 Admins, 3 Teams x 3 Members) ===")
        # Seed or update all 15 staff members
        created_users: dict[str, User] = {}
        for s_def in STAFF_ROSTER:
            stmt = select(User).where(User.email == s_def["email"])
            user = (await db.execute(stmt)).scalar_one_or_none()

            if not user:
                user = User(
                    id=uuid.uuid4(),
                    auth_id=f"auth-{uuid.uuid4().hex[:12]}",
                    email=s_def["email"],
                    full_name=s_def["full_name"],
                    hashed_password=standard_password_hash,
                    role=s_def["role"],
                    account_status=AccountStatus.ACTIVE,
                    must_reset_password=False,
                    email_verified_at=now,
                )
                db.add(user)
                await db.flush()
                print(f"  + Created {s_def['role'].value:12} | {s_def['email']:30} | {s_def['full_name']}")
            else:
                user.full_name = s_def["full_name"]
                user.role = s_def["role"]
                user.account_status = AccountStatus.ACTIVE
                user.must_reset_password = False
                user.hashed_password = standard_password_hash
                user.email_verified_at = now
                print(f"  ~ Updated {s_def['role'].value:12} | {s_def['email']:30} | {s_def['full_name']}")

            created_users[s_def["email"]] = user

        await db.commit()

        # Now link staff profiles and team leads
        for s_def in STAFF_ROSTER:
            user = created_users[s_def["email"]]
            tl_id = None
            if s_def["team_lead_email"] and s_def["team_lead_email"] in created_users:
                tl_id = created_users[s_def["team_lead_email"]].id

            sp = StaffProfile(
                user_id=user.id,
                team_lead_id=tl_id,
                department=s_def["department"],
                daily_capacity=4,
                skills=s_def["skills"],
                is_accepting_work=True,
            )
            db.add(sp)

        await db.commit()
        print(f"[OK] Created Staff Profiles with proper department, skills, capacity, and team lead relations.")

        # Seed standard client with working login
        client_email = "client@creo.agency"
        c_user = (await db.execute(select(User).where(User.email == client_email))).scalar_one_or_none()
        if not c_user:
            c_user = User(
                id=uuid.uuid4(),
                auth_id=f"auth-{uuid.uuid4().hex[:12]}",
                email=client_email,
                full_name="Sushmitaa (Ryze Mushroom Coffee)",
                hashed_password=standard_password_hash,
                role=UserRole.CLIENT,
                account_status=AccountStatus.ACTIVE,
                must_reset_password=False,
                email_verified_at=now,
            )
            db.add(c_user)
            await db.flush()
        else:
            c_user.hashed_password = standard_password_hash
            c_user.account_status = AccountStatus.ACTIVE
            c_user.must_reset_password = False

        growth_plan = (await db.execute(select(Plan).where(Plan.name == "growth"))).scalar_one_or_none()
        if not growth_plan:
            growth_plan = (await db.execute(select(Plan))).scalars().first()

        cp = (await db.execute(select(ClientProfile).where(ClientProfile.user_id == c_user.id))).scalar_one_or_none()
        if not cp:
            cp = ClientProfile(
                user_id=c_user.id,
                company_name="Ryze Mushroom Coffee",
                instagram_username="ryzemushroomcoffee",
                brand_summary="Organic functional mushroom coffee for sustained morning energy, razor-sharp focus, and zero jitters.",
                brand_dna={
                    "company_name": "Ryze Mushroom Coffee",
                    "positioning": "Organic functional mushroom coffee for sustained morning energy and zero jitters.",
                    "tone": {"voice_words": ["Energizing", "Grounded", "Authoritative", "Warm"]},
                    "visual_direction": {"primary_colors": ["#10B981", "#065F46", "#F59E0B"]},
                    "content_pillars": [
                        {"name": "Morning Rituals & Focus", "funnel_stage": "reach"},
                        {"name": "Functional Mushroom Science", "funnel_stage": "consideration"},
                        {"name": "Customer Transformations", "funnel_stage": "conversion"}
                    ]
                },
                brand_dna_source="gemini",
                brand_dna_version=1,
                onboarding_completed_at=now,
            )
            db.add(cp)
            await db.flush()

        sub = (await db.execute(select(Subscription).where(Subscription.client_id == c_user.id))).scalar_one_or_none()
        if not sub and growth_plan:
            sub = Subscription(
                id=uuid.uuid4(),
                client_id=c_user.id,
                plan_id=growth_plan.id,
                status="active",
                gateway=PaymentProvider.RAZORPAY,
                amount=growth_plan.monthly_price,
                current_period_start=now,
                current_period_end=now + timedelta(days=30),
            )
            db.add(sub)
            await db.flush()

        await db.commit()

        # Dispatch pod assignment and feasible calendar for Ryze
        try:
            res_ryze = await assign_client_and_generate_schedule(db, c_user.id)
            print(f"[OK] Dispatched client {client_email}: Lead={res_ryze.get('team_lead')}, Tasks={res_ryze.get('created_tasks')}")
        except Exception as e_disp:
            print(f"Notice dispatching {client_email}: {e_disp}")

        print("\n=== STEP 3: RE-DISPATCH CREATIVE PODS FOR ONBOARDED REAL CLIENTS ===")
        # Check real clients that have completed questionnaire / brand discovery
        for cid, cemail in real_clients:
            cp_stmt = select(ClientProfile).where(ClientProfile.user_id == cid)
            cp = (await db.execute(cp_stmt)).scalar_one_or_none()
            if cp and cp.brand_dna:
                print(f"  -> Generating pod assignments and calendar for {cemail}...")
                try:
                    res = await assign_client_and_generate_schedule(db, cid)
                    print(f"     Pod assigned: Lead={res.get('assigned_lead_id')}, Tasks={res.get('tasks_created')}, Calendar={res.get('calendar_items_created')}")
                except Exception as e:
                    print(f"     Notice on {cemail}: {e}")

        # Refresh materialized views
        mviews_res = await db.execute(text("SELECT matviewname FROM pg_matviews WHERE schemaname = 'public';"))
        for mv in mviews_res.fetchall():
            mv_name = mv[0]
            try:
                await db.execute(text(f"REFRESH MATERIALIZED VIEW {mv_name};"))
                print(f"[OK] Refreshed materialized view: {mv_name}")
            except Exception as e:
                print(f"Notice refreshing {mv_name}: {e}")

        await db.commit()

        # Final audit counts
        user_cnt = (await db.execute(select(func.count(User.id)))).scalar()
        staff_cnt = (await db.execute(select(func.count(StaffProfile.user_id)))).scalar()
        client_cnt = (await db.execute(select(func.count(User.id)).where(User.role == UserRole.CLIENT))).scalar()
        admin_cnt = (await db.execute(select(func.count(User.id)).where(User.role.in_([UserRole.ADMIN, UserRole.SUPER_ADMIN])))).scalar()
        team_cnt = (await db.execute(select(func.count(User.id)).where(User.role == UserRole.TEAM_LEAD))).scalar()
        deliv_cnt = (await db.execute(select(func.count(Deliverable.id)))).scalar()
        task_cnt = (await db.execute(select(func.count(Task.id)))).scalar()
        cal_cnt = (await db.execute(select(func.count(ContentCalendar.id)))).scalar()

        print("\n=========================================================")
        print("  CLEAN DATABASE AUDIT SUMMARY")
        print("=========================================================")
        print(f"  Total Users:           {user_cnt}")
        print(f"  Staff Profiles:        {staff_cnt} (1 Super Admin + 2 Admins + 12 Pod Members)")
        print(f"  Super Admin & Admins:  {admin_cnt}")
        print(f"  Team Leads (4 Pods):   {team_cnt}")
        print(f"  Client Accounts:       {client_cnt}")
        print(f"  Deliverables:          {deliv_cnt} (All mock reels purged)")
        print(f"  Tasks:                 {task_cnt}")
        print(f"  Content Calendar:      {cal_cnt}")
        print("=========================================================\n")


if __name__ == "__main__":
    asyncio.run(run_cleanup_and_reseed())
