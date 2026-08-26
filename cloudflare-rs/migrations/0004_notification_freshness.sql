ALTER TABLE notification_events ADD COLUMN source_sync_id TEXT;

CREATE UNIQUE INDEX notification_events_lead_change_source_idx
  ON notification_events(uid, type, actor_uid, day_key, source_sync_id)
  WHERE type = 'lead_change' AND source_sync_id IS NOT NULL;
