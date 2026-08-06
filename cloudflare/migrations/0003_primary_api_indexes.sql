CREATE INDEX IF NOT EXISTS users_username_search_idx
  ON users(username_lower, uid);

CREATE INDEX IF NOT EXISTS friend_requests_sender_idx
  ON friend_requests(sender_uid, status, created_at DESC);

CREATE INDEX IF NOT EXISTS devices_uid_updated_idx
  ON devices(uid, updated_at DESC);
