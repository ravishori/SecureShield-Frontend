package com.secureshield.secureshield_app

import java.io.File
import java.sql.Connection
import java.sql.DriverManager
import java.sql.Types
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** SqlDb over real SQLite (sqlite-jdbc), so these tests exercise the actual SQL the app runs. */
class JdbcSqlDb(file: File) : SqlDb {
    private val conn: Connection = DriverManager.getConnection("jdbc:sqlite:${file.path}")
    var failNext = false
    var failWith: Throwable? = null // a specific error to raise on every call until cleared

    private fun check() {
        failWith?.let { throw it }
        if (failNext) {
            failNext = false
            throw java.sql.SQLException("simulated storage error")
        }
    }

    private fun bind(st: java.sql.PreparedStatement, args: List<Any?>) {
        args.forEachIndexed { i, a ->
            when (a) {
                null -> st.setNull(i + 1, Types.NULL)
                is Int -> st.setLong(i + 1, a.toLong())
                is Long -> st.setLong(i + 1, a)
                is String -> st.setString(i + 1, a)
                else -> error("bind type")
            }
        }
    }

    override fun exec(sql: String, args: List<Any?>): Int {
        check()
        conn.prepareStatement(sql).use { bind(it, args); return it.executeUpdate() }
    }

    override fun query(sql: String, args: List<Any?>): List<Map<String, Any?>> {
        check()
        conn.prepareStatement(sql).use { st ->
            bind(st, args)
            st.executeQuery().use { rs ->
                val out = ArrayList<Map<String, Any?>>()
                val md = rs.metaData
                while (rs.next()) {
                    val row = LinkedHashMap<String, Any?>()
                    for (i in 1..md.columnCount) {
                        row[md.getColumnLabel(i)] = when (md.getColumnType(i)) {
                            Types.INTEGER, Types.BIGINT, Types.SMALLINT -> if (rs.getObject(i) == null) null else rs.getLong(i)
                            else -> rs.getObject(i)?.let { v -> if (v is Number && v !is Long) v.toLong() else v }
                        }
                    }
                    out.add(row)
                }
                return out
            }
        }
    }

    override fun <T> transaction(block: () -> T): T {
        conn.autoCommit = false
        try {
            val out = block()
            conn.commit()
            return out
        } catch (t: Throwable) {
            conn.rollback()
            throw t
        } finally {
            conn.autoCommit = true
        }
    }

    fun close() = conn.close()
}

class MonitorEventStoreTest {
    private lateinit var file: File
    private lateinit var db: JdbcSqlDb
    private var now = 1_000_000_000_000L
    private var seq = 0
    private lateinit var store: MonitorEventStore

    private fun newStore(d: JdbcSqlDb) = MonitorEventStore(d, clock = { now }, newId = { "00000000-0000-4000-8000-%012d".format(++seq) })

    @Before
    fun setUp() {
        file = File.createTempFile("events", ".db").also { it.deleteOnExit() }
        db = JdbcSqlDb(file)
        store = newStore(db)
        assertTrue(store.init())
        assertTrue(store.setOwner("user-a"))
    }

    @After
    fun tearDown() {
        db.close()
        file.delete()
    }

    private val analysis = MonitorEventStore.Analysis("Risky", "1.2", "com.android.vending", false, false, listOf("SEND_SMS"), 7, true, 123L, 55)

    private fun recorded(pkg: String, type: String = "installed", at: Long = now): String =
        (store.record(pkg, type, at) as MonitorEventStore.Recorded.New).id

    // ------------------------------------------------------------------------------------------------ persistence
    @Test
    fun an_event_is_stored_before_analysis_and_can_be_drained_with_the_backend_field_names() {
        val id = recorded("com.x")
        now += MonitorEventStore.IN_FLIGHT_ANALYSIS_MS + 1 // analysis never finished: the minimal event is still delivered
        val e = store.drain().single()
        assertEquals(id, e["client_event_id"])
        assertEquals(1_000_000_000_000L, e["occurred_at"])
        assertEquals("com.x", e["package_name"])
        assertEquals("com.x", e["app_name"]) // the backend requires a non-empty name
        assertEquals("installed", e["event_type"])
    }

