import asyncio
from app.db.session import AsyncSessionLocal
from app.models.work import Task, Deliverable
from app.models.user import User
from sqlalchemy import select

async def main():
    async with AsyncSessionLocal() as db:
        res_t = await db.execute(select(Task))
        tasks = res_t.scalars().all()
        print(f"Total tasks in DB: {len(tasks)}")
        for t in tasks[:10]:
            print("Task:", t.id, t.title, t.status, "Assigned:", t.assigned_to, "Client:", t.client_id)

        res_d = await db.execute(select(Deliverable))
        delivs = res_d.scalars().all()
        print(f"Total deliverables in DB: {len(delivs)}")
        for d in delivs[:10]:
            print("Deliverable:", d.id, d.title, d.status)

        res_u = await db.execute(select(User))
        users = res_u.scalars().all()
        print(f"Total users in DB: {len(users)}")
        for u in users[:10]:
            print("User:", u.id, u.email, u.role)

if __name__ == "__main__":
    asyncio.run(main())
