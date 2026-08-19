PRAGMA foreign_keys = ON;

CREATE TABLE users (
  uid TEXT PRIMARY KEY,
  email TEXT,
  display_name TEXT,
  photo_url TEXT,
  username TEXT,
  username_lower TEXT,
  private_json TEXT NOT NULL DEFAULT '{}',
  public_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT,
  updated_at TEXT NOT NULL,
  migrated_at TEXT
);

CREATE TABLE username_claims (
  username_lower TEXT PRIMARY KEY,
  uid TEXT NOT NULL,
  username TEXT,
  source_json TEXT NOT NULL DEFAULT '{}',
  updated_at TEXT NOT NULL,
  FOREIGN KEY (uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE INDEX username_claims_uid_idx ON username_claims(uid);

CREATE TABLE workout_snapshots (
  uid TEXT PRIMARY KEY,
  sync_id TEXT NOT NULL,
  snapshot_json TEXT NOT NULL,
  content_hash TEXT NOT NULL,
  source_updated_at TEXT,
  last_synced_at TEXT,
  schema_version INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL,
  migrated_at TEXT,
  FOREIGN KEY (uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE TABLE workout_sessions (
  uid TEXT NOT NULL,
  sync_id TEXT NOT NULL,
  session_id TEXT NOT NULL,
  occurred_at TEXT NOT NULL,
  reps INTEGER NOT NULL CHECK (reps >= 0),
  source TEXT NOT NULL,
  duration_us INTEGER,
  average_rep_duration_us INTEGER,
  manual_adjustments INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (uid, sync_id, session_id),
  FOREIGN KEY (uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE INDEX workout_sessions_active_idx
  ON workout_sessions(uid, sync_id, occurred_at DESC);

CREATE TABLE daily_scores (
  uid TEXT NOT NULL,
  sync_id TEXT NOT NULL,
  day_key TEXT NOT NULL,
  reps INTEGER NOT NULL CHECK (reps >= 0),
  PRIMARY KEY (uid, sync_id, day_key),
  FOREIGN KEY (uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE INDEX daily_scores_day_idx ON daily_scores(day_key, reps DESC);

CREATE TABLE friend_stats (
  uid TEXT PRIMARY KEY,
  today_count INTEGER NOT NULL DEFAULT 0,
  today_key TEXT,
  week_count INTEGER NOT NULL DEFAULT 0,
  week_key TEXT,
  best_day INTEGER NOT NULL DEFAULT 0,
  total_all_time INTEGER NOT NULL DEFAULT 0,
  streak INTEGER NOT NULL DEFAULT 0,
  source_json TEXT NOT NULL DEFAULT '{}',
  updated_at TEXT NOT NULL,
  migrated_at TEXT,
  FOREIGN KEY (uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE INDEX friend_stats_today_idx ON friend_stats(today_key, today_count DESC);
CREATE INDEX friend_stats_week_idx ON friend_stats(week_key, week_count DESC);
CREATE INDEX friend_stats_all_time_idx ON friend_stats(total_all_time DESC);

CREATE TABLE friend_links (
  owner_uid TEXT NOT NULL,
  friend_uid TEXT NOT NULL,
  added_at TEXT,
  source_json TEXT NOT NULL DEFAULT '{}',
  migrated_at TEXT,
  PRIMARY KEY (owner_uid, friend_uid),
  CHECK (owner_uid <> friend_uid),
  FOREIGN KEY (owner_uid) REFERENCES users(uid) ON DELETE CASCADE,
  FOREIGN KEY (friend_uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE INDEX friend_links_friend_idx ON friend_links(friend_uid, owner_uid);

CREATE TABLE friend_requests (
  sender_uid TEXT NOT NULL,
  receiver_uid TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
  incoming_json TEXT,
  outgoing_json TEXT,
  created_at TEXT,
  updated_at TEXT NOT NULL,
  migrated_at TEXT,
  PRIMARY KEY (sender_uid, receiver_uid),
  CHECK (sender_uid <> receiver_uid),
  FOREIGN KEY (sender_uid) REFERENCES users(uid) ON DELETE CASCADE,
  FOREIGN KEY (receiver_uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE INDEX friend_requests_receiver_idx
  ON friend_requests(receiver_uid, status, created_at DESC);

CREATE TABLE devices (
  uid TEXT NOT NULL,
  token TEXT NOT NULL,
  platform TEXT,
  updated_at TEXT NOT NULL,
  migrated_at TEXT,
  PRIMARY KEY (uid, token),
  FOREIGN KEY (uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE TABLE notification_events (
  uid TEXT NOT NULL,
  notification_id TEXT NOT NULL,
  type TEXT NOT NULL,
  title TEXT,
  body TEXT,
  actor_uid TEXT,
  competitor_uid TEXT,
  day_key TEXT,
  delivery_status TEXT,
  payload_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT,
  read_at TEXT,
  delivered_at TEXT,
  migrated_at TEXT,
  PRIMARY KEY (uid, notification_id),
  FOREIGN KEY (uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE INDEX notification_events_uid_created_idx
  ON notification_events(uid, created_at DESC);

CREATE TABLE migration_runs (
  run_id TEXT PRIMARY KEY,
  source TEXT NOT NULL,
  mode TEXT NOT NULL,
  started_at TEXT NOT NULL,
  completed_at TEXT,
  source_document_count INTEGER,
  imported_document_count INTEGER,
  summary_json TEXT NOT NULL DEFAULT '{}'
);

CREATE TABLE migration_ledger (
  source_path TEXT PRIMARY KEY,
  source_checksum TEXT NOT NULL,
  run_id TEXT NOT NULL,
  imported_at TEXT NOT NULL,
  FOREIGN KEY (run_id) REFERENCES migration_runs(run_id) ON DELETE CASCADE
);

CREATE INDEX migration_ledger_run_idx ON migration_ledger(run_id);
