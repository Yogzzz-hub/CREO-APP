
import asyncio
from sqlalchemy import text
from app.db.session import engine

async def main():
    async with engine.begin() as conn:
        await conn.execute(text('ALTER TABLE direct_messages ALTER COLUMN client_id DROP NOT NULL'))
        await conn.execute(text('ALTER TABLE direct_messages ALTER COLUMN specialist_id DROP NOT NULL'))

asyncio.run(main())