    @Test
    fun an_event_being_analysed_right_now_is_not_drained_until_the_analysis_lands() {
        val id = recorded("com.x")
        assertTrue(store.drain().isEmpty())
        assertTrue(store.attachAnalysis(id, analysis))
        val e = store.drain().single()
        assertEquals("Risky", e["app_name"])
        assertEquals(55L, e["local_risk_score"])
        assertEquals(listOf("SEND_SMS"), e["dangerous_perms"])
        assertEquals(true, e["has_overlay"])
    }

    @Test
    fun events_survive_the_process_dying_and_the_database_being_reopened() {
        val id = recorded("com.x")
        store.attachAnalysis(id, analysis)
        db.close() // process death
        val db2 = JdbcSqlDb(file)
        val store2 = newStore(db2)
        store2.init()
        assertEquals("user-a", store2.currentOwner())
        assertEquals(id, store2.drain().single()["client_event_id"])
        db2.close()
        db = JdbcSqlDb(file) // for tearDown
    }

    @Test
    fun draining_does_not_change_anything_so_a_crash_before_marking_loses_nothing() {
        store.attachAnalysis(recorded("com.x"), analysis)
        assertEquals(store.drain().map { it["client_event_id"] }, store.drain().map { it["client_event_id"] })
        assertEquals(1, store.drain().size)
    }

    @Test
    fun a_stalled_analysis_is_found_after_a_restart_and_can_be_finished_or_given_up() {
        val a = recorded("com.a")
        val b = recorded("com.b", at = now + 20_000)
        assertTrue(store.stalledAnalysis().isEmpty()) // still within the in-flight window
        now += MonitorEventStore.IN_FLIGHT_ANALYSIS_MS + 1
        assertEquals(setOf(a, b), store.stalledAnalysis().map { it["id"] }.toSet())
        assertTrue(store.attachAnalysis(a, analysis))
        assertTrue(store.markAnalysisUnavailable(b))
        assertTrue(store.stalledAnalysis().isEmpty())
        assertEquals(2, store.drain().size)
    }

    // ------------------------------------------------------------------------------------------------ deduplication
    @Test
    fun the_same_package_event_within_the_window_is_a_duplicate_and_stores_one_row() {
        val first = store.record("com.x", "installed", now) as MonitorEventStore.Recorded.New
        val again = store.record("com.x", "installed", now + 3_000)
        assertEquals(MonitorEventStore.Recorded.Duplicate(first.id), again)
        assertEquals(1L, store.stats()["total"])
    }

    @Test
    fun a_different_type_package_or_a_later_event_is_a_new_event() {
        recorded("com.x")
        assertTrue(store.record("com.x", "updated", now) is MonitorEventStore.Recorded.New)
        assertTrue(store.record("com.y", "installed", now) is MonitorEventStore.Recorded.New)
        assertTrue(store.record("com.x", "installed", now + MonitorEventStore.DEDUPE_WINDOW_MS + 1) is MonitorEventStore.Recorded.New)
    }

    @Test
    fun a_repeated_marked_result_is_accepted_without_changing_the_state() {
        val id = recorded("com.x")
        store.attachAnalysis(id, analysis)
        store.markResults(listOf(MonitorEventStore.Result(id, "created", "queued")))
        val again = store.markResults(listOf(MonitorEventStore.Result(id, "retry", null)))
        assertEquals(1, again.updated) // already synced: the late retry cannot reopen it
        assertEquals(1L, store.stats()["historySynced"])
        assertEquals(0L, store.stats()["historyPending"])
    }

