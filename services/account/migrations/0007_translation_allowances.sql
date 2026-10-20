ALTER TABLE users ADD COLUMN translation_daily_limit INTEGER NOT NULL DEFAULT 10 CHECK (typeof(translation_daily_limit) = 'integer' AND translation_daily_limit >= 0);

DROP TRIGGER translation_admit;
DROP TRIGGER translation_charge;

CREATE TABLE translation_daily_usage_new (
  scope TEXT NOT NULL CHECK (scope IN ('account', 'ip')),
  subject TEXT NOT NULL,
  day INTEGER NOT NULL,
  used INTEGER NOT NULL CHECK (used >= 0),
  PRIMARY KEY (scope, subject, day)
);
INSERT INTO translation_daily_usage_new SELECT scope, subject, day, used FROM translation_daily_usage;
DROP TABLE translation_daily_usage;
ALTER TABLE translation_daily_usage_new RENAME TO translation_daily_usage;

-- Keep admission and charging atomic. Elevated accounts use only their account quota.
-- Keep trigger bodies on one line for D1's remote statement parser.
CREATE TRIGGER translation_admit BEFORE INSERT ON lyric_translations WHEN COALESCE((SELECT used FROM translation_daily_usage WHERE scope = 'account' AND subject = NEW.account_id AND day = NEW.day), 0) >= COALESCE((SELECT translation_daily_limit FROM users WHERE id = NEW.account_id), 10) OR (COALESCE((SELECT translation_daily_limit FROM users WHERE id = NEW.account_id), 10) <= 10 AND COALESCE((SELECT used FROM translation_daily_usage WHERE scope = 'ip' AND subject = NEW.ip_hash AND day = NEW.day), 0) >= 10) BEGIN SELECT RAISE(ABORT, 'translation_daily_limit'); END;
CREATE TRIGGER translation_charge AFTER INSERT ON lyric_translations BEGIN INSERT INTO translation_daily_usage (scope, subject, day, used) VALUES ('account', NEW.account_id, NEW.day, 1) ON CONFLICT (scope, subject, day) DO UPDATE SET used = used + 1; INSERT INTO translation_daily_usage (scope, subject, day, used) SELECT 'ip', NEW.ip_hash, NEW.day, 1 WHERE COALESCE((SELECT translation_daily_limit FROM users WHERE id = NEW.account_id), 10) <= 10 ON CONFLICT (scope, subject, day) DO UPDATE SET used = used + 1; END;
