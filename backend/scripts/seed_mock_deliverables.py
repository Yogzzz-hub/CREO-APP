import asyncio
import uuid
from datetime import datetime, UTC, timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from sqlalchemy.orm import sessionmaker

from app.config import settings
from app.models.user import User
from app.models.work import Deliverable, DeliverableType, DeliverableStatus

async def main():
    print("Connecting to DB to seed mock deliverables...")
    engine = create_async_engine(settings.DIRECT_DATABASE_URL, echo=False, future=True)
    async_session = sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)
    
    now = datetime.now(UTC)
    email = "newbusiness@creo.com"
    
    async with async_session() as db:
        # Get client
        stmt = select(User).where(User.email == email)
        res = await db.execute(stmt)
        client = res.scalars().first()
        
        if not client:
            print("Client not found!")
            return
            
        # Get an editor (for assigning)
        stmt = select(User).where(User.email == "editor@creo.agency")
        res = await db.execute(stmt)
        editor = res.scalars().first()
        editor_id = editor.id if editor else None

        # Create Deliverables
        deliverables = [
            Deliverable(
                id=uuid.uuid4(),
                root_id=uuid.uuid4(),
                version=1,
                client_id=client.id,
                submitted_by=editor_id,
                file_url="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4",
                file_type=DeliverableType.REEL.value if hasattr(DeliverableType.REEL, "value") else str(DeliverableType.REEL),
                file_size_bytes=10485760,
                status=DeliverableStatus.PENDING_APPROVAL,
                revision_round=1,
                created_at=now - timedelta(hours=2)
            ),
            Deliverable(
                id=uuid.uuid4(),
                root_id=uuid.uuid4(),
                version=2,
                client_id=client.id,
                submitted_by=editor_id,
                file_url="https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4",
                file_type=DeliverableType.REEL.value if hasattr(DeliverableType.REEL, "value") else str(DeliverableType.REEL),
                file_size_bytes=15000000,
                status=DeliverableStatus.PENDING_APPROVAL,
                revision_round=2,
                created_at=now - timedelta(hours=1)
            ),
            Deliverable(
                id=uuid.uuid4(),
                root_id=uuid.uuid4(),
                version=1,
                client_id=client.id,
                submitted_by=editor_id,
                file_url="https://images.unsplash.com/photo-1549931319-a545dcf3bc73?auto=format&fit=crop&q=80&w=800",
                file_type=DeliverableType.STATIC_POST.value if hasattr(DeliverableType.STATIC_POST, "value") else str(DeliverableType.STATIC_POST),
                file_size_bytes=2048000,
                status=DeliverableStatus.APPROVED,
                revision_round=1,
                approved_at=now - timedelta(days=1),
                created_at=now - timedelta(days=2)
            ),
        ]
        
        db.add_all(deliverables)
        await db.commit()
        print("Mock deliverables successfully added for", email)

if __name__ == "__main__":
    asyncio.run(main())