    // ------------------------------------------------------------------------------------------------ separate states
    @Test
    fun history_and_guardian_states_are_tracked_independently() {
        val a = recorded("com.a"); val b = recorded("com.b", at = now + 20_000); val c = recorded("com.c", at = now + 40_000)
        listOf(a, b, c).forEach { store.attachAnalysis(it, analysis) }
        store.markResults(
            listOf(
                MonitorEventStore.Result(a, "created", "queued"), // synced, alert queued at the server
                MonitorEventStore.Result(b, "duplicate", "skipped"), // synced, no alert
                MonitorEventStore.Result(c, "created", null), // synced, guardian outcome unknown: still pending
            ),
        )
        val s = store.stats()
        assertEquals(3L, s["historySynced"]); assertEquals(1L, s["guardianAccepted"]) // "queued" is accepted, NOT delivered
        assertEquals(1L, s["guardianNotSent"]); assertEquals(1L, s["guardianPending"])
        assertEquals(0L, s["guardianProviderAccepted"])
        assertTrue(store.drain().isEmpty())
    }

    @Test
    fun a_rejected_event_is_final_and_never_resent() {
        val id = recorded("com.x"); store.attachAnalysis(id, analysis)
        store.markResults(listOf(MonitorEventStore.Result(id, "rejected", null)))
        assertTrue(store.drain().isEmpty())
        assertEquals(1L, store.stats()["historyRejected"]); assertEquals(1L, store.stats()["guardianNotSent"])
    }

    // ------------------------------------------------------------------------------------------------ partial failures / retry
    @Test
    fun a_retry_result_backs_off_then_becomes_drainable_again() {
        val id = recorded("com.x"); store.attachAnalysis(id, analysis)
        store.markResults(listOf(MonitorEventStore.Result(id, "retry", null)))
        assertTrue(store.drain().isEmpty()) // waiting out the delay
        now += 30_001
        assertEquals(1, store.drain().size)
    }

    @Test
    fun an_event_that_keeps_failing_is_given_up_after_the_attempt_limit() {
        val id = recorded("com.x"); store.attachAnalysis(id, analysis)
        repeat(MonitorEventStore.MAX_ATTEMPTS) {
            now += 4_000_000
            store.markResults(listOf(MonitorEventStore.Result(id, "retry", null)))
        }
        assertEquals(1L, store.stats()["historyFailed"])
        now += 4_000_000
        assertTrue(store.drain().isEmpty())
    }

    @Test
    fun a_batch_with_good_and_bad_results_applies_the_good_ones_and_counts_the_rest() {
        val id = recorded("com.x"); store.attachAnalysis(id, analysis)
        val r = store.markResults(
            listOf(
                MonitorEventStore.Result(id, "created", "sent"),
                MonitorEventStore.Result("not-an-id", "created", null),
                MonitorEventStore.Result(id, "weird", null),
                MonitorEventStore.Result(null, "created", null),
            ),
        )
        assertEquals(1, r.updated); assertEquals(3, r.ignored)
    }

    @Test
    fun drain_is_oldest_first_and_capped_at_the_batch_limit() {
        repeat(60) { i -> store.attachAnalysis(recorded("com.p$i", at = now + i * 20_000L), analysis) }
        val batch = store.drain(500)
        assertEquals(MonitorEventStore.MAX_DRAIN, batch.size)
        assertEquals((batch.map { it["occurred_at"] as Long }).sorted(), batch.map { it["occurred_at"] as Long })
        assertEquals("com.p0", batch.first()["package_name"])
    }

    // ------------------------------------------------------------------------------------------------ account isolation
    @Test
    fun nothing_is_stored_and_nothing_is_returned_while_signed_out() {
        store.setOwner(null)
        assertEquals(MonitorEventStore.Recorded.NoOwner, store.record("com.x", "installed", now))
        assertTrue(store.drain().isEmpty())
        assertEquals(0, store.markResults(listOf(MonitorEventStore.Result("x", "created", null))).updated)
        assertEquals(false, store.stats()["hasOwner"])
    }

    @Test
    fun switching_accounts_removes_the_previous_accounts_events_and_the_new_one_sees_none() {
        store.attachAnalysis(recorded("com.secret"), analysis)
        assertTrue(store.setOwner("user-b"))
        assertTrue(store.drain().isEmpty())
        assertEquals(0L, store.stats()["total"])
        assertEquals(0L, db.query("SELECT COUNT(*) AS n FROM monitor_events").first()["n"]) // physically gone, not just hidden
        store.setOwner("user-a")
        assertTrue(store.drain().isEmpty())
    }

