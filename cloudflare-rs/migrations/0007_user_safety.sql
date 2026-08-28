CREATE TABLE user_blocks (
  blocker_uid TEXT NOT NULL,
  blocked_uid TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (blocker_uid, blocked_uid),
  CHECK (blocker_uid <> blocked_uid),
  FOREIGN KEY (blocker_uid) REFERENCES users(uid) ON DELETE CASCADE,
  FOREIGN KEY (blocked_uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE INDEX user_blocks_blocked_idx
  ON user_blocks(blocked_uid, blocker_uid);

CREATE TABLE user_reports (
  report_id TEXT PRIMARY KEY,
  reporter_uid TEXT NOT NULL,
  reported_uid TEXT NOT NULL,
  reason TEXT NOT NULL CHECK (
    reason IN ('safety_concern', 'harassment', 'spam', 'inappropriate_profile', 'other')
  ),
  status TEXT NOT NULL DEFAULT 'open' CHECK (
    status IN ('open', 'reviewing', 'resolved', 'dismissed')
  ),
  created_at TEXT NOT NULL,
  FOREIGN KEY (reporter_uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE INDEX user_reports_status_created_idx
  ON user_reports(status, created_at DESC);

CREATE INDEX user_reports_reported_idx
  ON user_reports(reported_uid, created_at DESC);
