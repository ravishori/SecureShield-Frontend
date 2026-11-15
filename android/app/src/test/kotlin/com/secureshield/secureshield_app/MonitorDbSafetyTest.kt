package com.secureshield.secureshield_app

import java.io.File
import java.io.IOException
import java.sql.SQLException
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

/** Stands in for android.database.sqlite.SQLiteDatabaseCorruptException (the Android stub cannot be built on the JVM). */
open class TestCorruption(msg: String) : RuntimeException(msg)
class TestCorruptionSubclass(msg: String) : TestCorruption(msg)

/** F3/F4: the database is only ever deleted on confirmed corruption; upgrades are safe to retry; downgrade never erases. */
class MonitorDbSafetyTest {
    private lateinit var file: File
    private var current: JdbcSqlDb? = null
    private var recreated = 0
    private var recoveries = 0 // the counter that lives OUTSIDE the database
    private var now = 1_000_000_000_000L
    private var seq = 0
    private lateinit var db: RecoveringSqlDb
    private lateinit var store: MonitorEventStore

    private val corrupt = { t: Throwable -> DbRecoveryPolicy.isCorruption(t, setOf(TestCorruption::class.java.name)) }
    private val analysis = MonitorEventStore.Analysis("App", "1", null, false, false, emptyList(), 1, false, 1L, 10)

    @Before
    fun setUp() {
        file = File.createTempFile("safety_db", ".db").also { it.deleteOnExit() }
        db = RecoveringSqlDb(
            open = { JdbcSqlDb(file).also { d -> MonitorEventStore.SCHEMA.forEach { d.exec(it) }; current = d } },
            close = { current?.close() },
            recreate = { file.delete(); recreated++ },
            onCorruptionRecovered = { recoveries++ },
            isCorruption = corrupt,
        )
        store = MonitorEventStore(db, clock = { now }, newId = { "00000000-0000-4000-8000-%012d".format(++seq) })
        assertTrue(store.init())
        assertTrue(store.setOwner("user-a"))
    }

    @After
    fun tearDown() {
        try { current?.close() } catch (_: Throwable) {}
        file.delete()
    }

    private fun addEvents(n: Int): List<String> = (1..n).map {
        val id = (store.record("com.p$it", "installed", now + it * 20_000L) as MonitorEventStore.Recorded.New).id
        store.attachAnalysis(id, analysis)
        id
    }

    private fun rowCount(): Long = JdbcSqlDb(file).use { it.query("SELECT COUNT(*) AS n FROM monitor_events").first()["n"] as Long }

    private fun <T> JdbcSqlDb.use(block: (JdbcSqlDb) -> T): T = try { block(this) } finally { close() }

    // ------------------------------------------------------------------------------------------------ the policy
    @Test
    fun only_confirmed_corruption_is_corruption() {
        assertTrue(corrupt(TestCorruption("file is not a database")))
        assertTrue(corrupt(TestCorruptionSubclass("malformed")))
        assertTrue(corrupt(RuntimeException("wrapped", TestCorruption("inner")))) // found through the cause chain
        listOf(
            SQLException("database or disk is full"), SQLException("database is locked"), SQLException("attempt to write a readonly database"),
            IOException("unable to open database file"), SecurityException("permission denied"), IllegalStateException("x"),
        ).forEach { assertFalse(it.message, corrupt(it)) }
    }

    @Test
    fun the_default_policy_names_androids_corruption_exception() {
        assertTrue("android.database.sqlite.SQLiteDatabaseCorruptException" in DbRecoveryPolicy.CORRUPTION_CLASSES)
    }

    // ------------------------------------------------------------------------------------------------ F3: transient errors keep the data
    @Test
    fun transient_database_errors_never_delete_or_lose_existing_records() {
        addEvents(3)
        val errors = listOf(
            SQLException("database or disk is full"), // disk full
            SQLException("database is locked"), // locked
            SQLException("attempt to write a readonly database"), // read-only
            IOException("unable to open database file"), // cannot open
            SecurityException("permission denied"), // permission
        )
        for (e in errors) {
            current!!.failWith = e
            assertTrue(store.drain().isEmpty()) // the call fails safely ...
            assertEquals(MonitorEventStore.Recorded.Failed, store.record("com.new", "installed", now + 999_000))
            current!!.failWith = null
            assertEquals("${e.message}: the file must not be touched", 0, recreated)
            assertEquals(0, recoveries)
            assertTrue(file.exists())
            assertEquals("${e.message}: the events are still there", 3, store.drain().size)
        }
        assertEquals(3L, rowCount())
    }

    @Test
    fun a_transient_error_during_a_transaction_rolls_back_and_keeps_earlier_records() {
        addEvents(2)
        current!!.failWith = SQLException("database or disk is full")
        assertFalse(store.markResults(listOf(MonitorEventStore.Result("x", "created", "queued"))).updated > 0)
        current!!.failWith = null
        assertEquals(2L, rowCount())
        assertEquals(0, recreated)
    }

