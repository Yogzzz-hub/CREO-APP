import asyncio
import uuid
from datetime import datetime, UTC, date, timedelta
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.config import settings
from app.core.security import hash_password
from app.models.user import User, ClientProfile
from app.models.enums import (
    AccountStatus,
    UserRole,
    SubscriptionStatus,
    PaymentProvider,
    DeliverableType,
)

from app.models.billing import Plan, Subscription, UsageCounter

async def main():
    print("Connecting to DB...")
    engine = create_async_engine(
        settings.DIRECT_DATABASE_URL,
        echo=False,
        future=True,
    )
    async_session = sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)

    now = datetime.now(UTC)
    today = now.date()
    month_start = date(today.year, today.month, 1)
    if today.month == 12:
        month_end = date(today.year + 1, 1, 1) - timedelta(days=1)
    else:
        month_end = date(today.year, today.month + 1, 1) - timedelta(days=1)

    email = "newbusiness@creo.com"
    name = "New Business Corp"
    
    async with async_session() as db:
        # 1. Fetch starter plan
        stmt = select(Plan).where(Plan.name == "starter")
        res = await db.execute(stmt)
        plan_obj = res.scalars().first()
        if not plan_obj:
            print("Starter plan not found!")
            return

        # 2. Check if user exists
        stmt = select(User).where(User.email == email)
        res = await db.execute(stmt)
        user = res.scalars().first()
        
        if not user:
            print(f"Creating user {email}...")
            user = User(
                email=email,
                auth_id=f"auth_{uuid.uuid4().hex[:8]}",
                full_name=name,
                role=UserRole.CLIENT,
                account_status=AccountStatus.ACTIVE,
                email_verified_at=now,
                hashed_password=hash_password("password123"),
            )
            db.add(user)
            await db.flush()

            # Client profile (Brand DNA completed)
            cp = ClientProfile(
                user_id=user.id,
                company_name=name,
                instagram_username="@newbusiness",
                terms_accepted_at=now,
                terms_version="v1.0",
                onboarding_completed_at=now,
                brand_summary="A fresh, innovative startup looking to disrupt the market.",
                brand_dna={
                    "tone": "Professional, Modern, Friendly",
                    "palette": ["#101828", "#3B82F6", "#FFFFFF"],
                    "target_audience": "Modern businesses and young professionals",
                }
            )
            db.add(cp)
            await db.flush()

            # Subscription
            sub = Subscription(
                client_id=user.id,
                plan_id=plan_obj.id,
                status=SubscriptionStatus.ACTIVE,
                gateway=PaymentProvider.RAZORPAY,
                gateway_subscription_id=f"sub_test_{user.id.hex[:8]}",
                amount=plan_obj.monthly_price,
                current_period_start=now - timedelta(days=2),
                current_period_end=now + timedelta(days=28),
            )
            db.add(sub)
            await db.flush()

            # Usage counters
            counters = [
                UsageCounter(
                    client_id=user.id,
                    period_start=month_start,
                    period_end=month_end,
                    kind=DeliverableType.REEL,
                    quota=plan_obj.reel_quota,
                    used=0,
                ),
                UsageCounter(
                    client_id=user.id,
                    period_start=month_start,
                    period_end=month_end,
                    kind=DeliverableType.STATIC_POST,
                    quota=plan_obj.poster_quota,
                    used=0,
                ),
                UsageCounter(
                    client_id=user.id,
                    period_start=month_start,
                    period_end=month_end,
                    kind=DeliverableType.STORY,
                    quota=plan_obj.story_quota,
                    used=0,
                ),
            ]
            db.add_all(counters)
            await db.commit()
            print("Successfully created fully onboarded client with 25k Starter plan!")
            print(f"Login Email: {email}")
            print(f"Password: password123")
        else:
            print("User already exists!")

if __name__ == "__main__":
    asyncio.run(main())
