ALTER TABLE users ADD COLUMN time_zone TEXT NOT NULL DEFAULT 'UTC';
ALTER TABLE users ADD COLUMN last_active_at TEXT;

UPDATE users SET last_active_at = updated_at WHERE last_active_at IS NULL;

CREATE UNIQUE INDEX notification_events_engagement_source_idx
  ON notification_events(uid, type, source_sync_id)
  WHERE type = 'engagement_reminder' AND source_sync_id IS NOT NULL;
