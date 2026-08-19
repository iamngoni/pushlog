-- Username ownership is authoritative in username_claims. Profiles may contain
-- stale duplicate display data during backfill and must not block migration.
DROP INDEX IF EXISTS users_username_lower_unique;
