import asyncio
from app.db.session import async_session_factory
from sqlalchemy import text

async def reset_onboarding():
    async with async_session_factory() as db:
        print("Resetting all client onboarding stages to 1...")
        await db.execute(text("UPDATE subscriptions SET status = 'canceled';"))
        await db.execute(text("UPDATE client_profiles SET terms_accepted_at = NULL, onboarding_completed_at = NULL;"))
        await db.commit()
        print("Done! All clients are now back to Onboarding Step 2 (Terms). Wait, if terms_accepted is NULL, they are at Stage 1, which means they need to sign terms.")

if __name__ == "__main__":
    asyncio.run(reset_onboarding())
