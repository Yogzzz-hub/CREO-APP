# CREO-APP (Backend & Database)

High-performance asynchronous backend services and PostgreSQL database architecture powering the Creo Content Production & Pod Operations platform.

## Architecture & Structure

- **`backend/`**: FastAPI service built with asynchronous Python, SQLAlchemy 2.0, Pydantic v2 schemas, and Alembic database migrations.
  - `backend/app/routers/`: REST endpoints for deliverables, workstation, admin pod orchestration, client portal, calendar, and analytics.
  - `backend/app/services/`: Core business logic engines (dispatch, deliverable workflows, storage fallback, notifications).
  - `backend/app/models/`: SQLAlchemy declarative domain models.
  - `backend/alembic/`: Database versioning and incremental migration scripts.
- **`database/`**: Production SQL initialization scripts, seed data, and schema definitions.
  - `database/schema.sql`: Core relational schemas and table definitions.
  - `database/seed_data.sql`: Seed data for pods, users, deliverables, and client contracts.
  - `database/clean_and_seed_brands.py`: Brand assets and seed orchestration.

## Getting Started

### Prerequisites
- Python 3.11+
- PostgreSQL 15+
- Docker & Docker Compose (optional)

### Local Setup

1. **Configure Environment**:
   ```bash
   cd backend
   cp .env.example .env
   ```

2. **Install Dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

3. **Run Migrations & Seed**:
   ```bash
   alembic upgrade head
   python scripts/seed.py
   ```

4. **Start Development Server**:
   ```bash
   uvicorn app.main:app --reload --port 8000
   ```

### Docker Compose
Run the backend and database stack:
```bash
docker-compose up --build
```
