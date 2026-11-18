#!/usr/bin/env bash
set -e
REPO="dupdab/dupdap-backend"

i() {
  gh issue create --repo "$REPO" --title "$1" --body "$2"
  sleep 0.3
}

echo "=== Creating 125 backend issues ==="

i "payments: batch create does not register each payment in the Soroban escrow contract" "Single \`create()\` calls \`soroban.createPayment()\` and persists \`expiryLedger\`. The batch path builds and saves records but never calls \`PaymentEscrowService.createPayment()\` for any item, so batch payments have no on-chain escrow entry.

**Acceptance criteria:**
- [ ] \`createBatch()\` calls \`soroban.createPayment()\` per item
- [ ] \`expiryLedger\` persisted on each saved record
- [ ] Failure of any escrow registration rolls back the entire batch transaction
- [ ] Unit tests for the escrow registration path"

i "payments: batch create skips QR code generation for each item" "Single \`create()\` generates a Stellar URI and QR code. \`createBatch()\` builds records without setting \`qrCode\`, leaving each batch payment with a null QR code that breaks the customer payment page.

**Acceptance criteria:**
- [ ] Generate Stellar URI and QR code per batch item
- [ ] Batch response includes \`qrCode\` per item
- [ ] Unit test asserts QR code is non-null on each batch result"

i "payments: findAll() missing pagination bounds — allows arbitrarily large limit" "\`findAll(merchantId, page, limit)\` has no upper bound on \`limit\`. A caller passing \`limit=100000\` causes a full table scan for the merchant.

**Acceptance criteria:**
- [ ] Cap \`limit\` at 100
- [ ] Validate \`page >= 1\` and \`limit >= 1\` with \`@Min\`/\`@Max\` on the DTO
- [ ] Return 400 on out-of-range values"

i "payments: confirmPayment() does not dispatch webhook after confirmation" "After setting \`payment.status = CONFIRMED\` and saving, \`confirmPayment()\` does not call \`webhooks.dispatch()\` with a \`payment.confirmed\` event. Merchants subscribed to this event never receive the notification.

**Acceptance criteria:**
- [ ] Call \`webhooks.dispatch(merchantId, 'payment.confirmed', { paymentId })\` after save
- [ ] Unit test asserts dispatch is called on successful confirmation"

i "payments: confirmPayment() does not send merchant notification email" "No call to \`NotificationsService\` on payment confirmation, so merchants never receive confirmation emails regardless of their notification preferences.

**Acceptance criteria:**
- [ ] Call \`notifications.notifyMerchant()\` on confirmation
- [ ] Respects merchant's \`paymentConfirmedEmailEnabled\` preference
- [ ] Unit test with notification service mocked"

i "payments: expired payments never transitioned — no cron job to sweep PENDING past expiresAt" "Payments have an \`expiresAt\` field but no scheduled job marks them \`EXPIRED\` when the time passes. PENDING payments accumulate indefinitely.

**Acceptance criteria:**
- [ ] Cron job every 5 min: UPDATE payments SET status='expired' WHERE status='pending' AND expiresAt < NOW()
- [ ] \`payment.expired\` webhook dispatched per expired payment
- [ ] Admin alert if more than 100 payments expire in one sweep"

i "payments: refund() does not invoke Soroban contract refund" "\`refund()\` updates DB status to REFUNDED but never calls \`soroban.refund()\` to release funds from the on-chain escrow back to the customer.

**Acceptance criteria:**
- [ ] Call \`soroban.refund(paymentId, customerWalletAddress)\` before updating status
- [ ] If Soroban call fails, do not update DB status
- [ ] Unit test asserts contract refund is invoked"

i "payments: memo collision — generateMemo() uses Math.random() with no uniqueness guarantee" "\`Math.random().toString(36).substring(2,10)\` produces 8 base-36 characters. Under load two concurrent payments can receive the same memo, making Horizon matching ambiguous.

**Acceptance criteria:**
- [ ] Use \`crypto.randomBytes(8).toString('hex')\` for 64-bit entropy
- [ ] Add unique index on \`payments.stellarMemo\`
- [ ] Handle unique-constraint violation at creation with a retry"

i "payments: findByReference() is unscoped — authenticated actors can resolve other merchants' payments" "This method is intentionally unscoped for the customer pay page, but if called from an authenticated merchant context it returns payments belonging to other merchants.

**Acceptance criteria:**
- [ ] Audit all callers of \`findByReference\`
- [ ] Caller from admin/merchant contexts must pass \`merchantId\` and scope the query
- [ ] Add test asserting cross-merchant lookup returns 404"

i "payments: no rate limit on payment creation per merchant API key" "A merchant API key can create payments at unlimited rate, enabling DoS via queue saturation and DB row explosion.

**Acceptance criteria:**
- [ ] 60 payment creations per minute per API key (configurable via RuntimeConfig)
- [ ] 429 response with \`Retry-After\` header on breach
- [ ] Counter stored in Redis with sliding window"

i "payments: getStats() returns raw decimal strings instead of typed numbers" "Raw query returns \`totalUsd\` as a PostgreSQL numeric string. Callers receive \`\"1234.000000\"\` instead of \`1234\`.

**Acceptance criteria:**
- [ ] Parse \`totalUsd\` to \`number\` before returning
- [ ] Add typed response DTO for stats
- [ ] Unit test for decimal parsing"

i "payments: batch endpoint silently ignores items beyond index 19 — no 400 error" "The contract says max 20 items but the DTO validation does not enforce this. Items 20+ are silently dropped.

**Acceptance criteria:**
- [ ] \`@ArrayMaxSize(20)\` on the \`payments\` field
- [ ] 400 response with clear message if array exceeds 20
- [ ] Test for 21-item batch returning 400"

i "payments: receipt endpoint missing — referenced in README but not implemented" "README and payment entity reference a receipt endpoint but no \`GET /payments/:id/receipt\` route exists in the active module.

**Acceptance criteria:**
- [ ] \`GET /payments/:id/receipt\` returns a PDF or HTML receipt
- [ ] Receipt includes: payment ID, amount, date, merchant name, status
- [ ] Swagger documented"

i "payments: amountUsd arithmetic uses Number() cast — IEEE-754 precision loss on large amounts" "Several code paths cast \`payment.amountUsd\` to \`Number()\` before arithmetic, risking floating-point precision loss on amounts with many decimal places.

**Acceptance criteria:**
- [ ] All arithmetic on \`amountUsd\` uses Big.js
- [ ] No \`Number(payment.amountUsd)\` or \`parseFloat\` in service layer
- [ ] Unit test with high-precision value (e.g. 999999.999999)"

i "payments: no index on payments.expiresAt — expiry sweep cron will sequential scan" "The planned expiry cron queries WHERE status='pending' AND expiresAt < NOW(). Without an index on \`expiresAt\` this is a full table scan.

**Acceptance criteria:**
- [ ] Add \`@Index()\` on \`expiresAt\`
- [ ] Add composite \`@Index(['status', 'expiresAt'])\`
- [ ] Generate and run migration"

i "payments: customerEmail stored in plain text — PII should be encrypted at rest" "Customer email addresses are stored unencrypted. The encrypted column transformer already used for bank account numbers should be applied.

**Acceptance criteria:**
- [ ] Apply \`encryptedColumnTransformer\` to \`customerEmail\`
- [ ] Migration to re-encrypt existing rows
- [ ] API response masks email to c***@example.com format"

i "payments: Soroban listener does not guard against race condition on duplicate confirmed events" "\`applySorobanPaymentConfirmed()\` checks status and returns early but does not prevent race conditions when two events arrive simultaneously for the same payment.

**Acceptance criteria:**
- [ ] Use a database-level optimistic lock or UPDATE … WHERE status != 'confirmed'
- [ ] Log and discard duplicates cleanly
- [ ] Unit test for concurrent event arrival"

i "payments: no payment.failed webhook dispatched when Soroban confirmation throws" "If the Soroban confirmation call throws, the payment status is left as PENDING with no webhook dispatched and no merchant notification.

**Acceptance criteria:**
- [ ] Catch Soroban errors, set status to FAILED
- [ ] Dispatch \`payment.failed\` webhook
- [ ] Send merchant email notification
- [ ] Unit test for failure path"

i "payments: metadata jsonb column has no GIN index — slow JSON field queries" "Filtering payments by metadata fields requires a full table scan without a GIN index.

**Acceptance criteria:**
- [ ] Add GIN index on \`metadata\` column
- [ ] Migration generated and tested
- [ ] Query plan shows index used"

i "payments: stellarMemo not indexed — Horizon monitor lookup is O(n)" "Stellar monitor resolves payments by memo. Without an index on \`stellarMemo\`, each confirmation event triggers a full table scan.

**Acceptance criteria:**
- [ ] Add \`@Index()\` on \`stellarMemo\`
- [ ] Migration generated and run
- [ ] Query plan verified"

i "settlements: initiateSettlement() has no database transaction — partial writes possible" "Multiple \`save()\` calls are made without a wrapping transaction. A crash between settlement creation and payment status update leaves DB in inconsistent state.

**Acceptance criteria:**
- [ ] Wrap in \`dataSource.transaction()\`
- [ ] Webhook dispatch only after transaction commits
- [ ] Test simulating mid-operation crash asserts rollback"

i "settlements: createBatchSettlement() has no transaction — partial write on failure" "Same issue as \`initiateSettlement()\` — multiple saves without a transaction. A failure after settlement save but before payment status update leaves payments stuck with no settlementId.

**Acceptance criteria:**
- [ ] Wrap in \`dataSource.transaction()\`
- [ ] All payment updates atomic with settlement creation"

i "settlements: fiat currency mapping only covers 4 countries — unknown countries silently default to USD" "Only NG, US, GB, AU are mapped. All other merchant countries default to USD without error or warning, potentially settling in the wrong currency.

**Acceptance criteria:**
- [ ] Expand mapping to all Stellar anchor-supported fiat currencies
- [ ] Admin-configurable currency mapping via RuntimeConfig
- [ ] Log error (not warn) if unknown country falls back to default"

i "settlements: approveSettlement() does not update linked payment statuses to SETTLING" "When a large settlement is approved, the linked payments remain in CONFIRMED status instead of being updated to SETTLING, breaking the payment lifecycle state machine.

**Acceptance criteria:**
- [ ] Fetch all payments with settlementId = settlement.id
- [ ] Update each to SETTLING status on approval
- [ ] Dispatch \`payment.settling\` webhook per payment"

i "settlements: rejectSettlement() leaves linked payments stuck in SETTLING with no recovery path" "Rejecting a settlement leaves linked payments stuck in SETTLING indefinitely. They need to be reset to CONFIRMED for reprocessing.

**Acceptance criteria:**
- [ ] Reset linked payments to CONFIRMED on rejection
- [ ] Clear settlementId on each linked payment
- [ ] Dispatch \`payment.settlement_rejected\` webhook"

i "settlements: partner callback does not verify HMAC signature — open to spoofing" "The partner callback endpoint accepts any payload without verifying that it originates from the legitimate settlement partner. A spoofed callback could mark a settlement as completed without actual fiat transfer.

**Acceptance criteria:**
- [ ] Verify \`X-Partner-Signature\` HMAC-SHA256 against \`PARTNER_WEBHOOK_SECRET\`
- [ ] Reject with 401 on missing or invalid signature
- [ ] Constant-time comparison to prevent timing attacks"

i "settlements: no idempotency on partner callback — duplicate callbacks can double-complete a settlement" "Callback handler does not check current settlement status before updating. A retried success callback on an already-COMPLETED settlement proceeds without error.

**Acceptance criteria:**
- [ ] Guard: if settlement already COMPLETED or FAILED, return 200 and no-op
- [ ] Log duplicate callback with settlement ID
- [ ] Unit test for idempotent replay"

i "settlements: executeFiatTransfer() has no timeout — hangs indefinitely on slow partner API" "Axios call to partner API has no \`timeout\` configured. A slow partner response holds the Bull job worker indefinitely, starving the queue.

**Acceptance criteria:**
- [ ] Set \`timeout: 30_000\` on the Axios request
- [ ] On timeout, throw a retriable error so Bull retries
- [ ] Admin alert after 3 consecutive timeouts for same settlement"

i "settlements: fee calculation uses hardcoded 1.5% — ignores merchant customFeeRate" "\`BATCH_FEE_RATE = 0.015\` is a constant. \`Merchant.customFeeRate\` exists on the entity but is never consulted during settlement fee calculation.

**Acceptance criteria:**
- [ ] Load merchant's \`customFeeRate\` before calculating fee
- [ ] Fall back to global \`BATCH_FEE_RATE\` if \`customFeeRate\` is null
- [ ] Unit test for custom rate override"

i "settlements: no index on settlements.merchantId — merchant settlement listing is O(n)" "\`findForMerchant()\` queries by \`merchantId\` without an index on that column.

**Acceptance criteria:**
- [ ] Add \`@Index()\` on \`merchantId\`
- [ ] Add composite \`@Index(['merchantId', 'status'])\`
- [ ] Migration generated"

i "settlements: no alert when settlement queue depth exceeds threshold" "No monitoring of Bull queue depth. If jobs pile up (e.g. partner API down), there is no alert until merchants start complaining.

**Acceptance criteria:**
- [ ] Cron job every 5 min checks settlement queue depth
- [ ] Alert if depth > 50 (configurable)
- [ ] Prometheus metric \`settlement_queue_depth\`"

i "settlements: batchSmallConfirmedPayments uses TypeORM LessThan() on decimal string column" "\`LessThan(SMALL_BATCH_THRESHOLD_USD)\` where the constant is a number is applied to \`amountUsd\` which is a decimal column. TypeORM may compare as string, causing incorrect batching.

**Acceptance criteria:**
- [ ] Use a raw query or explicit cast to ensure numeric comparison
- [ ] Unit test with amounts 9.99, 10.00, 10.01"

i "settlements: processSettlement() sends no email on completion — only partner callback path does" "\`processSettlement()\` sends no email on completion. Only \`handlePartnerCallback\` sends email, leaving direct settlement completions silent.

**Acceptance criteria:**
- [ ] Call \`emailService.sendSettlementStatusEmail()\` in \`processSettlement()\` on completion
- [ ] Unit test for email dispatch"

i "settlements: findForAdmin() date filter uses createdAt — admins need completedAt filter for reconciliation" "Admin date filter uses \`createdAt\` range, but admins typically want to filter by \`completedAt\` for reconciliation.

**Acceptance criteria:**
- [ ] Add \`dateField\` query param: \`created\` (default) or \`completed\`
- [ ] Query uses correct column based on param
- [ ] Swagger documented"

i "settlements: LARGE_SETTLEMENT_THRESHOLD duplicated as magic number 10000 in two methods" "The value 10000 appears as a hardcoded literal in both \`initiateSettlement()\` and \`createBatchSettlement()\`. The constant is only defined in the former.

**Acceptance criteria:**
- [ ] Extract to module-level constant or RuntimeConfig
- [ ] Both methods reference the same value
- [ ] No magic numbers remain in service"

i "auth: JWT secret length not validated at startup — short secrets accepted silently" "\`JWT_SECRET\` is loaded from env without a minimum-length check. A short or default secret like 'secret' is accepted and used in production without warning.

**Acceptance criteria:**
- [ ] Joi validation: \`JWT_SECRET\` must be at least 32 characters
- [ ] App fails to start with clear error on short secret"

i "auth: login endpoint leaks user existence via timing difference" "When no merchant is found the function throws immediately. When found but password is wrong it runs \`bcrypt.compare\`. This timing difference can enumerate registered emails.

**Acceptance criteria:**
- [ ] Always run \`bcrypt.compare\` against a dummy hash when merchant not found
- [ ] Constant-time response regardless of lookup result"

i "auth: refresh token not implemented — users must re-login every 7 days" "Only access tokens are issued. When a token expires users are logged out with no silent refresh option.

**Acceptance criteria:**
- [ ] Issue refresh token stored in Redis
- [ ] \`POST /auth/refresh\` endpoint exchanges refresh token for new access token
- [ ] Refresh token rotation on every use
- [ ] Old refresh token blacklisted after rotation"

i "auth: TOTP secret could leak through non-decorated serialization paths" "\`totpSecret\` column exists on the Merchant entity. If the \`@Exclude()\` decorator is ever missing from a serialization path, the TOTP secret leaks to the client.

**Acceptance criteria:**
- [ ] \`@Exclude()\` on \`totpSecret\` verified in all serialization paths
- [ ] Integration test asserting merchant profile response never contains \`totpSecret\`"

i "auth: lockout key never cleared on successful login — lockout can persist after correct credentials" "The lockout key is set when failed attempts reach the threshold but \`clearFailedLogin()\` only deletes the attempts key, not the lockout key itself.

**Acceptance criteria:**
- [ ] Clear both \`failedAttemptsKey\` AND \`lockoutKey\` on successful login
- [ ] Unit test: 5 failures → lockout → successful login → no lockout"

i "auth: API key scopes not validated on generateApiKey() — invalid scopes stored silently" "\`generateApiKey()\` accepts any array of strings as scopes. Invalid scope values not in the \`ApiScope\` enum are stored without validation.

**Acceptance criteria:**
- [ ] Validate each scope against \`ApiScope\` enum values
- [ ] Return 400 with invalid scope names listed
- [ ] Unit test for invalid scope input"

i "auth: isBlacklisted() called on every request — no local cache for hot path" "Every authenticated request hits Redis to check the JWT blacklist. Under high load this adds Redis round-trip latency to every request.

**Acceptance criteria:**
- [ ] Cache negative blacklist lookups in a local LRU cache (1000 entries, 60s TTL)
- [ ] Cache invalidated on \`logout()\` for the same jti"

i "auth: no password strength policy enforced on registration" "\`RegisterDto\` has no password complexity requirements. The string 'password' is a valid password.

**Acceptance criteria:**
- [ ] Min 8 characters, at least one uppercase, lowercase, digit, special character
- [ ] \`@Matches()\` regex validator on \`RegisterDto.password\`
- [ ] Error message lists all unmet requirements"

i "auth: no email verification after registration — fake emails create live accounts" "Merchants receive a JWT immediately on registration without verifying their email. Any email address can create a live merchant account.

**Acceptance criteria:**
- [ ] Send verification email with signed token on registration
- [ ] \`POST /auth/verify-email\` endpoint
- [ ] Unverified merchants limited to sandbox mode"

i "stellar: invokeContract() uses BASE_FEE — transactions dropped under network congestion" "Hardcoded \`fee: StellarSdk.BASE_FEE\` (100 stroops). During network congestion, transactions at base fee are dropped.

**Acceptance criteria:**
- [ ] Use \`simulateTransaction()\` result to set appropriate fee
- [ ] Configurable minimum fee via \`STELLAR_MIN_FEE\` env var
- [ ] Fee bump transaction on retry after fee-too-low error"

i "stellar: invokeContract() returns hash before ledger close — callers assume success on pending tx" "After \`sendTransaction()\` only PENDING status is checked. The function returns the hash without polling \`getTransaction()\` until SUCCESS or FAILED.

**Acceptance criteria:**
- [ ] Poll \`rpc.getTransaction(hash)\` with exponential backoff until non-PENDING
- [ ] Throw \`SorobanRpcException\` on FAILED status
- [ ] Timeout after 30s and throw retriable error"

i "stellar: Horizon polling cursor not persisted — restarts from scratch on app restart" "The Horizon transaction polling cursor is held in memory. App restart resets it, causing missed transactions between restart and next poll.

**Acceptance criteria:**
- [ ] Persist cursor in Redis or DB after each poll
- [ ] Load cursor on startup before first poll
- [ ] Metric: last processed ledger sequence"

i "stellar: Soroban event indexer has no replay mechanism for missed events" "If the indexer is down during a contract event emission those events are permanently missed. No historical replay from a saved ledger sequence.

**Acceptance criteria:**
- [ ] Persist last indexed ledger in DB
- [ ] On startup, replay events from last indexed ledger
- [ ] Admin endpoint to trigger manual replay from a given ledger"

i "stellar: verifyPayment() accepts XLM as valid — only USDC should be accepted" "\`verifyPayment()\` returns verified: true for both USDC and XLM payments. The platform should only accept USDC.

**Acceptance criteria:**
- [ ] Remove XLM acceptance from \`verifyPayment()\`
- [ ] Return \`{ verified: false }\` for any non-USDC asset
- [ ] Unit test asserting XLM payment is rejected"

i "stellar: no alerting when Stellar monitor has not processed a transaction in > 10 minutes" "If the Stellar monitor silently stops processing there is no alert. Payments would remain PENDING without anyone knowing.

**Acceptance criteria:**
- [ ] Track \`last_processed_at\` timestamp
- [ ] Alert if no transaction processed in 10 minutes (configurable)
- [ ] Prometheus metric \`stellar_monitor_last_processed_at\`"

i "stellar: sendPayment() does not verify destination account exists before submission" "Sending to a non-existent Stellar account results in an on-chain failure, wasting fees and requiring a retry cycle.

**Acceptance criteria:**
- [ ] Load destination account via \`server.loadAccount()\` before submission
- [ ] Throw \`BadRequestException\` with clear message if account not found"

i "blockchain-wallet: syncBalance() does not handle accounts with no USDC trustline" "If a wallet has no USDC trustline, \`getBalance()\` returns empty balances. The service may throw or store incorrect balance.

**Acceptance criteria:**
- [ ] Default to '0' if no USDC balance entry found
- [ ] Log warning if trustline not established
- [ ] Unit test for account with no USDC trustline"

i "blockchain-wallet: slippage service has no upper bound — 100% slippage accepted" "Slippage tolerance can be set to any value including 100% or higher, accepting any exchange rate regardless of market price.

**Acceptance criteria:**
- [ ] Max slippage capped at 5% (configurable via RuntimeConfig)
- [ ] Return 400 on slippage > cap
- [ ] Admin-only endpoint to override cap with justification"

i "blockchain-wallet: IV must be fully random per wallet — static prefix weakens AES-GCM" "If IV generation has any pattern or seed reuse, AES-GCM encryption is weakened. IV must be \`crypto.randomBytes(12)\` per wallet with no reuse.

**Acceptance criteria:**
- [ ] Confirm \`crypto.randomBytes(12)\` used every time
- [ ] Add assertion test that two wallets never share the same IV
- [ ] Add IV uniqueness index to \`blockchain_wallets\` table"

i "analytics: getVolume() serves stale materialized view data with no staleness indicator" "If the materialized view hasn't been refreshed, stale data is served with no staleness indicator. Merchants may see old numbers labeled as current.

**Acceptance criteria:**
- [ ] Include \`lastRefreshedAt\` timestamp in response
- [ ] Add \`isStale: true\` flag if refresh is > 10 minutes old
- [ ] Prometheus metric \`analytics_view_last_refresh_age_seconds\`"

i "analytics: clearCacheForMerchant() uses delPattern() — not supported by all cache backends" "\`cache.delPattern()\` is not atomic and not supported by in-memory cache backends, potentially silently no-oping.

**Acceptance criteria:**
- [ ] Confirm \`delPattern\` works for both Redis and in-memory backends
- [ ] Add integration test asserting cache is actually cleared"

i "analytics: top merchants query has no row limit — OOMs on large datasets" "Admin analytics endpoint for top merchants has no LIMIT clause, loading all merchants ordered by volume.

**Acceptance criteria:**
- [ ] Add configurable \`limit\` param (default 20, max 100)
- [ ] Apply LIMIT in the query
- [ ] Pagination support with cursor"

i "analytics: getFunnel() period bounds use local midnight instead of UTC" "\`new Date(now.getFullYear(), now.getMonth(), now.getDate())\` creates a local-timezone midnight. Merchants in non-UTC timezones see wrong period boundaries.

**Acceptance criteria:**
- [ ] Use \`startOfUtcDay()\` from \`date-range.util\` consistently
- [ ] Unit tests with mocked UTC dates"

i "analytics: monthly volume queries hit payments table directly — no materialized view" "Daily queries use the materialized view. Monthly queries fall back to a full payments table scan which is prohibitively slow for high-volume merchants.

**Acceptance criteria:**
- [ ] Create a \`monthly_payment_volume\` materialized view
- [ ] Monthly queries read from the view
- [ ] Refresh scheduled daily"

i "analytics: getRevenue() does not subtract refunded fee amounts — overstates platform revenue" "Revenue is calculated from settlement fee amounts only. Refunded payments that reduced fee revenue are not reflected.

**Acceptance criteria:**
- [ ] Subtract fee amounts for REFUNDED and PARTIALLY_REFUNDED payment settlements
- [ ] Add \`refundedFeeUsd\` field to revenue response"

i "analytics: no rate limiting on analytics export endpoint" "Export endpoint triggers an expensive DB query. No rate limit prevents a single merchant from triggering concurrent exports.

**Acceptance criteria:**
- [ ] 5 exports per day per merchant (configurable)
- [ ] Background job for ranges > 30 days
- [ ] 429 with Retry-After on excess"

i "analytics: payment funnel abandonmentRate formula needs documentation and test coverage" "\`abandonmentRate\` is calculated as (expired + failed) / total but the semantics are undocumented and untested.

**Acceptance criteria:**
- [ ] Document exactly which statuses count as abandoned
- [ ] Add \`pendingRate\` metric for payments still in-flight
- [ ] Unit test asserting SETTLING payments are not counted as abandoned"

i "webhooks: delivery service does not support secret rotation with grace period" "No endpoint exists to rotate only the webhook secret. The old secret remains active until explicitly replaced, with no grace period overlap.

**Acceptance criteria:**
- [ ] \`POST /webhooks/:id/rotate-secret\` endpoint
- [ ] Old secret remains valid for 1h (grace period) then invalidated
- [ ] Audit log entry on rotation"

i "webhooks: delivery does not include event ID — merchants cannot deduplicate retried events" "Webhook payload includes event and data but no unique \`eventId\`. Merchants receiving retried deliveries cannot deduplicate them.

**Acceptance criteria:**
- [ ] Add \`eventId: uuid\` to every webhook payload (stable across retries)
- [ ] Store \`eventId\` in \`WebhookDeliveryLog\`"

i "webhooks: SSRF protection resolves DNS only at creation — vulnerable to DNS rebinding" "DNS is resolved once at webhook creation. If a merchant's hostname later resolves to a private IP, subsequent deliveries will reach internal services.

**Acceptance criteria:**
- [ ] Re-resolve DNS on every delivery attempt, not just at creation
- [ ] Reject delivery and alert admin if private IP detected post-creation"

i "webhooks: any 2xx response treated as success — HTML error pages counted as delivery" "A merchant endpoint returning 200 OK with an HTML error page is counted as a successful delivery.

**Acceptance criteria:**
- [ ] Require Content-Type: application/json on 2xx response
- [ ] Log response body on failure for debugging
- [ ] Unit test for HTML 200 response treated as failure"

i "webhooks: delivery log never pruned — unbounded table growth" "\`WebhookDeliveryLog\` rows are never deleted. High-traffic merchants accumulate millions of rows.

**Acceptance criteria:**
- [ ] Cron job to delete delivery logs older than 90 days (configurable)
- [ ] Admin endpoint to query delivery log with pagination"

i "webhooks: dispatch() loads all merchant webhooks with no index on (merchantId, isActive)" "Every webhook dispatch loads all webhooks for the merchant without a composite index.

**Acceptance criteria:**
- [ ] Add composite index \`@Index(['merchantId', 'isActive'])\`
- [ ] Migration generated"

i "webhooks: no maximum webhook endpoints per merchant — allows unbounded resource usage" "A merchant can register unlimited webhook endpoints. Each dispatch iterates all of them, multiplying delivery jobs per event.

**Acceptance criteria:**
- [ ] Limit 10 webhook endpoints per merchant (configurable)
- [ ] Return 400 with clear message on limit exceeded"

i "webhooks: event subscription matching semantics undocumented — glob patterns unsupported" "\`w.events.includes(event)\` performs exact array element check. Comments imply wildcard behaviour but \`payment.*\` patterns are not supported.

**Acceptance criteria:**
- [ ] Document exact matching semantics in Swagger
- [ ] Support glob-style \`payment.*\` subscriptions
- [ ] Unit test for exact match, wildcard, and no-match scenarios"

i "admin: SuperAdminGuard references non-existent User entity and UserRole enum" "Guard imports \`User\` entity and \`UserRole\` enum which do not exist in this codebase. All SUPERADMIN-protected endpoints fail at runtime.

**Acceptance criteria:**
- [ ] Replace \`User\`/\`UserRole\` with \`Merchant\`/\`MerchantRole\`
- [ ] Guard tests with ADMIN and SUPERADMIN fixtures"

i "admin: no audit log for admin actions — cannot trace who changed what" "Admin actions (merchant suspension, fee updates, AML reviews) are not recorded in the audit log. Post-incident forensics are impossible.

**Acceptance criteria:**
- [ ] All admin write operations call \`AuditService.log()\`
- [ ] Audit entry includes: actor ID, action, resource type, resource ID, before/after, IP
- [ ] Admin endpoint to query audit log with filters"

i "admin: merchant suspension does not invalidate active JWTs" "When an admin suspends a merchant their existing JWTs remain valid until expiry (up to 7 days).

**Acceptance criteria:**
- [ ] On suspension, blacklist all active JTIs for the merchant in Redis
- [ ] Integration test: suspend merchant → existing token returns 401"

i "admin: fee update endpoint does not validate fee rate bounds" "Admin can set merchant \`customFeeRate\` to any value including negative numbers or values > 1 (100%+), corrupting settlement calculations.

**Acceptance criteria:**
- [ ] Validate \`customFeeRate\` is between 0 and 0.1 (10% max)
- [ ] Return 400 on out-of-bounds value"

i "admin: AML flag review endpoint allows invalid status transitions" "An AML flag can be transitioned to any status from any status (e.g. RESOLVED → PENDING). No state machine validation exists.

**Acceptance criteria:**
- [ ] Define valid transitions: PENDING → REVIEWING → RESOLVED or ESCALATED
- [ ] Reject invalid transitions with 400"

i "admin: alert deduplication key not namespaced by type — different alert types can suppress each other" "\`dedupeKey\` is a free-form string not namespaced by \`AdminAlertType\`. Two different alert types using the same key suppress each other.

**Acceptance criteria:**
- [ ] Auto-prefix dedupeKey with the alert type in \`raise()\`
- [ ] Unit test for cross-type deduplication isolation"

i "admin: /metrics endpoint unauthenticated — internal queue depths and payment volumes exposed" "\`/metrics\` endpoint is unauthenticated. Any external actor can read internal queue depths, error rates, and payment volumes.

**Acceptance criteria:**
- [ ] Restrict \`/metrics\` to admin IP allowlist or bearer token
- [ ] E2E test asserting unauthenticated /metrics returns 401 from public IP"

i "admin: merchant list endpoint loads all merchants into memory — no pagination" "Admin merchant list query has no LIMIT/OFFSET. With thousands of merchants this OOMs the process.

**Acceptance criteria:**
- [ ] Add \`page\` and \`limit\` query params (default: 20, max: 100)
- [ ] Return \`PaginatedResponseDto\`
- [ ] Index on \`merchants.createdAt\` for sorted pagination"

i "database: no migration rollback tests — rollbacks untested until production incident" "Migration rollback scripts exist but are not automatically tested in CI. A bad rollback discovered in production can cause data loss.

**Acceptance criteria:**
- [ ] CI step: run latest migration, rollback, re-run
- [ ] Assert schema state before and after is identical
- [ ] Block merge if rollback fails"

i "database: TypeORM synchronize:true risk — must be hard-disabled outside development" "If \`synchronize\` is ever enabled in staging or production, TypeORM will silently drop columns that don't match entities.

**Acceptance criteria:**
- [ ] Hard-code \`synchronize: false\` in non-dev environments in code (not just env var)
- [ ] Startup assertion throws and exits if synchronize is true in production"

i "database: connection pool size not tuned — DB_POOL_MIN/MAX env vars may not be wired in" "Default TypeORM pool of 10 connections will saturate under moderate load. \`.env.example\` shows DB_POOL_MAX=20 but this may not be applied.

**Acceptance criteria:**
- [ ] Confirm \`DB_POOL_MIN\` and \`DB_POOL_MAX\` are read and applied
- [ ] Recommended values documented in README
- [ ] Prometheus metric for pool utilization"

i "database: no CHECK constraints on critical numeric columns — negative amounts accepted at DB level" "\`amountUsd\`, \`feeAmountUsd\`, \`netAmountUsd\` have no database-level CHECK constraints. Application bugs could store negative amounts.

**Acceptance criteria:**
- [ ] CHECK (amount_usd > 0) on payments
- [ ] CHECK (fee_amount_usd >= 0) on settlements
- [ ] Migration with constraints"

i "database: missing composite indexes for common admin query patterns on settlements and AML" "Admin endpoints query by (status, createdAt) and (merchantId, status, createdAt) without covering indexes.

**Acceptance criteria:**
- [ ] \`@Index(['status', 'createdAt'])\` on Settlement
- [ ] \`@Index(['merchantId', 'status', 'createdAt'])\` on Settlement
- [ ] \`@Index(['status', 'createdAt'])\` on AmlFlag
- [ ] Migrations generated"

i "database: backup service pg_dump failure does not raise AdminAlert" "pg_dump failures are logged but do not raise an AdminAlert. A silent backup failure could go undetected until a restore is needed.

**Acceptance criteria:**
- [ ] Raise \`AdminAlertType.BACKUP_FAILURE\` on pg_dump non-zero exit
- [ ] Alert deduplicated per day"

i "database: WAL archiving not configured — point-in-time recovery limited to daily backups" "PITR is mentioned as a goal but WAL archiving is not configured. Without WAL, recovery granularity is daily backup only.

**Acceptance criteria:**
- [ ] Document WAL archiving configuration for PostgreSQL
- [ ] archive_command pushes WAL segments to S3
- [ ] Recovery drill procedure updated"

i "database: numeric transformer does not handle null input — throws on nullable columns" "If a nullable column is null the transformer's \`from()\` function may call \`.toString()\` on null, throwing a runtime exception.

**Acceptance criteria:**
- [ ] Return null from \`from()\` when value is null/undefined
- [ ] Unit test for null and undefined inputs"

i "aml: velocity check resets at UTC midnight — not a rolling 24h window" "\`HIGH_VELOCITY_LIMIT\` is checked against payments since UTC midnight. A merchant can make 49 payments at 23:59 and 49 more at 00:01 without triggering a flag.

**Acceptance criteria:**
- [ ] Use rolling 24h window: createdAt >= NOW() - INTERVAL '24 hours'
- [ ] Unit test for the midnight boundary case"

i "aml: HIGH_VALUE_THRESHOLD hardcoded at \$10,000 — not configurable per jurisdiction" "Different jurisdictions have different AML reporting thresholds. The hardcoded value may not be legally correct for all merchant countries.

**Acceptance criteria:**
- [ ] Move threshold to RuntimeConfig
- [ ] Support per-country thresholds
- [ ] Admin endpoint to update thresholds"

i "aml: AML flag confirmation does not auto-suspend merchant" "An AML flag resolved as CONFIRMED_FRAUD has no automatic trigger to suspend the merchant. Admin must manually navigate and suspend separately.

**Acceptance criteria:**
- [ ] On AML flag resolution with CONFIRMED_FRAUD status, auto-suspend merchant
- [ ] Log auto-suspension in audit trail
- [ ] Admin can override auto-suspension policy"

i "aml: no AML check at settlement initiation — flagged payments proceed to fiat transfer" "\`checkAndFlag()\` is called only on payment creation. Settlement initiation (where actual fiat transfer happens) has no AML re-check.

**Acceptance criteria:**
- [ ] Check AML flag status before initiating settlement
- [ ] Block settlement if any linked payment has an open AML flag
- [ ] Alert admin when settlement blocked"

i "aml: AML alert email has no link to the review panel — admin must navigate manually" "Admin alert email body includes reason and IDs but no direct link to the admin review panel for the flag.

**Acceptance criteria:**
- [ ] Include ADMIN_PANEL_URL/aml/{flagId} in email body
- [ ] \`ADMIN_PANEL_URL\` configurable via env var"

i "aml: no Prometheus metrics for AML flag volume — spikes in fraud undetectable" "No Prometheus metrics for AML flag creation rate. A sudden spike in flags goes undetected by SRE tooling.

**Acceptance criteria:**
- [ ] Counter: \`aml_flags_created_total\` labeled by reason
- [ ] Gauge: \`aml_flags_open_total\`
- [ ] Alert rule: more than 10 HIGH_VALUE flags in 5 minutes"

i "notifications: email queue processor has no dead letter handling — failed emails silently dropped" "After max retries, failed email jobs are discarded with no alert. Critical emails like settlement completion can be permanently lost.

**Acceptance criteria:**
- [ ] Move permanently failed jobs to dead letter queue
- [ ] Admin alert on DLQ entry
- [ ] Admin endpoint to view and replay DLQ emails"

i "notifications: outbound emails have no unsubscribe link — CAN-SPAM / GDPR violation" "Outbound merchant emails do not include an unsubscribe link, violating CAN-SPAM and GDPR requirements.

**Acceptance criteria:**
- [ ] All notification emails include one-click unsubscribe link
- [ ] \`POST /merchant/notifications/unsubscribe\` endpoint
- [ ] Unsubscribed merchants excluded from non-critical emails"

i "notifications: NotificationPrefsService.notify() does not check merchant unsubscribe status" "\`notify()\` sends email regardless of merchant unsubscribe or email-disabled status.

**Acceptance criteria:**
- [ ] Check unsubscribe flag before dispatching
- [ ] Also check \`paymentConfirmedEmailEnabled\` for payment notifications
- [ ] Unit test: unsubscribed merchant receives no email"

i "notifications: Handlebars templates loaded lazily — missing template crashes at send time" "Email templates are loaded lazily. A missing or malformed template is not discovered until an email is attempted, causing a runtime error mid-flow.

**Acceptance criteria:**
- [ ] Load and compile all Handlebars templates at module initialization
- [ ] Fail fast if any template is missing or has a syntax error"

i "notifications: SendGrid 429 rate limit errors not handled — silent email delivery failure" "If SendGrid returns 429, the email job fails without retry scheduling aligned to the Retry-After header.

**Acceptance criteria:**
- [ ] Catch 429 from SendGrid, extract Retry-After, schedule Bull job delay accordingly
- [ ] Metric: \`email_rate_limit_hits_total\`"

i "observability: Sentry DSN not validated at startup — app boots with no error tracking" "If SENTRY_DSN is unset or malformed, Sentry initializes silently. Production could be running without error reporting for days.

**Acceptance criteria:**
- [ ] Warn loudly at startup if Sentry DSN is not configured
- [ ] Health check endpoint includes Sentry status"

i "observability: OpenTelemetry not capturing TypeORM database query spans" "Auto-instrumentation is configured but TypeORM queries may not be captured as spans, making slow query diagnosis harder.

**Acceptance criteria:**
- [ ] Confirm \`@opentelemetry/instrumentation-pg\` is included
- [ ] Database span includes: query, duration, table name
- [ ] Slow query threshold alert (> 500ms)"

i "observability: no business-level Prometheus metrics — payment conversion rate not tracked" "No Prometheus metrics for core business health: payment conversion rate, settlement success rate, average settlement time.

**Acceptance criteria:**
- [ ] \`payment_conversion_rate\` gauge (settled / confirmed in last hour)
- [ ] \`settlement_success_rate\` gauge
- [ ] \`settlement_duration_p95_seconds\` histogram"

i "observability: health check /health does not test database connectivity" "Readiness probe returns OK without testing actual DB connection. A dead DB would still report healthy to the load balancer.

**Acceptance criteria:**
- [ ] Add TypeORM health indicator using \`@nestjs/terminus\`
- [ ] SELECT 1 query with 2s timeout
- [ ] Return degraded if DB responds slowly, down if unreachable"

i "observability: log lines for payments and settlements lack structured context fields" "Log lines for payment operations do not include \`paymentId\`, \`merchantId\`, or \`settlementId\` as structured fields.

**Acceptance criteria:**
- [ ] All payment-related log calls include { paymentId, merchantId } context
- [ ] All settlement-related logs include { settlementId, merchantId }
- [ ] Winston format outputs valid JSON in production"

i "observability: backup success/failure not tracked in Prometheus" "No metrics for backup operations. SRE teams cannot build alerts for backup failures.

**Acceptance criteria:**
- [ ] Counter: \`db_backup_success_total\` and \`db_backup_failure_total\`
- [ ] Gauge: \`db_backup_last_success_timestamp\`
- [ ] Alert: backup not completed in 25h"

i "observability: runtime config changes not logged or alerted" "Changes to runtime configuration (fee rates, thresholds) are applied silently with no audit trail or alert.

**Acceptance criteria:**
- [ ] \`AuditService.log()\` on every runtime config update
- [ ] Admin alert on change to financial-critical keys
- [ ] \`GET /admin/runtime-config/history\` endpoint"

i "observability: no uptime heartbeat when cron jobs are stuck" "If a cron job hangs the app remains alive and healthy from the load balancer's perspective.

**Acceptance criteria:**
- [ ] Each cron job pings the uptime heartbeat on completion
- [ ] Heartbeat URL per job configurable via env
- [ ] Alert if heartbeat not received within 2× job interval"

i "security: TLS enforcement middleware trusts X-Forwarded-Proto without validating proxy config" "TLS enforcement reads \`X-Forwarded-Proto\`. If TRUST_PROXY=false (default), this header can be spoofed to bypass TLS enforcement.

**Acceptance criteria:**
- [ ] Only trust \`X-Forwarded-Proto\` when TRUST_PROXY is correctly configured
- [ ] In production without a trusted proxy, detect HTTP via socket directly"

i "security: sensitive access middleware logs full request paths including UUIDs — PII in logs" "Logging full request paths can expose payment IDs and merchant IDs in log aggregation systems.

**Acceptance criteria:**
- [ ] Redact UUIDs from logged paths (/payments/uuid → /payments/[id])
- [ ] Redact query params that may contain sensitive data"

i "security: Helmet CSP configured without report-uri — CSP violations go undetected" "Helmet is configured but without a report-uri directive. CSP violations are silently blocked with no visibility.

**Acceptance criteria:**
- [ ] Configure report-uri pointing to Sentry or a CSP reporting endpoint
- [ ] Env var: CSP_REPORT_URI"

i "security: ALLOWED_ORIGINS unset in production defaults to permissive CORS" "If ALLOWED_ORIGINS is unset in production, CORS may default to allow all origins.

**Acceptance criteria:**
- [ ] If ALLOWED_ORIGINS is unset in production, app fails to start
- [ ] Joi validation for ALLOWED_ORIGINS in production mode
- [ ] Integration test: request from unlisted origin returns 403"

i "security: encrypted column key has no versioning — key rotation breaks all existing decryption" "AES encryption key for bank account numbers is derived at startup with no version tracking. Key rotation breaks decryption of all existing values.

**Acceptance criteria:**
- [ ] Add \`encKeyVersion\` column to Merchant
- [ ] Migration to re-encrypt with versioned keys
- [ ] Admin endpoint to trigger re-encryption job"

i "security: no geofencing or new-country login alert for merchant accounts" "No monitoring of login geography. A compromised credential used from a foreign IP is indistinguishable from a normal login.

**Acceptance criteria:**
- [ ] Log country code derived from IP on every login
- [ ] Flag login if country differs from merchant's registered country
- [ ] Send merchant email alert on login from new country"

i "security: INTERNAL_SERVICE_SECRET not rotatable without redeploy" "Internal service secret is loaded from env at startup only. Rotation requires a full redeploy.

**Acceptance criteria:**
- [ ] Store secret in RuntimeConfig DB table with cache TTL of 60s
- [ ] Admin endpoint to rotate secret (new and old both valid for 5 minutes)
- [ ] Audit log on rotation"

i "testing: no contract tests between backend and Soroban contracts" "Backend assumes specific Soroban contract function signatures. Breaking contract changes are undetectable until runtime.

**Acceptance criteria:**
- [ ] Consumer-driven contract tests using Pact or a custom schema validator
- [ ] Contract test runs against testnet contract on every CI run"

i "testing: SettlementsService has zero unit test coverage" "The most financially critical service has no test file.

**Acceptance criteria:**
- [ ] Unit tests for: initiateSettlement, processSettlement, handlePartnerCallback, approveSettlement, rejectSettlement
- [ ] Coverage > 80% for this file"

i "testing: StellarService has zero unit test coverage" "No tests for XLM rate fetching, fallback logic, Soroban invocation, or payment verification.

**Acceptance criteria:**
- [ ] Unit tests for \`getXlmUsdRate()\` including fallback path
- [ ] Tests for \`invokeContract()\` with mock Soroban RPC
- [ ] Tests for \`verifyPayment()\` for valid USDC, invalid asset, wrong memo"

i "testing: WebhooksService SSRF guard has no negative test cases for private IP ranges" "\`assertPublicUrl()\` has no tests for the private IP ranges it is supposed to block.

**Acceptance criteria:**
- [ ] Test for each private range: 10.0.0.1, 172.16.0.1, 192.168.0.1, 127.0.0.1, ::1
- [ ] Test for IPv6 mapped IPv4 addresses (::ffff:10.0.0.1)"

i "testing: no load test covering settlement queue throughput" "Existing k6 load test covers payment creation only. Settlement queue throughput under load is untested.

**Acceptance criteria:**
- [ ] Add k6 scenario: create 500 payments, confirm all, assert settlements complete within 60s
- [ ] Track: settlement p95 latency, queue depth, error rate"

i "testing: db seed script fails on re-run due to unique constraint violations" "Re-running \`db:seed\` fails with unique constraint violations instead of upserting seed data.

**Acceptance criteria:**
- [ ] Use upsert or truncate-then-insert strategy
- [ ] Seed completes cleanly on a database with existing data"

i "testing: no integration tests for the full payment lifecycle end-to-end" "No integration tests cover: payment creation → Stellar confirmation → settlement → webhook dispatch.

**Acceptance criteria:**
- [ ] Integration test suite in \`test/integration/\`
- [ ] Uses in-memory Postgres or test database
- [ ] Mocks Stellar Horizon and Soroban RPC
- [ ] CI runs integration tests in a separate step"

i "testing: no E2E tests for merchant onboarding and first settlement" "No E2E test suite covers the merchant-facing API from registration to first settlement.

**Acceptance criteria:**
- [ ] register → login → create payment → confirm → settle → webhook received
- [ ] Seeds test database before each suite
- [ ] Runs in CI with real PostgreSQL + Redis via Docker Compose"

i "testing: Jest coverage threshold not enforced — coverage can drop to 0% without CI failure" "No coverage threshold set in \`jest.config.js\`. Coverage can silently regress to zero.

**Acceptance criteria:**
- [ ] Set Jest coverage threshold to 70% globally
- [ ] CI fails build if coverage drops below threshold"

i "config: .env.example has duplicate SMTP variable sets causing new developer confusion" "Two parallel sets of SMTP variables exist: the legacy SMTP_* block and the current EMAIL_SMTP_* block.

**Acceptance criteria:**
- [ ] Remove legacy SMTP_* block from .env.example
- [ ] Add comments explaining the distinction between email config blocks"

i "config: no CONTRIBUTING.md — no guide for branch strategy, PR process, or test requirements" "No contribution guide exists. New developers don't know the branch strategy, PR process, or test requirements.

**Acceptance criteria:**
- [ ] CONTRIBUTING.md with: branch naming, PR template, test requirements, commit format
- [ ] PR template in .github/pull_request_template.md"

i "config: no docker-compose.yml for local development — setup requires manual installs" "README describes prerequisites but no Docker Compose file exists for local dev. Onboarding takes 30+ minutes.

**Acceptance criteria:**
- [ ] docker-compose.dev.yml with Postgres 16, Redis 6, and the app in watch mode
- [ ] README updated with single-command setup"

i "config: ESLint has no no-console rule — console.log usage unrestricted in services" "No ESLint rule prevents \`console.log\`. Services use it instead of Logger, bypassing structured logging.

**Acceptance criteria:**
- [ ] Add 'no-console': 'error' to ESLint config
- [ ] Fix all existing violations
- [ ] CI fails on new violations"

i "config: Swagger UI served in production — full API surface exposed publicly" "Swagger UI at /docs is served in all environments including production, exposing the full API surface.

**Acceptance criteria:**
- [ ] Disable Swagger in NODE_ENV=production or gate behind admin auth
- [ ] E2E test: /docs returns 404 in production mode"

i "config: no API version field in Swagger spec — version undocumented" "Swagger spec has no version field. API consumers cannot track which version they are integrating with.

**Acceptance criteria:**
- [ ] Set version from package.json in Swagger DocumentBuilder
- [ ] \`GET /api/v1/version\` returns version and git sha"

i "config: no CHANGELOG.md — breaking changes undiscoverable without reading git history" "No changelog exists. Breaking changes are undiscoverable without reading git history.

**Acceptance criteria:**
- [ ] CHANGELOG.md with entries for all breaking changes to date
- [ ] Conventional commits enforced via commitlint"

i "config: ormconfig.ts duplicates database connection config from DatabaseModule" "Database connection config is defined in both ormconfig.ts and DatabaseModule. Two sources of truth for DB credentials.

**Acceptance criteria:**
- [ ] Extract shared config to src/config/database.config.ts
- [ ] Both ormconfig.ts and DatabaseModule import from the shared config"

i "config: no precommit hook — lint and tests not enforced before commit" "Developers can commit without running lint or tests. CI is the first gate, causing slow feedback loops.

**Acceptance criteria:**
- [ ] husky + lint-staged: run ESLint on staged TS files pre-commit
- [ ] Run jest for files changed in commit"

i "payments: no support for partial payments — customer must pay exact amount" "The platform requires the customer to pay the exact quoted XLM amount. Slight discrepancies due to wallet rounding cause payment failures.

**Acceptance criteria:**
- [ ] Accept payments within ±1% of quoted amount (configurable tolerance)
- [ ] Store actual received amount on payment record
- [ ] Adjust settlement amount to actual received"

i "payments: QR code not regenerated when XLM rate changes on pending payment" "If a payment stays PENDING while the XLM rate changes significantly, the QR code shows an outdated amount. The customer pays the old amount but the payment expects the original.

**Acceptance criteria:**
- [ ] Endpoint to refresh QR code / XLM amount for a pending payment
- [ ] Auto-refresh QR if payment is > 5 minutes old and rate has moved > 2%
- [ ] New amount sent to customer via email/webhook"

i "merchants: no index on merchants.email — login lookup is O(n)" "Every login does \`findOne({ where: { email } })\` without an index on \`email\`. As the merchant table grows, login latency increases linearly.

**Acceptance criteria:**
- [ ] Confirm \`@Column({ unique: true })\` creates an index on email (TypeORM creates unique index automatically)
- [ ] Query plan verified
- [ ] Add explicit \`@Index()\` decorator for clarity"

i "merchants: totalVolumeUsd updated nowhere in the codebase — always shows 0" "The \`totalVolumeUsd\` field on Merchant exists but no service increments it when settlements complete.

**Acceptance criteria:**
- [ ] Increment \`totalVolumeUsd\` on \`MerchantsService\` when settlement COMPLETED
- [ ] Use atomic \`UPDATE merchants SET total_volume_usd = total_volume_usd + ? WHERE id = ?\`
- [ ] Backfill migration for existing merchants"

i "merchants: bankAccountNumber decryption fails with no graceful fallback for legacy plaintext rows" "If \`bankAccountNumber\` was stored before encryption was added, decryption will fail on legacy rows with no fallback.

**Acceptance criteria:**
- [ ] Detect plaintext values (no encryption envelope header) and return as-is
- [ ] Migration job to encrypt all legacy plaintext rows
- [ ] Log warning for each legacy row detected"

i "merchants: no endpoint to list or revoke individual API keys" "Merchants can generate an API key but there is no endpoint to list active keys or revoke one without regenerating.

**Acceptance criteria:**
- [ ] \`GET /merchant/api-keys\` lists active keys with created date and last-used date
- [ ] \`DELETE /merchant/api-keys/:id\` revokes a specific key
- [ ] Revoked key returns 401 immediately (no grace period)"

i "queues: dead letter queue not configured for any Bull queue — failed jobs permanently lost" "Failed Bull jobs (settlements, webhooks, emails) are retried up to max attempts then silently discarded.

**Acceptance criteria:**
- [ ] Configure DLQ for settlement, webhook, and email queues
- [ ] Failed jobs after max retries moved to DLQ
- [ ] Admin endpoint to list and replay DLQ jobs"

i "queues: no concurrency limit on settlement processor — can overload partner API" "Settlement Bull processor has no concurrency setting. All pending settlement jobs run simultaneously, potentially saturating the partner API.

**Acceptance criteria:**
- [ ] Set concurrency: 5 on settlement processor (configurable)
- [ ] Per-merchant concurrency lock already exists — verify it still applies
- [ ] Metric: active settlement jobs"

i "queues: Bull queue dashboard not exposed for admin monitoring" "No Bull Board or similar dashboard is available to admins for monitoring job queues.

**Acceptance criteria:**
- [ ] Integrate bull-board at \`/admin/queues\` (admin auth required)
- [ ] Shows: job counts (waiting, active, completed, failed) per queue
- [ ] Allows manual job retry from UI"

i "queues: QUEUE_NAMES constants duplicated across queue.constants.ts and older queue config" "Queue name constants appear in multiple files. A rename in one place doesn't propagate automatically.

**Acceptance criteria:**
- [ ] Single \`QUEUE_NAMES\` source of truth in \`src/queues/queue.constants.ts\`
- [ ] All other references import from that file
- [ ] Lint rule or TS barrel prevents re-definition"

i "runtime-config: get() passes raw number to CacheService.set — config cached for 24h instead of 60s" "\`RuntimeConfigService.get()\` passes \`{ ttl: seconds }\` instead of \`{ ttlSeconds: seconds }\` to CacheService, silently falling back to the 86400s default.

**Acceptance criteria:**
- [ ] Fix option key to \`ttlSeconds\`
- [ ] Unit test asserting config is cached for the correct duration
- [ ] Regression test to prevent wrong option key"

i "runtime-config: no validation on runtime config values — invalid types stored silently" "Runtime config values are stored as strings with no type validation. Setting \`fee_rate\` to \`'banana'\` causes silent NaN in settlement calculations.

**Acceptance criteria:**
- [ ] Type schema per config key (number, boolean, string, enum)
- [ ] Validation on write — reject invalid types with 400
- [ ] Type-safe \`get<T>()\` method"

i "cron: cron jobs run on all instances in multi-replica deployment — duplicate job execution" "If multiple instances of the app are running, cron jobs (Stellar monitor, batch settlements) fire on each instance simultaneously, causing duplicate processing.

**Acceptance criteria:**
- [ ] Use Redis-based distributed lock (e.g. Redlock) for each cron job
- [ ] Only one instance executes a given cron job at a time
- [ ] Lock TTL set to 2× expected job duration"

i "health: liveness and readiness probes return same response — Kubernetes cannot distinguish them" "Both liveness and readiness endpoints likely return the same OK response. Kubernetes uses them differently: readiness should include downstream deps, liveness should not.

**Acceptance criteria:**
- [ ] \`GET /health/live\` — only checks process health (memory, event loop)
- [ ] \`GET /health/ready\` — checks DB, Redis, and queue connectivity
- [ ] Kubernetes manifests reference correct endpoints"

i "health: health check response does not include version or git SHA" "Health response returns only status. Operators cannot tell which version is running from a health check alone.

**Acceptance criteria:**
- [ ] Include \`version\` (from package.json) and \`gitSha\` (from BUILD_SHA env) in health response
- [ ] \`uptime\` in seconds
- [ ] \`environment\` (NODE_ENV)"

echo ""
echo "=== Backend: 125 issues created ==="