    // ------------------------------------------------------------------------------------------------ F3: confirmed corruption recovers once, visibly
    @Test
    fun confirmed_corruption_recreates_the_database_counts_it_outside_the_database_and_keeps_working() {
        addEvents(3)
        current!!.failWith = TestCorruption("file is not a database")
        // the call that met the corruption is retried once on the fresh file: it succeeds there, but the owner lived in the
        // corrupt file and is gone, so the event is (correctly) not attributed to anyone
        assertEquals(MonitorEventStore.Recorded.NoOwner, store.record("com.after", "installed", now + 5_000_000))
        assertEquals(1, recreated)
        assertEquals(1, recoveries) // counted outside the database: it survives the recreate
        // the owner lived in the corrupt file: it is gone, so nothing is attributed until the app sets it again
        assertNull(store.currentOwner())
        assertTrue(store.setOwner("user-a"))
        assertTrue(store.record("com.fresh", "installed", now + 9_000_000) is MonitorEventStore.Recorded.New)
        assertEquals(1, recreated) // and it is not recreated again
    }

    @Test
    fun a_second_failure_after_recovery_propagates_instead_of_looping() {
        var opens = 0
        val d = RecoveringSqlDb(
            open = { opens++; throw TestCorruption("always corrupt") },
            close = {}, recreate = { recreated++ }, onCorruptionRecovered = { recoveries++ }, isCorruption = corrupt,
        )
        try {
            d.query("SELECT 1")
            fail("expected the second corruption to propagate")
        } catch (e: TestCorruption) {
            // propagated
        }
        assertEquals(1, recoveries) // one recovery, not an endless delete loop
        assertEquals(2, opens)
    }

    // ------------------------------------------------------------------------------------------------ F3: failed upgrades keep the data
    private class FailingAfter(private val inner: SqlDb, private val allowed: Int) : SqlDb {
        private var n = 0
        override fun exec(sql: String, args: List<Any?>): Int {
            if (++n > allowed) throw SQLException("simulated failure mid-upgrade")
            return inner.exec(sql, args)
        }
        override fun query(sql: String, args: List<Any?>) = inner.query(sql, args)
        override fun <T> transaction(block: () -> T): T = inner.transaction(block)
    }

    private fun v1Database(): JdbcSqlDb {
        val f = File.createTempFile("v1_schema", ".db").also { it.deleteOnExit() }
        val d = JdbcSqlDb(f)
        d.exec("""CREATE TABLE monitor_events (id TEXT PRIMARY KEY NOT NULL, owner TEXT NOT NULL, occurred_at INTEGER NOT NULL,
            package_name TEXT NOT NULL, event_type TEXT NOT NULL, app_name TEXT, version_name TEXT, installer_package TEXT,
            is_unknown_source INTEGER NOT NULL DEFAULT 0, is_system_app INTEGER NOT NULL DEFAULT 0, dangerous_perms TEXT,
            perm_count INTEGER NOT NULL DEFAULT 0, has_overlay INTEGER NOT NULL DEFAULT 0, first_install_time INTEGER,
            local_risk_score INTEGER NOT NULL DEFAULT 0, analysis_state TEXT NOT NULL DEFAULT 'pending',
            history_state TEXT NOT NULL DEFAULT 'pending', guardian_state TEXT NOT NULL DEFAULT 'pending',
            attempts INTEGER NOT NULL DEFAULT 0, next_attempt_at INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL)""")
        d.exec("CREATE TABLE monitor_meta (k TEXT PRIMARY KEY NOT NULL, v TEXT)")
        d.exec("INSERT INTO monitor_meta VALUES ('owner', 'user-a')")
        repeat(3) { i ->
            d.exec("INSERT INTO monitor_events (id, owner, occurred_at, package_name, event_type, analysis_state, created_at, updated_at) VALUES (?, 'user-a', ?, ?, 'installed', 'done', 1, 1)",
                listOf("ev$i", 1000L + i, "pkg$i"))
        }
        return d
    }

    private fun columns(d: SqlDb) = d.query("PRAGMA table_info(monitor_events)").map { it["name"] as String }
    private fun count(d: SqlDb) = d.query("SELECT COUNT(*) AS n FROM monitor_events").first()["n"] as Long

    @Test
    fun a_failed_upgrade_rolls_back_leaves_every_event_and_can_simply_be_run_again() {
        val d = v1Database()
        try {
            d.transaction { MonitorSchema.upgradeV1ToV2(FailingAfter(d, 1)) } // first ALTER succeeds, the next statement fails
            fail("the simulated failure should propagate")
        } catch (_: SQLException) {
        }
        assertFalse("guardian_reason" in columns(d)) // the half-done work was rolled back
        assertEquals(3L, count(d))
        d.transaction { MonitorSchema.upgradeV1ToV2(d) } // the retry (next app start) completes it
        assertTrue("guardian_reason" in columns(d) && "last_error" in columns(d))
        assertEquals(3L, count(d))
        d.close()
    }

