package com.secureshield.secureshield_app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MonitorLifecycleTest {
    @Test
    fun startsStopped() {
        assertFalse(MonitorLifecycle().running)
    }

    @Test
    fun firstStartIsAcceptedAndMarksRunning() {
        val l = MonitorLifecycle()
        assertEquals(MonitorLifecycle.StartOutcome.STARTED, l.begin())
        assertTrue(l.running)
    }

    @Test
    fun duplicateStartIsReportedAndChangesNothing() {
        val l = MonitorLifecycle()
        l.begin()
        assertEquals(MonitorLifecycle.StartOutcome.ALREADY_RUNNING, l.begin())
        assertTrue(l.running)
    }

    @Test
    fun failedStartRollsBackSoTheUiCannotSeeRunning() {
        val l = MonitorLifecycle()
        l.begin()
        l.failed()
        assertFalse(l.running)
        assertEquals(MonitorLifecycle.StartOutcome.STARTED, l.begin()) // a retry is possible
    }

    @Test
    fun stopIsIdempotentAndReportsWhetherAnythingWasRunning() {
        val l = MonitorLifecycle()
        assertFalse(l.end())
        l.begin()
        assertTrue(l.end())
        assertFalse(l.end())
        assertFalse(l.running)
    }

    @Test
    fun restartAfterStopWorks() {
        val l = MonitorLifecycle()
        l.begin(); l.end()
        assertEquals(MonitorLifecycle.StartOutcome.STARTED, l.begin())
    }

    @Test
    fun anotherInstanceStartsStoppedLikeAfterProcessDeath() {
        val before = MonitorLifecycle()
        before.begin()
        assertFalse(MonitorLifecycle().running) // state is per process: after a kill nothing claims to be running
    }

    @Test
    fun awaitStateReturnsTrueAsSoonAsTheProbeHolds() {
        var calls = 0
        val sleeps = mutableListOf<Long>()
        val ok = MonitorLifecycle.awaitState(10, 100, { sleeps.add(it) }) { ++calls >= 3 }
        assertTrue(ok)
        assertEquals(listOf(100L, 100L), sleeps)
    }

    @Test
    fun awaitStateGivesUpWhenTheStateNeverArrives() {
        val sleeps = mutableListOf<Long>()
        val ok = MonitorLifecycle.awaitState(5, 50, { sleeps.add(it) }) { false }
        assertFalse(ok)
        assertEquals(5, sleeps.size)
    }

    @Test
    fun awaitStateRechecksOnceAtTheEnd() {
        var calls = 0
        val ok = MonitorLifecycle.awaitState(2, 1, { }) { ++calls == 3 } // true only on the final re-check
        assertTrue(ok)
    }

    @Test
    fun concurrentStartsAcceptExactlyOne() {
        val l = MonitorLifecycle()
        val started = java.util.concurrent.atomic.AtomicInteger()
        val threads = (1..16).map {
            Thread { if (l.begin() == MonitorLifecycle.StartOutcome.STARTED) started.incrementAndGet() }
        }
        threads.forEach { it.start() }
        threads.forEach { it.join() }
        assertEquals(1, started.get())
    }
}
