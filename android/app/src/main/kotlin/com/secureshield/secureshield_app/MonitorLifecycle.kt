package com.secureshield.secureshield_app

/**
 * Pure (Android-free) lifecycle state for [AppMonitorService], so the rules can be unit-tested on the JVM.
 *
 * Rules:
 *  - "running" becomes true only when a start is accepted, and false again on a failed start, a stop, or destruction;
 *  - a second start while running is reported as [StartOutcome.ALREADY_RUNNING] (never a second receiver or notification);
 *  - stop is idempotent and says whether anything was actually running.
 * The flag lives in the process, so after the process is killed it is false again: the UI must ask, never assume.
 */
class MonitorLifecycle {
    enum class StartOutcome { STARTED, ALREADY_RUNNING }

    private val lock = Any()

    @Volatile
    var running: Boolean = false
        private set

    fun begin(): StartOutcome = synchronized(lock) {
        if (running) {
            StartOutcome.ALREADY_RUNNING
        } else {
            running = true
            StartOutcome.STARTED
        }
    }

    /** The start did not complete (for example the foreground promotion was refused): roll back. */
    fun failed() = synchronized(lock) { running = false }

    /** Returns true if the monitor WAS running. */
    fun end(): Boolean = synchronized(lock) {
        val was = running
        running = false
        was
    }

    companion object {
        /**
         * Polls [probe] up to [attempts] times, [intervalMs] apart; true as soon as it holds. Used to CONFIRM a requested
         * state change with the service itself before telling the UI anything.
         */
        fun awaitState(
            attempts: Int,
            intervalMs: Long,
            sleep: (Long) -> Unit = { Thread.sleep(it) },
            probe: () -> Boolean,
        ): Boolean {
            repeat(attempts) {
                if (probe()) return true
                sleep(intervalMs)
            }
            return probe()
        }
    }
}
