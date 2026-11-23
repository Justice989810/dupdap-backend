# Database

This document describes the database schema, materialized views, and refresh scheduling used by the analytics layer.

## Tables

- `payments` — raw payment records (one row per charge).
- `merchants` — merchant accounts.
- `refunds` — refund records linked to payments.

## Materialized views

### `daily_payment_volume`

Aggregates payment volume per merchant per day. Daily analytics queries read from this view instead of scanning `payments` directly.

```sql
CREATE MATERIALIZED VIEW daily_payment_volume AS
SELECT
    merchant_id,
    date_trunc('day', created_at) AS day,
    COUNT(*)                     AS payment_count,
    SUM(amount)                  AS total_amount
FROM payments
GROUP BY merchant_id, date_trunc('day', created_at);

CREATE UNIQUE INDEX daily_payment_volume_pkey
    ON daily_payment_volume (merchant_id, day);
```

### `monthly_payment_volume`

Aggregates payment volume per merchant per month. Monthly analytics queries read from this view instead of scanning `payments` directly, which is prohibitively slow for high-volume merchants.

```sql
CREATE MATERIALIZED VIEW monthly_payment_volume AS
SELECT
    merchant_id,
    date_trunc('month', created_at) AS month,
    COUNT(*)                        AS payment_count,
    SUM(amount)                     AS total_amount
FROM payments
GROUP BY merchant_id, date_trunc('month', created_at);

CREATE UNIQUE INDEX monthly_payment_volume_pkey
    ON monthly_payment_volume (merchant_id, month);
```

## Refresh scheduling

Both materialized views are refreshed daily. The refresh runs after the daily aggregation job and uses `REFRESH MATERIALIZED VIEW CONCURRENTLY` (enabled by the unique indexes above) so reads are not blocked during refresh.

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY daily_payment_volume;
REFRESH MATERIALIZED VIEW CONCURRENTLY monthly_payment_volume;
```

Schedule these statements in the same daily job that refreshes `daily_payment_volume`.
