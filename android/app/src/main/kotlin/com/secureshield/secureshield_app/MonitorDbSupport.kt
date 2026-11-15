package com.secureshield.secureshield_app

/**
 * Android-free database safety rules for the monitor event store (unit-tested on the JVM).
 *
 * The one rule: queued events are only ever destroyed when Android CONFIRMS the file is corrupt. Disk-full, locked,
 * permission, read-only and any other error leaves the file alone and fails just that call.
 */
object DbRecoveryPolicy {
    /** Android's confirmation of corruption (SQLite NOTADB / CORRUPT are both reported as this class). */
    val CORRUPTION_CLASSES = setOf("android.database.sqlite.SQLiteDatabaseCorruptException")

    /** True if [t], one of its causes, or one of their superclasses is a confirmed-corruption exception. */
    fun isCorruption(t: Throwable, classes: Set<String> = CORRUPTION_CLASSES): Boolean {
        var cur: Throwable? = t
        var depth = 0
        while (cur != null && depth < 8) {
            var c: Class<*>? = cur.javaClass
            while (c != null) {
                if (c.name in classes) return true
                c = c.superclass
            }
            cur = cur.cause
            depth++
        }
        return false
    }
}

/**
 * Wraps a database so that a confirmed corruption (and only that) deletes and recreates the file, counts the recovery
 * outside the database, and retries the failed call once on the fresh file. Every other failure propagates unchanged and
 * leaves the file and its events untouched.
 */
class RecoveringSqlDb(
    private val open: () -> SqlDb,
    private val close: () -> Unit,
    private val recreate: () -> Unit,
    private val onCorruptionRecovered: () -> Unit,
    private val isCorruption: (Throwable) -> Boolean = { DbRecoveryPolicy.isCorruption(it) },
) : SqlDb {
    private var cur: SqlDb? = null
    private val lock = Any()

    private fun db(): SqlDb = synchronized(lock) { cur ?: open().also { cur = it } }

    private fun <T> guard(block: (SqlDb) -> T): T {
        try {
            return block(db())
        } catch (t: Throwable) {
            if (!isCorruption(t)) throw t // transient or environmental: the file and its events stay as they are
            recover()
        }
        return block(db()) // once, on the new empty file; a failure here propagates
    }

    private fun recover() = synchronized(lock) {
        cur = null
        try { close() } catch (_: Throwable) {}
        recreate()
        onCorruptionRecovered()
    }

    override fun exec(sql: String, args: List<Any?>): Int = guard { it.exec(sql, args) }
    override fun query(sql: String, args: List<Any?>): List<Map<String, Any?>> = guard { it.query(sql, args) }
    override fun <T> transaction(block: () -> T): T = guard { it.transaction(block) }
}

/** Schema moves. Additive only, idempotent, and safe to repeat after a failed or interrupted attempt. */
object MonitorSchema {
    /**
     * v1 -> v2: adds the two nullable columns and the diagnostics table. Columns that already exist are skipped (an earlier
     * partial upgrade, or a downgrade followed by a new upgrade), so running it again can never fail on "duplicate column".
     * If the table is missing entirely the full schema is created instead. Runs inside the caller's transaction: if any
     * statement fails, nothing it did is kept and the existing events are untouched.
     */
    fun upgradeV1ToV2(db: SqlDb) {
        val have = db.query("PRAGMA table_info(monitor_events)").mapNotNull { it["name"] as? String }.toSet()
        if (have.isEmpty()) {
            MonitorEventStore.SCHEMA.forEach { db.exec(it) }
            return
        }
        for ((name, type) in MonitorEventStore.V2_COLUMNS) {
            if (name !in have) db.exec("ALTER TABLE monitor_events ADD COLUMN $name $type")
        }
        db.exec(MonitorEventStore.DIAG_TABLE)
    }

    /**
     * Downgrade is a deliberate no-op. Version 2 only ADDED nullable columns and a table, so older code keeps working on
     * the same file (it names its columns explicitly and ignores the extras), and the events are never erased on rollback.
     */
    fun onDowngrade() {}
}
