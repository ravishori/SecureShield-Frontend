package com.secureshield.secureshield_app

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SubscriptionInfo
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import android.util.Log
import androidx.core.content.ContextCompat
import java.security.MessageDigest

/**
 * Privacy-preserving SIM fingerprint provider.
 *
 * Reads available SIM identifiers (serial number, subscriber ID, carrier
 * name, slot index, mobile country/network codes) and returns a list of
 * per-SIM fingerprints. Each fingerprint is a **SHA-256 hash** of the
 * raw identifiers — the raw values never leave this class. This means:
 *
 *   • Comparison across launches still works (same SIM → same hash).
 *   • A leaked fingerprint reveals no PII.
 *   • Storage is fixed-size regardless of carrier name length.
 *
 * Compatibility notes:
 *   • `getSimSerialNumber()` returns null on API 29+ unless the app is the
 *     device/profile owner or carrier-privileged. We fall back to the
 *     carrier name + slot + MCC/MNC + ICCID-via-SubscriptionInfo (when
 *     `READ_PHONE_STATE` is granted) which is sufficient for detecting
 *     swaps in practice.
 *   • Dual-SIM is fully supported via SubscriptionManager (API 22+).
 *   • Method is safe to call from any thread; no I/O.
 */
object SimFingerprintProvider {
    private const val TAG = "SimFingerprint"

    /** Single SIM fingerprint plus the carrier name (which is safe to show). */
    data class SimRecord(
        val slotIndex: Int,
        val carrierName: String,
        val countryIso: String,
        val mccMnc: String,           // e.g. "405854" (India / Reliance Jio)
        val fingerprintSha256: String, // 64-char hex
        val hasFullId: Boolean,        // true if we could read ICCID/serial
    )

    /**
     * Returns one record per active SIM. Empty list when no SIM is present
     * or permissions are denied.
     */
    @SuppressLint("MissingPermission", "HardwareIds")
    fun read(context: Context): List<SimRecord> {
        if (!hasPhonePermission(context)) {
            Log.i(TAG, "READ_PHONE_STATE not granted — returning empty list")
            return emptyList()
        }

        val out = mutableListOf<SimRecord>()
        try {
            val subscriptionMgr = ContextCompat.getSystemService(
                context, SubscriptionManager::class.java
            )
            val telephonyMgr = ContextCompat.getSystemService(
                context, TelephonyManager::class.java
            ) ?: return emptyList()

            // ── Path 1: Dual-SIM aware via SubscriptionManager ───────────
            if (subscriptionMgr != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                val active: List<SubscriptionInfo> =
                    subscriptionMgr.activeSubscriptionInfoList ?: emptyList()
                for (sub in active) {
                    out += buildRecord(context, telephonyMgr, sub)
                }
            }

            // ── Path 2: Single-SIM fallback for very old devices ─────────
            if (out.isEmpty()) {
                val serial = legacySerial(telephonyMgr)
                val carrier = telephonyMgr.networkOperatorName.orEmpty()
                val mccMnc = telephonyMgr.networkOperator.orEmpty()
                val country = telephonyMgr.networkCountryIso.orEmpty()
                if (serial != null || carrier.isNotEmpty()) {
                    out += SimRecord(
                        slotIndex = 0,
                        carrierName = carrier,
                        countryIso = country,
                        mccMnc = mccMnc,
                        fingerprintSha256 = sha256(
                            "legacy|$serial|$carrier|$mccMnc|$country"
                        ),
                        hasFullId = serial != null,
                    )
                }
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Permission revoked mid-call: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Unexpected SIM read failure", e)
        }
        return out
    }

    @SuppressLint("MissingPermission", "HardwareIds")
    private fun buildRecord(
        ctx: Context,
        tm: TelephonyManager,
        sub: SubscriptionInfo,
    ): SimRecord {
        // Prefer per-subscription telephony manager (API 24+) so multi-SIM
        // devices return the correct identifier per slot.
        val perSubTm: TelephonyManager =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                tm.createForSubscriptionId(sub.subscriptionId)
            } else tm

        val iccid: String? = try {
            // ICCID is the stable physical SIM card ID. Available via
            // SubscriptionInfo on most OEMs even when getSimSerialNumber
            // returns null on API 29+.
            sub.iccId.takeIf { !it.isNullOrBlank() } ?: legacySerial(perSubTm)
        } catch (_: Throwable) { null }

        val imsi: String? = try { legacySubscriberId(perSubTm) } catch (_: Throwable) { null }
        val carrier = sub.carrierName?.toString().orEmpty()
        val country = sub.countryIso.orEmpty()
        val mcc = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            sub.mccString.orEmpty() else sub.mcc.toString()
        val mnc = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            sub.mncString.orEmpty() else sub.mnc.toString()
        val mccMnc = "$mcc$mnc"

        // Composite raw identifier — we hash this so PII never leaves.
        // Order matters: keep stable across launches.
        val raw = buildString {
            append("v1|")
            append(iccid ?: "")
            append('|')
            append(imsi ?: "")
            append('|')
            append(carrier)
            append('|')
            append(mccMnc)
            append('|')
            append(country)
            append('|')
            append(sub.simSlotIndex)
        }

        return SimRecord(
            slotIndex = sub.simSlotIndex,
            carrierName = carrier,
            countryIso = country,
            mccMnc = mccMnc,
            fingerprintSha256 = sha256(raw),
            hasFullId = iccid != null,
        )
    }

    private fun hasPhonePermission(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            context, Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED
    }

    @SuppressLint("MissingPermission", "HardwareIds")
    private fun legacySerial(tm: TelephonyManager): String? = try {
        @Suppress("DEPRECATION")
        tm.simSerialNumber
    } catch (_: Throwable) { null }

    @SuppressLint("MissingPermission", "HardwareIds")
    private fun legacySubscriberId(tm: TelephonyManager): String? = try {
        @Suppress("DEPRECATION")
        tm.subscriberId
    } catch (_: Throwable) { null }

    private fun sha256(input: String): String {
        val md = MessageDigest.getInstance("SHA-256")
        val digest = md.digest(input.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }
}