    @Test
    fun the_upgrade_is_idempotent_so_existing_columns_never_cause_a_duplicate_column_failure() {
        val d = v1Database()
        d.transaction { MonitorSchema.upgradeV1ToV2(d) }
        d.transaction { MonitorSchema.upgradeV1ToV2(d) } // a partial earlier upgrade, or downgrade-then-upgrade
        d.transaction { MonitorSchema.upgradeV1ToV2(d) }
        assertEquals(3L, count(d))
        assertEquals(1, columns(d).count { it == "last_error" })
        d.close()
    }

    @Test
    fun an_upgrade_of_a_database_with_no_table_creates_the_schema_instead_of_failing() {
        val f = File.createTempFile("empty_db", ".db").also { it.deleteOnExit() }
        val d = JdbcSqlDb(f)
        d.transaction { MonitorSchema.upgradeV1ToV2(d) }
        assertTrue("last_error" in columns(d))
        d.close()
    }

    // ------------------------------------------------------------------------------------------------ F4: downgrade is safe
    @Test
    fun a_rolled_back_older_build_keeps_working_on_the_v2_file_without_erasing_anything() {
        val d = v1Database()
        d.transaction { MonitorSchema.upgradeV1ToV2(d) }
        d.exec("UPDATE monitor_events SET guardian_reason = 'not_authorised', last_error = 'http_422' WHERE id = 'ev0'")
        MonitorSchema.onDowngrade() // must not throw and must not touch anything
        assertEquals(3L, count(d))
        // Statements exactly as the v1 (Stage 2B) code issues them: named columns only, extras are ignored
        d.exec("INSERT OR IGNORE INTO monitor_events (id, owner, occurred_at, package_name, event_type, created_at, updated_at) VALUES ('old', 'user-a', 5, 'p', 'installed', 1, 1)")
        d.exec("UPDATE monitor_events SET history_state = 'synced', guardian_state = 'delivered', updated_at = 2 WHERE id = 'old' AND owner = 'user-a'")
        val rows = d.query("SELECT * FROM monitor_events WHERE owner = 'user-a' AND history_state = 'pending' ORDER BY occurred_at ASC LIMIT 50")
        assertEquals(3, rows.size)
        assertEquals(4L, count(d))
        d.exec("INSERT OR REPLACE INTO monitor_meta (k, v) VALUES ('owner', 'user-a')")
        // and upgrading again later still works and keeps what the older build wrote
        d.transaction { MonitorSchema.upgradeV1ToV2(d) }
        assertEquals(4L, count(d))
        assertEquals("not_authorised", d.query("SELECT guardian_reason AS r FROM monitor_events WHERE id = 'ev0'").first()["r"])
        d.close()
    }

    @Test
    fun the_v2_schema_only_adds_nullable_things_which_is_what_makes_the_no_op_downgrade_safe() {
        val d = v1Database()
        val before = columns(d)
        d.transaction { MonitorSchema.upgradeV1ToV2(d) }
        val added = columns(d) - before.toSet()
        assertEquals(listOf("guardian_reason", "last_error"), added)
        val info = d.query("PRAGMA table_info(monitor_events)").filter { it["name"] in added }
        assertTrue(info.all { it["notnull"] == 0L && it["dflt_value"] == null }) // nullable, no default needed by old inserts
        d.close()
    }

    // ------------------------------------------------------------------------------------------------ the Android glue obeys the rules
    private fun androidSource(name: String): String {
        val f = File("src/main/kotlin/com/secureshield/secureshield_app/$name").takeIf { it.exists() }
            ?: File("app/src/main/kotlin/com/secureshield/secureshield_app/$name")
        return f.readText()
    }

    @Test
    fun the_android_helper_overrides_downgrade_replaces_the_deleting_error_handler_and_deletes_only_in_recreate() {
        val src = androidSource("AndroidSqlDb.kt")
        assertTrue(Regex("""override fun onDowngrade""").containsMatchIn(src))
        assertTrue(src.contains("DatabaseErrorHandler {")) // the default handler would delete on any corruption report
        assertEquals(1, Regex("""deleteDatabase\(""").findAll(src).count()) // one place: the confirmed-corruption recreate
        assertTrue(Regex("""recreate\s*=\s*\{\s*SQLiteDatabase\.deleteDatabase""").containsMatchIn(src))
        assertFalse(src.contains("catch (_: Throwable) {\n        try { helper.close() }")) // the old catch-all recovery is gone
        assertTrue(src.contains("KEY_RECOVERIES")) // the counter is outside the database (SharedPreferences)
    }
}