    @Test
    fun re_setting_the_same_account_keeps_its_events() {
        store.attachAnalysis(recorded("com.x"), analysis)
        assertTrue(store.setOwner("user-a"))
        assertEquals(1, store.drain().size)
    }

    @Test
    fun logout_stops_attribution_and_hides_events_and_the_next_login_never_inherits_them() {
        store.attachAnalysis(recorded("com.x"), analysis)
        store.setOwner(null)
        assertTrue(store.drain().isEmpty())
        store.setOwner("user-b")
        assertTrue(store.drain().isEmpty())
    }

    @Test
    fun results_for_another_accounts_event_are_ignored() {
        val id = recorded("com.x"); store.attachAnalysis(id, analysis)
        // simulate a row that belongs to someone else (it cannot be created through the API once the owner is switched)
        db.exec("UPDATE monitor_events SET owner = 'user-b' WHERE id = ?", listOf(id))
        val r = store.markResults(listOf(MonitorEventStore.Result(id, "created", "queued")))
        assertEquals(0, r.updated); assertEquals(1, r.ignored)
        assertEquals("pending", db.query("SELECT history_state AS s FROM monitor_events").first()["s"])
        assertFalse(store.attachAnalysis(id, analysis))
        assertTrue(store.drain().isEmpty())
    }

    @Test
    fun purge_removes_one_accounts_events_or_all() {
        store.attachAnalysis(recorded("com.x"), analysis)
        db.exec("INSERT INTO monitor_events (id, owner, occurred_at, package_name, event_type, created_at, updated_at) VALUES ('o', 'user-b', 1, 'p', 'installed', 1, 1)")
        assertEquals(MonitorEventStore.PurgeResult(true, 1), store.purge("user-a"))
        assertEquals(1L, db.query("SELECT COUNT(*) AS n FROM monitor_events").first()["n"])
        assertEquals(MonitorEventStore.PurgeResult(true, 1), store.purge(null))
        assertEquals(0L, db.query("SELECT COUNT(*) AS n FROM monitor_events").first()["n"])
    }

    @Test
    fun invalid_owner_ids_are_refused_and_leave_the_owner_unchanged() {
        assertFalse(store.setOwner("   "))
        assertFalse(store.setOwner("x".repeat(200)))
        assertEquals("user-a", store.currentOwner())
    }

    // ------------------------------------------------------------------------------------------------ database errors
    @Test
    fun a_storage_error_never_throws_and_is_counted() {
        db.failNext = true
        assertEquals(MonitorEventStore.Recorded.Failed, store.record("com.x", "installed", now))
        db.failNext = true
        assertTrue(store.drain().isEmpty())
        db.failNext = true
        assertEquals(0, store.markResults(listOf(MonitorEventStore.Result("x", "created", null))).updated)
        db.failNext = true
        assertEquals(false, store.stats()["available"])
        assertTrue(store.storageErrors >= 4)
        assertTrue(store.record("com.x", "installed", now) is MonitorEventStore.Recorded.New) // and it recovers
    }

    @Test
    fun a_failure_in_the_middle_of_a_transaction_leaves_nothing_half_written() {
        store.attachAnalysis(recorded("com.x"), analysis)
        val before = db.query("SELECT COUNT(*) AS n FROM monitor_events").first()["n"]
        db.exec("CREATE TRIGGER boom BEFORE INSERT ON monitor_events BEGIN SELECT RAISE(ABORT, 'x'); END")
        assertEquals(MonitorEventStore.Recorded.Failed, store.record("com.y", "installed", now))
        db.exec("DROP TRIGGER boom")
        assertEquals(before, db.query("SELECT COUNT(*) AS n FROM monitor_events").first()["n"])
    }

