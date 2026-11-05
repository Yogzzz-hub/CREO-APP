import asyncio
import os
from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy import text
from dotenv import load_dotenv

load_dotenv()
DB_URL = os.getenv("DATABASE_URL")

async def main():
    engine = create_async_engine(DB_URL)
    async with engine.begin() as conn:
        try:
            await conn.execute(text("ALTER TYPE ticket_status ADD VALUE IF NOT EXISTS 'closed';"))
            print('Added closed to enum')
        except Exception as e:
            print(e)
        try:
            await conn.execute(text("ALTER TABLE tickets ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMP WITH TIME ZONE;"))
            await conn.execute(text("ALTER TABLE tickets ADD COLUMN IF NOT EXISTS closed_at TIMESTAMP WITH TIME ZONE;"))
            print('Added columns')
        except Exception as e:
            print(e)

if __name__ == "__main__":
    asyncio.run(main())
