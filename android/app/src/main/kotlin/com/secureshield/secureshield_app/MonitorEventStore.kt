package com.secureshield.secureshield_app

import java.util.UUID

/** The minimal SQL surface the store needs. Android-free so the store is unit-tested on the JVM against real SQLite. */
interface SqlDb {
    /** Runs one statement; returns the number of rows it changed. */
    fun exec(sql: String, args: List<Any?> = emptyList()): Int

    /** Runs one query; each row is column name to Long, String or null. */
    fun query(sql: String, args: List<Any?> = emptyList()): List<Map<String, Any?>>

    /** All-or-nothing: if [block] throws, nothing it wrote is kept and the exception propagates. Not re-entrant. */
    fun <T> transaction(block: () -> T): T
}

/**
 * F19 Stage 2B: the durable on-device store for package events (Android SQLite in production, real SQLite in the tests).
 *
 * Rules:
 *  • An event is stored BEFORE it is analysed or notified, so a process death never loses it.
 *  • The id is a UUID generated on the device; it is also the backend's `client_event_id`, so a retried upload is idempotent.
 *  • Every row has an owner (the signed-in account's opaque id). Nothing is stored while no owner is set, and every read or
 *    write is scoped to the CURRENT owner, so one account can never drain, mark or see another account's events.
 *  • History sync and guardian delivery are tracked separately (`history_state`, `guardian_state`) because the server
 *    reports them independently.
 *  • Nothing here logs or throws on a storage error: every public method returns a safe value instead. No package name, app
 *    name or owner id ever reaches a log (this class does not log at all).
 */