    @Test
    fun invalid_events_are_not_stored() {
        assertEquals(MonitorEventStore.Recorded.Failed, store.record("", "installed", now))
        assertEquals(MonitorEventStore.Recorded.Failed, store.record("com.x", "exploded", now))
        assertEquals(MonitorEventStore.Recorded.Failed, store.record("p".repeat(300), "installed", now))
        assertEquals(0L, store.stats()["total"])
    }

    // ------------------------------------------------------------------------------------------------ housekeeping and privacy
    @Test
    fun old_finished_events_age_out_but_unsent_recent_ones_are_kept() {
        val done = recorded("com.done"); store.attachAnalysis(done, analysis)
        store.markResults(listOf(MonitorEventStore.Result(done, "created", "sent")))
        val unsent = recorded("com.unsent", at = now + 20_000); store.attachAnalysis(unsent, analysis)
        now += MonitorEventStore.TERMINAL_RETENTION_MS + 1
        recorded("com.new", at = now) // any new record triggers housekeeping
        val ids = db.query("SELECT id FROM monitor_events").map { it["id"] }
        assertFalse(ids.contains(done)); assertTrue(ids.contains(unsent))
    }

    @Test
    fun the_table_never_grows_beyond_the_cap_and_keeps_unsent_events_first() {
        repeat(MonitorEventStore.MAX_ROWS + 25) { i -> recorded("com.p$i", at = now + i * 20_000L) }
        assertTrue((db.query("SELECT COUNT(*) AS n FROM monitor_events").first()["n"] as Long) <= MonitorEventStore.MAX_ROWS)
    }

    @Test
    fun stats_contain_counts_only_and_no_package_or_owner_text() {
        store.attachAnalysis(recorded("com.very.secret.bank"), analysis)
        val text = store.stats().toString()
        assertFalse(text.contains("secret")); assertFalse(text.contains("user-a")); assertFalse(text.contains("Risky"))
        assertNotNull(store.stats()["total"]); assertNull(store.stats()["package_name"])
    }

    @Test
    fun the_store_does_not_log() {
        val src = File("src/main/kotlin/com/secureshield/secureshield_app/MonitorEventStore.kt").takeIf { it.exists() }
            ?: File("app/src/main/kotlin/com/secureshield/secureshield_app/MonitorEventStore.kt")
        val code = src.readText()
        assertFalse(Regex("""\b(Log\.|println|printStackTrace|Timber)""").containsMatchIn(code))
    }

    // ------------------------------------------------------------------------------------------------ guardian mapping
    private fun synced(guardian: String?, reason: String? = null): Map<String, Any?> {
        val id = recorded("com.g${seq + 1}", at = now + (seq + 1) * 20_000L); store.attachAnalysis(id, analysis)
        store.markResults(listOf(MonitorEventStore.Result(id, "created", guardian, reason)))
        return db.query("SELECT history_state AS h, guardian_state AS g, guardian_reason AS r FROM monitor_events WHERE id = ?", listOf(id)).first()
    }

    @Test
    fun every_server_guardian_status_maps_to_what_it_really_means() {
        val expected = mapOf(
            "queued" to "accepted", "already" to "accepted", "pending" to "accepted", "leased" to "accepted",
            "sent" to "provider_accepted",
            "skipped" to "not_sent", "expired" to "not_sent", "none" to "not_sent",
            "failed" to "failed",
            null to "pending", "weird" to "pending",
        )
        expected.forEach { (server, state) ->
            val row = synced(server)
            assertEquals("history is synced regardless of the guardian answer ($server)", "synced", row["h"])
            assertEquals("guardian $server", state, row["g"])
        }
    }

    @Test
    fun a_queued_alert_is_never_reported_as_delivered_or_provider_accepted() {
        synced("queued"); synced("already")
        val st = store.stats()
        assertEquals(2L, st["guardianAccepted"]); assertEquals(0L, st["guardianProviderAccepted"])
        assertFalse(st.keys.any { it.contains("elivered") })
    }

