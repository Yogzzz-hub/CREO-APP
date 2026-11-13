"""Give existing chat messages an agency, so staff rooms can be separated per agency.

Messages written before this change have no agency_id. They take the agency of the person who
sent them. Messages whose sender has no agency stay unassigned and are then visible only to
platform super admins in staff rooms.
"""
from alembic import op

revision = "0028_chat_message_agency"
down_revision = "0027_schema_catch_up"
branch_labels = None
depends_on = None


def upgrade():
    op.execute(
        """
        UPDATE direct_messages AS dm
           SET agency_id = u.agency_id
          FROM users AS u
         WHERE dm.sender_id = u.id
           AND dm.agency_id IS NULL
           AND u.agency_id IS NOT NULL
        """
    )


def downgrade():
    # Backfilled values cannot be told apart from ones written by the app.
    pass
