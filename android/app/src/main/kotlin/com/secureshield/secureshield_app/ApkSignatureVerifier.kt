package com.secureshield.secureshield_app

import android.content.Context
import android.content.pm.PackageManager
import android.content.pm.Signature
import android.os.Build
import java.security.MessageDigest
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate

/**
 * APK signature verification — extracts certificate SHA-256 hash.
 *
 * Used to detect tampered or repackaged APKs by comparing against known-good
 * signatures. Run-time performance: ~5-10ms per app (negligible).
 *
 * Safety: We only read public certificate info via PackageManager — no security
 * elevation needed.
 */
object ApkSignatureVerifier {

    /**
     * Get the SHA-256 hash of an app's signing certificate.
     *
     * Returns: hex-encoded SHA-256 (lowercase), or null if the package is not found.
     * Example: "abc123def456..."
     */
    fun getSignatureSha256(context: Context, packageName: String): String? {
        return try {
            val pm = context.packageManager

            // Get signatures based on Android version
            val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val pkgInfo = pm.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNING_CERTIFICATES
                )
                pkgInfo.signingInfo?.apkContentsSigners ?: return null
            } else {
                @Suppress("DEPRECATION")
                val pkgInfo = pm.getPackageInfo(
                    packageName,
                    PackageManager.GET_SIGNATURES
                )
                pkgInfo.signatures ?: return null
            }

            if (signatures.isEmpty()) return null

            // Get the first signature
            val signature = signatures.firstOrNull() ?: return null

            // Convert signature to X509 certificate
            val certFactory = CertificateFactory.getInstance("X.509")
            val cert = certFactory.generateCertificate(signature.toByteArray().inputStream())
                as? X509Certificate ?: return null

            // Calculate SHA-256 hash
            val md = MessageDigest.getInstance("SHA-256")
            val digest = md.digest(cert.encoded)

            // Convert bytes to hex (lowercase)
            digest.joinToString("") { byte ->
                String.format("%02x", byte.toInt() and 0xFF)
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Compare an app's signature against a known-good hash.
     *
     * Returns: true if signatures match (app is authentic), false otherwise.
     */
    fun verifySignature(
        context: Context,
        packageName: String,
        expectedHash: String
    ): Boolean {
        val actual = getSignatureSha256(context, packageName) ?: return false
        return actual.equals(expectedHash, ignoreCase = true)
    }

    /**
     * Batch-verify multiple apps against a hash map.
     *
     * Useful for checking a list of banking apps, for example.
     * Returns: map of packageName -> isValid
     */
    fun verifyMultiple(
        context: Context,
        packages: Map<String, String>  // packageName -> expectedHash
    ): Map<String, Boolean> {
        return packages.mapValues { (pkg, expectedHash) ->
            verifySignature(context, pkg, expectedHash)
        }
    }
}
