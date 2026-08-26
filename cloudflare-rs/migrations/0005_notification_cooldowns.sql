CREATE TABLE notification_cooldowns (
  uid TEXT NOT NULL,
  type TEXT NOT NULL,
  actor_uid TEXT NOT NULL,
  cooldown_until TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (uid, type, actor_uid),
  FOREIGN KEY (uid) REFERENCES users(uid) ON DELETE CASCADE,
  FOREIGN KEY (actor_uid) REFERENCES users(uid) ON DELETE CASCADE
);
