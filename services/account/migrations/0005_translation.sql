CREATE TABLE translation_daily_usage (
  scope TEXT NOT NULL CHECK (scope IN ('account', 'ip')),
  subject TEXT NOT NULL,
  day INTEGER NOT NULL,
  used INTEGER NOT NULL CHECK (used BETWEEN 0 AND 10),
  PRIMARY KEY (scope, subject, day)
);

CREATE TABLE lyric_translations (
  song_id TEXT NOT NULL,
  revision TEXT NOT NULL,
  lyrics_hash TEXT NOT NULL,
  translations TEXT,
  lease_token TEXT NOT NULL,
  expires_at INTEGER NOT NULL,
  account_id TEXT,
  ip_hash TEXT,
  day INTEGER NOT NULL,
  PRIMARY KEY (song_id, revision, lyrics_hash)
);
CREATE INDEX lyric_translations_expiry ON lyric_translations(expires_at);

-- Keep trigger bodies on one line for D1's remote statement parser.
-- Admission and both counters run in the same SQLite transaction.
CREATE TRIGGER translation_admit BEFORE INSERT ON lyric_translations WHEN COALESCE((SELECT used FROM translation_daily_usage WHERE scope = 'account' AND subject = NEW.account_id AND day = NEW.day), 0) >= 10 OR COALESCE((SELECT used FROM translation_daily_usage WHERE scope = 'ip' AND subject = NEW.ip_hash AND day = NEW.day), 0) >= 10 BEGIN SELECT RAISE(ABORT, 'translation_daily_limit'); END;
CREATE TRIGGER translation_charge AFTER INSERT ON lyric_translations BEGIN INSERT INTO translation_daily_usage (scope, subject, day, used) VALUES ('account', NEW.account_id, NEW.day, 1) ON CONFLICT (scope, subject, day) DO UPDATE SET used = used + 1; INSERT INTO translation_daily_usage (scope, subject, day, used) VALUES ('ip', NEW.ip_hash, NEW.day, 1) ON CONFLICT (scope, subject, day) DO UPDATE SET used = used + 1; END;