    @Test
    fun the_guardian_reason_code_is_kept_and_anything_that_is_not_a_code_is_dropped() {
        assertEquals("not_authorised", synced("skipped", "not_authorised")["r"])
        assertNull(synced("skipped", "com.bank.secret app")["r"])
        assertNull(synced("skipped", "A".repeat(60))["r"])
        assertNull(synced("skipped", null)["r"])
    }

    // ------------------------------------------------------------------------------------------------ failure diagnostics
    private fun failRow(error: String? = "no_outcome"): String {
        val id = recorded("com.fail${++seq}", at = now + seq * 20_000L); store.attachAnalysis(id, analysis)
        repeat(MonitorEventStore.MAX_ATTEMPTS) {
            now += 4_000_000
            store.markResults(listOf(MonitorEventStore.Result(id, "retry", null, null, error)))
        }
        return id
    }

    @Test
    fun an_exhausted_event_is_failed_never_synced_with_a_kept_error_code_and_a_settled_guardian_state() {
        val id = failRow("http_422")
        val row = db.query("SELECT history_state AS h, guardian_state AS g, guardian_reason AS r, last_error AS e, attempts AS a FROM monitor_events WHERE id = ?", listOf(id)).first()
        assertEquals("failed", row["h"]); assertEquals("not_sent", row["g"]); assertEquals("history_failed", row["r"])
        assertEquals("http_422", row["e"]); assertEquals(MonitorEventStore.MAX_ATTEMPTS.toLong(), row["a"])
        val st = store.stats()
        assertEquals(1L, st["historyFailed"]); assertEquals(0L, st["historySynced"]); assertEquals(0L, st["guardianPending"])
        assertEquals(mapOf("http_422" to 1L), st["errorCodes"])
        now += 4_000_000
        assertTrue(store.drain().isEmpty()) // and it is never uploaded again
    }

    @Test
    fun a_retry_before_the_limit_keeps_the_event_pending_with_its_last_error() {
        val id = recorded("com.x"); store.attachAnalysis(id, analysis)
        store.markResults(listOf(MonitorEventStore.Result(id, "retry", null, null, "no_outcome")))
        val row = db.query("SELECT history_state AS h, last_error AS e FROM monitor_events").first()
        assertEquals("pending", row["h"]); assertEquals("no_outcome", row["e"])
    }

    @Test
    fun error_and_rejection_reasons_are_validated_codes_only() {
        val a = recorded("com.a"); val b = recorded("com.b", at = now + 20_000)
        listOf(a, b).forEach { store.attachAnalysis(it, analysis) }
        store.markResults(listOf(
            MonitorEventStore.Result(a, "rejected", null, null, "bad_timestamp"),
            MonitorEventStore.Result(b, "rejected", null, null, "Bad Value: com.secret.app"),
        ))
        assertEquals(mapOf("bad_timestamp" to 1L, "rejected" to 1L), store.stats()["errorCodes"])
        assertFalse(store.stats().toString().contains("secret"))
    }

    // ------------------------------------------------------------------------------------------------ retention keeps a record
    @Test
    fun retention_cleanup_counts_the_failed_rejected_and_unsent_events_it_removes() {
        failRow()
        val rej = recorded("com.rej", at = now + 40_000); store.attachAnalysis(rej, analysis)
        store.markResults(listOf(MonitorEventStore.Result(rej, "rejected", null, null, "invalid_payload")))
        val ok = recorded("com.ok", at = now + 60_000); store.attachAnalysis(ok, analysis)
        store.markResults(listOf(MonitorEventStore.Result(ok, "created", "queued")))
        val unsent = recorded("com.unsent", at = now + 80_000); store.attachAnalysis(unsent, analysis)
        now += MonitorEventStore.MAX_AGE_MS + 1 // everything is now past the maximum age
        recorded("com.new", at = now)
        val st = store.stats()
        assertEquals(1L, st["lostFailed"]); assertEquals(1L, st["lostRejected"]); assertEquals(1L, st["lostUnsent"]) // synced is not "lost"
    }

