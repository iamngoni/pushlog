CREATE TABLE weight_entries (
  uid TEXT NOT NULL,
  recorded_on TEXT NOT NULL,
  weight_grams INTEGER NOT NULL CHECK (weight_grams > 0 AND weight_grams < 500000),
  updated_at TEXT NOT NULL,
  PRIMARY KEY (uid, recorded_on),
  FOREIGN KEY (uid) REFERENCES users(uid) ON DELETE CASCADE
);

CREATE INDEX weight_entries_uid_day_idx
  ON weight_entries(uid, recorded_on);

CREATE TABLE weight_settings (
  uid TEXT PRIMARY KEY,
  unit TEXT NOT NULL DEFAULT 'kg' CHECK (unit IN ('kg', 'lb')),
  goal TEXT NOT NULL DEFAULT 'maintain' CHECK (goal IN ('lose', 'maintain', 'gain')),
  share_progress INTEGER NOT NULL DEFAULT 0 CHECK (share_progress IN (0, 1)),
  share_latest_weight INTEGER NOT NULL DEFAULT 0 CHECK (share_latest_weight IN (0, 1)),
  updated_at TEXT NOT NULL,
  FOREIGN KEY (uid) REFERENCES users(uid) ON DELETE CASCADE
);