class MonitorEventStore(
    private val db: SqlDb,
    private val clock: () -> Long = System::currentTimeMillis,
    private val newId: () -> String = { UUID.randomUUID().toString() },
) {
    companion object {
        const val DB_VERSION = 2
        const val MAX_ATTEMPTS = 10
        const val MAX_DRAIN = 50 // the backend accepts at most 50 events per batch
        const val MAX_ROWS = 2000
        const val DEDUPE_WINDOW_MS = 10_000L // ADDED then REPLACED for one update, or a re-delivered broadcast
        const val IN_FLIGHT_ANALYSIS_MS = 60_000L
        const val TERMINAL_RETENTION_MS = 7L * 24 * 3600 * 1000
        const val MAX_AGE_MS = 30L * 24 * 3600 * 1000
        const val MAX_PERMS = 300
        private const val BACKOFF_BASE_MS = 30_000L
        private const val BACKOFF_MAX_MS = 3_600_000L

        val SCHEMA = listOf(
            """CREATE TABLE IF NOT EXISTS monitor_events (
                id TEXT PRIMARY KEY NOT NULL,
                owner TEXT NOT NULL,
                occurred_at INTEGER NOT NULL,
                package_name TEXT NOT NULL,
                event_type TEXT NOT NULL,
                app_name TEXT,
                version_name TEXT,
                installer_package TEXT,
                is_unknown_source INTEGER NOT NULL DEFAULT 0,
                is_system_app INTEGER NOT NULL DEFAULT 0,
                dangerous_perms TEXT,
                perm_count INTEGER NOT NULL DEFAULT 0,
                has_overlay INTEGER NOT NULL DEFAULT 0,
                first_install_time INTEGER,
                local_risk_score INTEGER NOT NULL DEFAULT 0,
                analysis_state TEXT NOT NULL DEFAULT 'pending',
                history_state TEXT NOT NULL DEFAULT 'pending',
                guardian_state TEXT NOT NULL DEFAULT 'pending',
                attempts INTEGER NOT NULL DEFAULT 0,
                next_attempt_at INTEGER NOT NULL DEFAULT 0,
                guardian_reason TEXT,
                last_error TEXT,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )""",
            "CREATE INDEX IF NOT EXISTS ix_monitor_events_drain ON monitor_events (owner, history_state, next_attempt_at)",
            "CREATE INDEX IF NOT EXISTS ix_monitor_events_dedupe ON monitor_events (owner, package_name, event_type, occurred_at)",
            "CREATE TABLE IF NOT EXISTS monitor_meta (k TEXT PRIMARY KEY NOT NULL, v TEXT)",
            DIAG_TABLE,
        )

        /** Counts of events removed by retention while still unsent / failed / rejected, so cleanup never hides them. */
        const val DIAG_TABLE =
            "CREATE TABLE IF NOT EXISTS monitor_diag (owner TEXT NOT NULL, kind TEXT NOT NULL, n INTEGER NOT NULL DEFAULT 0, " +
                "PRIMARY KEY (owner, kind))"

        /** Columns version 2 added to monitor_events (nullable, additive). See [MonitorSchema.upgradeV1ToV2]. */
        val V2_COLUMNS = listOf("guardian_reason" to "TEXT", "last_error" to "TEXT")

        const val HISTORY_PENDING = "pending"
        const val HISTORY_SYNCED = "synced"
        const val HISTORY_REJECTED = "rejected"
        const val HISTORY_FAILED = "failed"
        // Guardian states describe what the SERVER told us, never that anyone received anything:
        const val GUARDIAN_PENDING = "pending" // no answer yet
        const val GUARDIAN_ACCEPTED = "accepted" // the server holds the alert (queued, already queued, pending or leased)
        const val GUARDIAN_PROVIDER_ACCEPTED = "provider_accepted" // the SMS/e-mail provider accepted it; NOT handset delivery
        const val GUARDIAN_NOT_SENT = "not_sent" // not eligible, expired, nothing to send, or the history never synced
        const val GUARDIAN_FAILED = "failed" // the server gave up sending it
        private val CODE = Regex("^[a-z][a-z0-9_]{0,39}$")

        /** Reason and error codes are short lowercase identifiers; anything else (free text, a package name) is dropped. */
        fun code(s: String?): String? = s?.takeIf { CODE.matches(it) }
        private const val OWNER_KEY = "owner"
    }

    sealed class Recorded {
        data class New(val id: String) : Recorded()
        data class Duplicate(val id: String) : Recorded()
        object NoOwner : Recorded()
        object Failed : Recorded()
    }

    /** What the analyser found; every field is optional so an unavailable package still has a (minimal) event. */
    data class Analysis(
        val appName: String?,
        val versionName: String?,
        val installerPackage: String?,
        val isUnknownSource: Boolean,
        val isSystemApp: Boolean,
        val dangerousPerms: List<String>,
        val permCount: Int,
        val hasOverlay: Boolean,
        val firstInstallTime: Long?,
        val localRiskScore: Int,
    )

    /** One device-side result for one event, from the backend's per-event outcome. */
    data class Result(
        val id: String?,
        val history: String?,
        val guardian: String?,
        val guardianReason: String? = null,
        val reason: String? = null, // rejection reason or retry error code
    )

    data class MarkSummary(val updated: Int, val ignored: Int)

    /** ok=false means the delete (or its bookkeeping) did not complete: the caller must not claim the data is gone. */
    data class PurgeResult(val ok: Boolean, val deleted: Int)

    @Volatile
    var storageErrors = 0
        private set

    private inline fun <T> safe(fallback: T, block: () -> T): T = try {
        block()
    } catch (_: Throwable) {
        storageErrors++
        fallback
    }

    /** Creates the tables. Safe to repeat. */
    fun init(): Boolean = safe(false) {
        SCHEMA.forEach { db.exec(it) }
        true
    }

    fun currentOwner(): String? = safe<String?>(null) { readOwner() }

    /** Unlike [currentOwner], a storage error propagates, so callers report "failed" instead of "no account". */
    private fun readOwner(): String? =
        db.query("SELECT v FROM monitor_meta WHERE k = ?", listOf(OWNER_KEY)).firstOrNull()?.get("v") as String?

    /**
     * Sets the signed-in account (null = signed out). Switching to a DIFFERENT account deletes every other account's events
     * in the same transaction, so nothing of the previous account survives into the next one. Returns false on a storage
     * error, in which case the owner is left as it was.
     */
    fun setOwner(owner: String?): Boolean = safe(false) {
        val clean = owner?.trim()?.takeIf { it.isNotEmpty() && it.length <= 128 }
        if (owner != null && clean == null) return@safe false
        db.transaction {
            if (clean == null) {
                db.exec("DELETE FROM monitor_meta WHERE k = ?", listOf(OWNER_KEY))
            } else {
                db.exec("DELETE FROM monitor_events WHERE owner <> ?", listOf(clean))
                db.exec("DELETE FROM monitor_diag WHERE owner <> ?", listOf(clean))
                db.exec("INSERT OR REPLACE INTO monitor_meta (k, v) VALUES (?, ?)", listOf(OWNER_KEY, clean))
            }
        }
        true
    }

    /** Stores the event FIRST (before analysis or notification). */
    fun record(packageName: String, eventType: String, occurredAt: Long = clock()): Recorded = safe<Recorded>(Recorded.Failed) {
        if (packageName.isEmpty() || packageName.length > 255) return@safe Recorded.Failed
        if (eventType != "installed" && eventType != "updated" && eventType != "removed") return@safe Recorded.Failed
        val owner = readOwner() ?: return@safe Recorded.NoOwner
        val now = clock()
        db.transaction {
            val dup = db.query(
                "SELECT id FROM monitor_events WHERE owner = ? AND package_name = ? AND event_type = ? " +
                    "AND occurred_at BETWEEN ? AND ? LIMIT 1",
                listOf(owner, packageName, eventType, occurredAt - DEDUPE_WINDOW_MS, occurredAt + DEDUPE_WINDOW_MS),
            ).firstOrNull()
            if (dup != null) return@transaction Recorded.Duplicate(dup["id"] as String)
            housekeeping(now)
            val id = newId()
            val inserted = db.exec(
                "INSERT OR IGNORE INTO monitor_events (id, owner, occurred_at, package_name, event_type, created_at, updated_at) " +
                    "VALUES (?, ?, ?, ?, ?, ?, ?)",
                listOf(id, owner, occurredAt, packageName, eventType, now, now),
            )
            if (inserted == 1) Recorded.New(id) else Recorded.Failed
        }
    }

    /** Adds the analysis to a stored event (current owner only). */
    fun attachAnalysis(id: String, a: Analysis): Boolean = safe(false) {
        val owner = readOwner() ?: return@safe false
        db.exec(
            "UPDATE monitor_events SET app_name = ?, version_name = ?, installer_package = ?, is_unknown_source = ?, " +
                "is_system_app = ?, dangerous_perms = ?, perm_count = ?, has_overlay = ?, first_install_time = ?, " +
                "local_risk_score = ?, analysis_state = 'done', updated_at = ? WHERE id = ? AND owner = ?",
            listOf(
                a.appName?.take(255), a.versionName?.take(100), a.installerPackage?.take(255),
                if (a.isUnknownSource) 1 else 0, if (a.isSystemApp) 1 else 0,
                a.dangerousPerms.take(MAX_PERMS).joinToString("\n"), a.permCount.coerceIn(0, 1000),
                if (a.hasOverlay) 1 else 0, a.firstInstallTime, a.localRiskScore.coerceIn(0, 100), clock(), id, owner,
            ),
        ) == 1
    }

    /** The package could not be analysed (for example it is gone): the minimal event will be synced as it is. */
    fun markAnalysisUnavailable(id: String): Boolean = safe(false) {
        val owner = readOwner() ?: return@safe false
        db.exec(
            "UPDATE monitor_events SET analysis_state = 'unavailable', updated_at = ? WHERE id = ? AND owner = ? " +
                "AND analysis_state = 'pending'",
            listOf(clock(), id, owner),
        ) == 1
    }

    /** Events whose analysis never finished (the process died mid-way): `id`, `package_name`, `event_type`. */
    fun stalledAnalysis(limit: Int = MAX_DRAIN): List<Map<String, Any?>> = safe<List<Map<String, Any?>>>(emptyList()) {
        val owner = readOwner() ?: return@safe emptyList<Map<String, Any?>>()
        db.query(
            "SELECT id, package_name, event_type FROM monitor_events WHERE owner = ? AND analysis_state = 'pending' " +
                "AND created_at <= ? ORDER BY occurred_at ASC LIMIT ?",
            listOf(owner, clock() - IN_FLIGHT_ANALYSIS_MS, limit.coerceIn(1, MAX_DRAIN)),
        )
    }

    /**
     * The current owner's events that still need a history sync, oldest first, in the backend's field names (including
     * `client_event_id` and `occurred_at`). Events being analysed right now, and events waiting out a retry delay, are not
     * returned. Reading does not change anything: a repeat drain returns the same events until they are marked.
     */
    fun drain(limit: Int = MAX_DRAIN): List<Map<String, Any?>> = safe<List<Map<String, Any?>>>(emptyList()) {
        val owner = readOwner() ?: return@safe emptyList<Map<String, Any?>>()
        val now = clock()
        db.query(
            "SELECT * FROM monitor_events WHERE owner = ? AND history_state = 'pending' AND next_attempt_at <= ? " +
                "AND (analysis_state <> 'pending' OR created_at <= ?) ORDER BY occurred_at ASC LIMIT ?",
            listOf(owner, now, now - IN_FLIGHT_ANALYSIS_MS, limit.coerceIn(1, MAX_DRAIN)),
        ).map { toPayload(it) }
    }

    /**
     * Applies the backend's per-event outcomes. `history`: created or duplicate (synced), rejected (a permanent no),
     * retry (try again later; spends one attempt). `guardian` is the server's raw status: queued, already, pending, leased
     * (accepted), sent (provider accepted), skipped, expired, none (not sent), failed. An id that is not the current
     * owner's, or an unknown value, is ignored, not applied. When the last attempt is spent the event becomes `failed`
     * (never `synced`), its guardian state becomes `not_sent` (history_failed) and the error code is kept.
     */
    fun markResults(results: List<Result>): MarkSummary = safe(MarkSummary(0, results.size)) {
        val owner = readOwner() ?: return@safe MarkSummary(0, results.size)
        var updated = 0
        var ignored = 0
        db.transaction {
            for (r in results) {
                val id = r.id
                val history = r.history
                if (id == null || history == null || history !in setOf("created", "duplicate", "rejected", "retry")) {
                    ignored++
                    continue
                }
                val row = db.query(
                    "SELECT attempts, history_state FROM monitor_events WHERE id = ? AND owner = ?", listOf(id, owner),
                ).firstOrNull()
                if (row == null) {
                    ignored++
                    continue
                }
                if (row["history_state"] != HISTORY_PENDING) {
                    updated++ // already final: a repeat of the same result is accepted and changes nothing
                    continue
                }
                val now = clock()
                when (history) {
                    "created", "duplicate" ->
                        db.exec(
                            "UPDATE monitor_events SET history_state = ?, guardian_state = ?, guardian_reason = ?, " +
                                "last_error = NULL, updated_at = ? WHERE id = ? AND owner = ? AND history_state = 'pending'",
                            listOf(HISTORY_SYNCED, guardianState(r.guardian), code(r.guardianReason), now, id, owner),
                        )
                    "rejected" ->
                        db.exec(
                            "UPDATE monitor_events SET history_state = ?, guardian_state = ?, guardian_reason = ?, " +
                                "last_error = ?, updated_at = ? WHERE id = ? AND owner = ? AND history_state = 'pending'",
                            listOf(HISTORY_REJECTED, GUARDIAN_NOT_SENT, "history_rejected", code(r.reason) ?: "rejected", now, id, owner),
                        )
                    else -> {
                        val attempts = ((row["attempts"] as? Long) ?: 0L).toInt() + 1
                        val err = code(r.reason) ?: "retry"
                        if (attempts >= MAX_ATTEMPTS) {
                            db.exec(
                                "UPDATE monitor_events SET history_state = ?, guardian_state = ?, guardian_reason = ?, " +
                                    "attempts = ?, last_error = ?, updated_at = ? WHERE id = ? AND owner = ? AND history_state = 'pending'",
                                listOf(HISTORY_FAILED, GUARDIAN_NOT_SENT, "history_failed", attempts, err, now, id, owner),
                            )
                        } else {
                            db.exec(
                                "UPDATE monitor_events SET attempts = ?, last_error = ?, next_attempt_at = ?, updated_at = ? " +
                                    "WHERE id = ? AND owner = ? AND history_state = 'pending'",
                                listOf(attempts, err, now + backoff(attempts), now, id, owner),
                            )
                        }
                    }
                }
                updated++
            }
        }
        MarkSummary(updated, ignored)
    }

    /**
     * Deletes the given owner's events and diagnostics (null = every owner's). The result says whether it really completed:
     * a storage error is `ok = false`, never a silent zero.
     */
    fun purge(owner: String? = null): PurgeResult = try {
        var deleted = 0
        db.transaction {
            if (owner == null) {
                deleted = db.exec("DELETE FROM monitor_events")
                db.exec("DELETE FROM monitor_diag")
            } else {
                deleted = db.exec("DELETE FROM monitor_events WHERE owner = ?", listOf(owner))
                db.exec("DELETE FROM monitor_diag WHERE owner = ?", listOf(owner))
            }
        }
        PurgeResult(true, deleted)
    } catch (_: Throwable) {
        storageErrors++
        PurgeResult(false, 0)
    }

    /** Counts only (never a package, app name or owner id), for the current owner. */
    fun stats(): Map<String, Any?> = safe<Map<String, Any?>>(mapOf("available" to false, "storageErrors" to storageErrors)) {
        val owner = readOwner()
        val out = linkedMapOf<String, Any?>("available" to true, "hasOwner" to (owner != null), "storageErrors" to storageErrors)
        fun count(where: String): Long =
            if (owner == null) 0L
            else db.query("SELECT COUNT(*) AS n FROM monitor_events WHERE owner = ? AND $where", listOf(owner)).first()["n"] as Long
        out["total"] = count("1 = 1")
        out["historyPending"] = count("history_state = 'pending'")
        out["historySynced"] = count("history_state = 'synced'")
        out["historyRejected"] = count("history_state = 'rejected'")
        out["historyFailed"] = count("history_state = 'failed'")
        out["guardianPending"] = count("guardian_state = 'pending'")
        out["guardianAccepted"] = count("guardian_state = 'accepted'")
        out["guardianProviderAccepted"] = count("guardian_state = 'provider_accepted'")
        out["guardianNotSent"] = count("guardian_state = 'not_sent'")
        out["guardianFailed"] = count("guardian_state = 'failed'")
        out["analysisPending"] = count("analysis_state = 'pending'")
        // Why events failed or were rejected: validated codes with counts (no free text).
        val errors = linkedMapOf<String, Long>()
        if (owner != null) {
            db.query(
                "SELECT last_error AS e, COUNT(*) AS n FROM monitor_events WHERE owner = ? AND last_error IS NOT NULL " +
                    "AND history_state IN ('failed', 'rejected') GROUP BY last_error", listOf(owner),
            ).forEach { errors[(it["e"] as String)] = it["n"] as Long }
        }
        out["errorCodes"] = errors
        // Events that retention removed while they were still unsent, failed or rejected (never silent).
        fun lost(kind: String): Long =
            if (owner == null) 0L
            else (db.query("SELECT n FROM monitor_diag WHERE owner = ? AND kind = ?", listOf(owner, kind)).firstOrNull()?.get("n") as Long?) ?: 0L
        out["lostFailed"] = lost("failed")
        out["lostRejected"] = lost("rejected")
        out["lostUnsent"] = lost("unsent")
        val oldest = if (owner == null) null else
            db.query("SELECT MIN(occurred_at) AS t FROM monitor_events WHERE owner = ? AND history_state = 'pending'", listOf(owner)).first()["t"] as Long?
        out["oldestPendingAgeMs"] = oldest?.let { (clock() - it).coerceAtLeast(0) }
        out
    }

    // ---------------------------------------------------------------------------------------------------------------------

    private fun guardianState(g: String?): String = when (g) {
        "queued", "already", "pending", "leased" -> GUARDIAN_ACCEPTED
        "sent" -> GUARDIAN_PROVIDER_ACCEPTED
        "skipped", "expired", "none" -> GUARDIAN_NOT_SENT
        "failed" -> GUARDIAN_FAILED
        else -> GUARDIAN_PENDING
    }

    private fun backoff(attempts: Int): Long =
        minOf(BACKOFF_BASE_MS shl (attempts - 1).coerceIn(0, 20), BACKOFF_MAX_MS)

    /** Deletes the rows matched by [idQuery] after adding the unsent / failed / rejected ones to the owner's diagnostics. */
    private fun deleteCounted(idQuery: String, args: List<Any?>) {
        db.query(
            "SELECT owner AS o, history_state AS s, COUNT(*) AS n FROM monitor_events WHERE id IN ($idQuery) GROUP BY owner, history_state",
            args,
        ).forEach {
            val kind = when (it["s"]) { "failed" -> "failed"; "rejected" -> "rejected"; "pending" -> "unsent"; else -> null } ?: return@forEach
            db.exec("INSERT OR IGNORE INTO monitor_diag (owner, kind, n) VALUES (?, ?, 0)", listOf(it["o"], kind))
            db.exec("UPDATE monitor_diag SET n = n + ? WHERE owner = ? AND kind = ?", listOf(it["n"], it["o"], kind))
        }
        db.exec("DELETE FROM monitor_events WHERE id IN ($idQuery)", args)
    }

    /** Inside the record() transaction: old finished rows and anything beyond the cap go; removals of problem rows are counted. */
    private fun housekeeping(now: Long) {
        deleteCounted("SELECT id FROM monitor_events WHERE created_at < ?", listOf(now - MAX_AGE_MS))
        deleteCounted(
            "SELECT id FROM monitor_events WHERE history_state <> 'pending' AND updated_at < ?", listOf(now - TERMINAL_RETENTION_MS),
        )
        val total = (db.query("SELECT COUNT(*) AS n FROM monitor_events").first()["n"] as Long).toInt()
        if (total >= MAX_ROWS) {
            deleteCounted(
                "SELECT id FROM monitor_events ORDER BY (history_state = 'pending') ASC, occurred_at ASC LIMIT ?",
                listOf(total - MAX_ROWS + 1),
            )
        }
    }

    private fun toPayload(r: Map<String, Any?>): Map<String, Any?> {
        val pkg = r["package_name"] as String
        val perms = (r["dangerous_perms"] as String?)?.split('\n')?.filter { it.isNotEmpty() } ?: emptyList()
        return linkedMapOf(
            "client_event_id" to r["id"],
            "occurred_at" to r["occurred_at"],
            "client_timestamp" to r["occurred_at"],
            "package_name" to pkg,
            "app_name" to ((r["app_name"] as String?)?.takeIf { it.isNotEmpty() } ?: pkg),
            "event_type" to r["event_type"],
            "version_name" to r["version_name"],
            "installer_package" to r["installer_package"],
            "is_unknown_source" to (r["is_unknown_source"] == 1L),
            "is_system_app" to (r["is_system_app"] == 1L),
            "dangerous_perms" to perms,
            "perm_count" to r["perm_count"],
            "local_risk_score" to r["local_risk_score"],
            "has_overlay" to (r["has_overlay"] == 1L),
            "first_install_time" to r["first_install_time"],
        )
    }
}