    @Test
    fun finished_failed_events_age_out_after_seven_days_but_are_counted() {
        failRow()
        now += MonitorEventStore.TERMINAL_RETENTION_MS + 1
        recorded("com.new", at = now)
        assertEquals(0L, store.stats()["historyFailed"]); assertEquals(1L, store.stats()["lostFailed"])
    }

    @Test
    fun the_diagnostics_belong_to_their_account_and_go_with_it() {
        failRow()
        now += MonitorEventStore.TERMINAL_RETENTION_MS + 1
        recorded("com.new", at = now)
        assertEquals(1L, store.stats()["lostFailed"])
        store.setOwner("user-b")
        assertEquals(0L, store.stats()["lostFailed"]) // the next account does not see the previous account's counters
        assertEquals(0L, db.query("SELECT COUNT(*) AS n FROM monitor_diag").first()["n"])
    }

    // ------------------------------------------------------------------------------------------------ purge result
    @Test
    fun a_purge_that_fails_says_so_instead_of_reporting_zero() {
        store.attachAnalysis(recorded("com.x"), analysis)
        db.failNext = true
        val r = store.purge(null)
        assertFalse(r.ok); assertEquals(0, r.deleted)
        assertEquals(1L, db.query("SELECT COUNT(*) AS n FROM monitor_events").first()["n"]) // nothing half-deleted
        assertTrue(store.storageErrors >= 1)
        assertTrue(store.purge(null).ok) // and it works once the storage does
    }

    @Test
    fun a_purge_clears_the_diagnostics_too() {
        failRow(); now += MonitorEventStore.TERMINAL_RETENTION_MS + 1; recorded("com.new", at = now)
        assertTrue(store.purge(null).ok)
        assertEquals(0L, db.query("SELECT COUNT(*) AS n FROM monitor_diag").first()["n"])
    }

    // ------------------------------------------------------------------------------------------------ schema upgrade
    @Test
    fun a_version_1_database_is_upgraded_in_place_without_losing_events() {
        val f = File.createTempFile("legacy_v1", ".db").also { it.deleteOnExit() }
        val old = JdbcSqlDb(f)
        old.exec("""CREATE TABLE monitor_events (id TEXT PRIMARY KEY NOT NULL, owner TEXT NOT NULL, occurred_at INTEGER NOT NULL,
            package_name TEXT NOT NULL, event_type TEXT NOT NULL, app_name TEXT, version_name TEXT, installer_package TEXT,
            is_unknown_source INTEGER NOT NULL DEFAULT 0, is_system_app INTEGER NOT NULL DEFAULT 0, dangerous_perms TEXT,
            perm_count INTEGER NOT NULL DEFAULT 0, has_overlay INTEGER NOT NULL DEFAULT 0, first_install_time INTEGER,
            local_risk_score INTEGER NOT NULL DEFAULT 0, analysis_state TEXT NOT NULL DEFAULT 'pending',
            history_state TEXT NOT NULL DEFAULT 'pending', guardian_state TEXT NOT NULL DEFAULT 'pending',
            attempts INTEGER NOT NULL DEFAULT 0, next_attempt_at INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL)""")
        old.exec("CREATE TABLE monitor_meta (k TEXT PRIMARY KEY NOT NULL, v TEXT)")
        old.exec("INSERT INTO monitor_meta VALUES ('owner', 'user-a')")
        old.exec("INSERT INTO monitor_events (id, owner, occurred_at, package_name, event_type, analysis_state, created_at, updated_at) VALUES ('keep', 'user-a', 5, 'p', 'installed', 'done', 1, 1)")
        old.transaction { MonitorSchema.upgradeV1ToV2(old) }
        val s2 = newStore(old); s2.init()
        now = 10_000_000_000_000L
        assertEquals(1, s2.drain().size)
        assertTrue(s2.markResults(listOf(MonitorEventStore.Result("keep", "created", "sent"))).updated == 1)
        assertEquals("provider_accepted", old.query("SELECT guardian_state AS g FROM monitor_events").first()["g"])
        old.close()
    }
}
