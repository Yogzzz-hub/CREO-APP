"""Bring migrations level with the models.

These columns and tables were only ever created by raw SQL in app/main.py at startup (or by
database/schema.sql), so a database built from migrations alone was missing them and every
insert into deliverables failed. Each step is idempotent: on a database that already has them
(production, where startup created them) this migration changes nothing.
"""
from alembic import op

import app.models  # noqa: F401  registers every model on Base.metadata
from app.db.base import Base

revision = "0027_schema_catch_up"
down_revision = "0026_revenue_crm"
branch_labels = None
depends_on = None

COLUMNS = [
    ("deliverables", "voice_note_url", "text"),
    ("deliverables", "voice_note_duration", "integer"),
    ("direct_messages", "attachment_url", "text"),
    ("direct_messages", "attachment_name", "varchar(255)"),
    ("direct_messages", "attachment_type", "varchar(100)"),
    ("direct_messages", "attachment_size", "bigint"),
]

# Created from the model definitions, so they match what the code reads and writes.
TABLES = ["escalation_states", "platform_settings", "sample_requests", "bde_proposals", "bde_targets"]


def upgrade():
    for table, column, sql_type in COLUMNS:
        op.execute(f"ALTER TABLE {table} ADD COLUMN IF NOT EXISTS {column} {sql_type}")
    bind = op.get_bind()
    for name in TABLES:
        Base.metadata.tables[name].create(bind=bind, checkfirst=True)


def downgrade():
    # Not reversible safely: production may hold data in these columns and tables.
    pass
