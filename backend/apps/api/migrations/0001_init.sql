CREATE TABLE users (
  id TEXT PRIMARY KEY,
  firebase_uid TEXT,
  display_name TEXT NOT NULL,
  short_tag TEXT NOT NULL,
  color TEXT NOT NULL,
  created_at TEXT NOT NULL,
  deleted_at TEXT,
  CHECK (deleted_at IS NOT NULL OR firebase_uid IS NOT NULL)
);

CREATE UNIQUE INDEX idx_users_firebase_uid ON users (firebase_uid);

CREATE TABLE apartments (
  id TEXT PRIMARY KEY,
  owner_id TEXT NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  street TEXT NOT NULL,
  city TEXT NOT NULL,
  invite_code TEXT NOT NULL,
  invite_code_rotated_at TEXT,
  cloud_media_count INTEGER NOT NULL DEFAULT 0 CHECK (cloud_media_count >= 0),
  orphan_delete_after TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE UNIQUE INDEX idx_apartments_invite_code ON apartments (invite_code);

CREATE TABLE apartment_changes (
  id TEXT PRIMARY KEY,
  apartment_id TEXT NOT NULL REFERENCES apartments (id) ON DELETE RESTRICT,
  author_id TEXT NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  field TEXT NOT NULL,
  old_value TEXT NOT NULL,
  new_value TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX idx_apartment_changes_apartment_created ON apartment_changes (
  apartment_id,
  created_at ASC
);

CREATE TABLE memberships (
  apartment_id TEXT NOT NULL REFERENCES apartments (id) ON DELETE RESTRICT,
  user_id TEXT NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  role TEXT NOT NULL CHECK (role IN ('owner', 'contributor')),
  joined_at TEXT NOT NULL,
  left_at TEXT,
  PRIMARY KEY (apartment_id, user_id)
);

CREATE INDEX idx_memberships_user_left ON memberships (user_id, left_at);

CREATE TABLE media (
  id TEXT PRIMARY KEY,
  apartment_id TEXT NOT NULL REFERENCES apartments (id) ON DELETE RESTRICT,
  author_id TEXT NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  kind TEXT NOT NULL CHECK (kind IN ('photo', 'video')),
  source TEXT NOT NULL CHECK (source IN ('camera', 'import')),
  upload_status TEXT NOT NULL CHECK (upload_status IN ('pending', 'confirmed')),
  sha256 TEXT NOT NULL,
  captured_at TEXT NOT NULL,
  captured_tz TEXT NOT NULL,
  captured_at_from_import INTEGER NOT NULL DEFAULT 0 CHECK (captured_at_from_import IN (0, 1)),
  server_received_at TEXT,
  lat REAL,
  lng REAL,
  accuracy_m REAL,
  location_source TEXT,
  width INTEGER NOT NULL CHECK (width > 0),
  height INTEGER NOT NULL CHECK (height > 0),
  bytes INTEGER NOT NULL CHECK (bytes > 0),
  r2_key TEXT NOT NULL UNIQUE,
  deleted_at TEXT,
  deleted_by TEXT REFERENCES users (id) ON DELETE RESTRICT
);

CREATE INDEX idx_media_apartment_captured ON media (apartment_id, captured_at DESC);

CREATE TABLE entries (
  id TEXT PRIMARY KEY,
  media_id TEXT NOT NULL REFERENCES media (id) ON DELETE RESTRICT,
  author_id TEXT NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
  text TEXT NOT NULL,
  created_at TEXT NOT NULL,
  server_received_at TEXT NOT NULL,
  retracted_at TEXT
);

CREATE INDEX idx_entries_media_created ON entries (media_id, created_at ASC);

CREATE TABLE markers (
  id TEXT PRIMARY KEY,
  entry_id TEXT NOT NULL REFERENCES entries (id) ON DELETE RESTRICT,
  media_id TEXT NOT NULL REFERENCES media (id) ON DELETE RESTRICT,
  number INTEGER NOT NULL CHECK (number > 0),
  x REAL NOT NULL CHECK (x >= 0.0 AND x <= 1.0),
  y REAL NOT NULL CHECK (y >= 0.0 AND y <= 1.0),
  UNIQUE (media_id, number)
);

CREATE INDEX idx_markers_entry_id ON markers (entry_id);

CREATE TABLE change_log (
  seq INTEGER PRIMARY KEY AUTOINCREMENT,
  apartment_id TEXT NOT NULL REFERENCES apartments (id) ON DELETE RESTRICT,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  op TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX idx_change_log_apartment_seq ON change_log (apartment_id, seq ASC);
