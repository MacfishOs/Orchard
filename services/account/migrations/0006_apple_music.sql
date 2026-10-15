-- Apple Music developer tokens issued per account per UTC day.
CREATE TABLE apple_token_daily_usage (
  user_id TEXT NOT NULL,
  day INTEGER NOT NULL,
  used INTEGER NOT NULL,
  PRIMARY KEY (user_id, day)
);
