package com.secureshield.secureshield_app

import android.content.Context
import android.database.DatabaseErrorHandler
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.io.File

/** [SqlDb] over one open Android database. Transactions here are real; nesting is not supported (the store never nests). */
class RawSql(private val db: SQLiteDatabase) : SqlDb {
    override fun exec(sql: String, args: List<Any?>): Int {
        val st = db.compileStatement(sql)
        try {
            args.forEachIndexed { i, a ->
                when (a) {
                    null -> st.bindNull(i + 1)
                    is Long -> st.bindLong(i + 1, a)
                    is Int -> st.bindLong(i + 1, a.toLong())
                    is String -> st.bindString(i + 1, a)
                    else -> throw IllegalArgumentException("unsupported bind type")
                }
            }
            return st.executeUpdateDelete()
        } finally {
            st.close()
        }
    }

    override fun query(sql: String, args: List<Any?>): List<Map<String, Any?>> {
        val c = db.rawQuery(sql, args.map { it?.toString() }.toTypedArray())
        try {
            val rows = ArrayList<Map<String, Any?>>()
            while (c.moveToNext()) {
                val row = LinkedHashMap<String, Any?>()
                for (i in 0 until c.columnCount) {
                    row[c.getColumnName(i)] = when (c.getType(i)) {
                        android.database.Cursor.FIELD_TYPE_NULL -> null
                        android.database.Cursor.FIELD_TYPE_INTEGER -> c.getLong(i)
                        else -> c.getString(i)
                    }
                }
                rows.add(row)
            }
            return rows
        } finally {
            c.close()
        }
    }

    override fun <T> transaction(block: () -> T): T {
        db.beginTransaction()
        try {
            val out = block()
            db.setTransactionSuccessful()
            return out
        } finally {
            db.endTransaction()
        }
    }
}

/**
 * Android SQLite behind [SqlDb]. The file lives in noBackupFilesDir, so it is never copied into a device backup.
 *
 * Safety rules (see [DbRecoveryPolicy], [RecoveringSqlDb], [MonitorSchema]):
 *  • The file is deleted ONLY when Android confirms corruption; each such recovery is counted in SharedPreferences, outside
 *    the database, so the loss is never invisible. Disk-full, locked, permission and read-only errors never delete anything.
 *  • The v1 -> v2 upgrade is idempotent and transactional: if it fails, the events are untouched and it is retried next open.
 *  • A downgrade (older app over a newer one) is a no-op, so rolling back never erases queued events.
 */
class AndroidSqlDb(context: Context, private val file: File) : SqlDb {
    companion object {
        const val DIAG_PREFS = "secureshield_monitor_diag"
        const val KEY_RECOVERIES = "db_recovered"

        /** How many times a confirmed-corrupt database had to be recreated (counted outside the database). */
        fun recoveries(ctx: Context): Int = try {
            ctx.applicationContext.getSharedPreferences(DIAG_PREFS, Context.MODE_PRIVATE).getInt(KEY_RECOVERIES, 0)
        } catch (_: Throwable) {
            0
        }
    }

    private val app = context.applicationContext

    // The default handler deletes the file on ANY corruption report; deletion is decided by RecoveringSqlDb instead.
    private val helper = object : SQLiteOpenHelper(
        app, file.path, null, MonitorEventStore.DB_VERSION, DatabaseErrorHandler { /* no automatic deletion */ },
    ) {
        override fun onCreate(db: SQLiteDatabase) {
            MonitorEventStore.SCHEMA.forEach { db.execSQL(it) }
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            if (oldVersion < 2) MonitorSchema.upgradeV1ToV2(RawSql(db))
        }

        override fun onDowngrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
            MonitorSchema.onDowngrade() // never throw, never drop: an additive schema stays usable by older code
        }
    }

    private val inner = RecoveringSqlDb(
        open = { RawSql(helper.writableDatabase) },
        close = { helper.close() },
        recreate = { SQLiteDatabase.deleteDatabase(file) },
        onCorruptionRecovered = {
            try {
                val p = app.getSharedPreferences(DIAG_PREFS, Context.MODE_PRIVATE)
                p.edit().putInt(KEY_RECOVERIES, p.getInt(KEY_RECOVERIES, 0) + 1).commit()
            } catch (_: Throwable) {
            }
        },
    )

    @Synchronized
    override fun exec(sql: String, args: List<Any?>): Int = inner.exec(sql, args)

    @Synchronized
    override fun query(sql: String, args: List<Any?>): List<Map<String, Any?>> = inner.query(sql, args)

    @Synchronized
    override fun <T> transaction(block: () -> T): T = inner.transaction(block)
}

/** The process-wide store. Opened lazily; the helpers below never throw. */
object MonitorEvents {
    @Volatile
    private var store: MonitorEventStore? = null

    fun get(ctx: Context): MonitorEventStore {
        store?.let { return it }
        synchronized(this) {
            store?.let { return it }
            val file = File(ctx.applicationContext.noBackupFilesDir, "secureshield_monitor_events.db")
            val s = MonitorEventStore(AndroidSqlDb(ctx, file))
            s.init()
            store = s
            return s
        }
    }

    fun dbRecoveries(ctx: Context): Int = AndroidSqlDb.recoveries(ctx)

    /**
     * Stores the event BEFORE any analysis or notification. Returns the event id, or null when nothing was stored (no
     * signed-in account, a duplicate, or a storage error); the caller carries on with local protection either way.
     */
    fun recordFirst(ctx: Context, packageName: String, eventType: String): String? = try {
        (get(ctx).record(packageName, eventType) as? MonitorEventStore.Recorded.New)?.id
    } catch (_: Throwable) {
        null
    }

    fun attach(ctx: Context, id: String?, r: AppInstallAnalyzer.AnalysisResult) {
        if (id == null) return
        try {
            get(ctx).attachAnalysis(
                id,
                MonitorEventStore.Analysis(
                    r.appName, r.versionName, r.installerPackage, r.isUnknownSource, r.isSystemApp, r.dangerousPerms,
                    r.permCount, r.hasOverlay, r.firstInstallTime, r.localRiskScore,
                ),
            )
        } catch (_: Throwable) {
        }
    }

    /** Re-runs the analysis for events whose analysis was cut short (process death); the rest go out as minimal events. */
    fun recoverStalled(ctx: Context) {
        try {
            val s = get(ctx)
            for (row in s.stalledAnalysis()) {
                val id = row["id"] as String
                val r = if (row["event_type"] == "removed") null
                else AppInstallAnalyzer.analyze(ctx, row["package_name"] as String, row["event_type"] as String)
                if (r != null) attach(ctx, id, r) else s.markAnalysisUnavailable(id)
            }
        } catch (_: Throwable) {
        }
    }
}
