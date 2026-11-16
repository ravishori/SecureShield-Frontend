package com.secureshield.secureshield_app

import com.secureshield.secureshield_app.MonitorPolicy.Decision
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class MonitorPolicyTest {
    private val added = MonitorPolicy.ACTION_PACKAGE_ADDED
    private val importanceNone = 0
    private val importanceLow = 2
    private val oreo = 26
    private val preOreo = 25
    private val android15 = 35

    // ---- preference parsing: fail closed -------------------------------------------------------------------------
    @Test fun onlyABooleanTrueEnables() = assertTrue(MonitorPolicy.parse(true))
    @Test fun falseIsOff() = assertFalse(MonitorPolicy.parse(false))
    @Test fun missingIsOff() = assertFalse(MonitorPolicy.parse(null))
    @Test fun corruptStringIsOff() {
        assertFalse(MonitorPolicy.parse("true"))
        assertFalse(MonitorPolicy.parse("yes"))
    }
    @Test fun corruptNumberIsOff() {
        assertFalse(MonitorPolicy.parse(1))
        assertFalse(MonitorPolicy.parse(1L))
    }
    @Test fun otherObjectsAreOff() = assertFalse(MonitorPolicy.parse(Any()))

    // ---- notification visibility: fail closed ----------------------------------------------------------------------
    @Test fun visibleWhenAppNotificationsAndChannelAreOn() = assertTrue(MonitorPolicy.isVisible(true, android15, importanceLow))

    @Test fun permissionRevokedMeansNotVisible() = assertFalse(MonitorPolicy.isVisible(false, android15, importanceLow))

    @Test fun disabledChannelMeansNotVisible() = assertFalse(MonitorPolicy.isVisible(true, android15, importanceNone))

    @Test fun missingChannelMeansNotVisible() = assertFalse(MonitorPolicy.isVisible(true, android15, null))

    @Test fun failedAppLevelCheckMeansNotVisible() {
        assertFalse(MonitorPolicy.isVisible(null, android15, importanceLow))
        assertFalse(MonitorPolicy.isVisible(null, preOreo, null))
    }

    @Test fun beforeAndroid8ThereAreNoChannelsSoTheAppSwitchDecides() {
        assertTrue(MonitorPolicy.isVisible(true, preOreo, null))
        assertFalse(MonitorPolicy.isVisible(false, preOreo, null))
    }

    @Test fun androidEightIsTheFirstVersionThatNeedsAChannel() {
        assertFalse(MonitorPolicy.isVisible(true, oreo, null))
        assertTrue(MonitorPolicy.isVisible(true, oreo, importanceLow))
    }

    @Test fun everyImportanceAboveNoneCountsAsVisible() {
        for (i in 1..5) assertTrue(MonitorPolicy.isVisible(true, android15, i))
    }

    // ---- monitoring OFF: nothing is processed ---------------------------------------------------------------------
    @Test fun offIgnoresEverythingWhateverTheNotificationState() {
        for (visible in listOf(true, false)) for (running in listOf(true, false)) {
            assertEquals(Decision.IGNORE_MONITORING_OFF, MonitorPolicy.decide(added, false, false, visible, running))
            assertEquals(Decision.IGNORE_MONITORING_OFF, MonitorPolicy.decide("x", true, false, visible, running))
        }
    }

    // ---- monitoring ON but not visible: pause, process nothing ------------------------------------------------------
    @Test fun onButNotVisiblePausesBeforeAnythingElseIsDecided() {
        for (running in listOf(true, false)) for (replacing in listOf(true, false)) {
            assertEquals(Decision.PAUSE_NOTIFICATIONS_OFF, MonitorPolicy.decide(added, replacing, true, false, running))
            assertEquals(Decision.PAUSE_NOTIFICATIONS_OFF, MonitorPolicy.decide("other", replacing, true, false, running))
        }
    }

    // ---- monitoring ON and visible ----------------------------------------------------------------------------------
    @Test fun onWithoutServiceHandlesAFreshInstall() =
        assertEquals(Decision.HANDLE, MonitorPolicy.decide(added, false, true, true, false))

    @Test fun onWithServiceLeavesItToTheServiceSoThereIsOneNotification() =
        assertEquals(Decision.LEFT_TO_SERVICE, MonitorPolicy.decide(added, false, true, true, true))

    @Test fun updatesAndOtherActionsAreNotHandled() {
        assertEquals(Decision.IGNORE_NOT_APPLICABLE, MonitorPolicy.decide(added, true, true, true, false))
        assertEquals(Decision.IGNORE_NOT_APPLICABLE, MonitorPolicy.decide("android.intent.action.PACKAGE_REMOVED", false, true, true, false))
        assertEquals(Decision.IGNORE_NOT_APPLICABLE, MonitorPolicy.decide(null, false, true, true, false))
    }

    @Test fun theHandledActionIsTheProtectedSystemBroadcast() =
        assertEquals("android.intent.action.PACKAGE_ADDED", MonitorPolicy.ACTION_PACKAGE_ADDED)

    @Test fun onlyOneComponentActsAndOnlyWhenOnAndVisible() {
        for (enabled in listOf(true, false)) for (visible in listOf(true, false))
            for (running in listOf(true, false)) for (replacing in listOf(true, false)) {
                val d = MonitorPolicy.decide(added, replacing, enabled, visible, running)
                val acts = d == Decision.HANDLE || d == Decision.LEFT_TO_SERVICE
                if (acts) assertTrue("acts only when enabled and visible", enabled && visible)
                assertFalse(d == Decision.HANDLE && d == Decision.LEFT_TO_SERVICE)
            }
    }

    @Test fun revocationThenRestoreFlow() {
        // revoked while ON -> pause
        assertEquals(Decision.PAUSE_NOTIFICATIONS_OFF, MonitorPolicy.decide(added, false, true, false, true))
        // after the pause the preference is OFF: the next event, even with notifications back, is ignored until the user restarts
        assertEquals(Decision.IGNORE_MONITORING_OFF, MonitorPolicy.decide(added, false, false, true, false))
    }
}
