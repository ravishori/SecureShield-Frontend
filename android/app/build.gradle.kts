import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Release signing ─────────────────────────────────────────────────────────────────────────────────────────────
// Release builds are signed ONLY with an upload key supplied from outside the repository, and the build FAILS
// when it is missing or invalid. There is no fallback to the debug key. Debug/profile builds are unaffected.
//
// Credentials come from (first match wins):
//   1. environment variables (CI):  SECURESHIELD_KEYSTORE_PATH, SECURESHIELD_KEYSTORE_PASSWORD,
//                                   SECURESHIELD_KEY_ALIAS, SECURESHIELD_KEY_PASSWORD
//   2. android/key.properties (git-ignored; template: key.properties.example): storeFile, storePassword,
//      keyAlias, keyPassword
// The keystore must live OUTSIDE this project folder so it can never be committed. Passwords are never printed.
// See docs/ANDROID_RELEASE.md and tool/verify_apk_signature.py.
fun releaseSigningInputs(): Map<String, String> {
    val env = System.getenv()
    if (!env["SECURESHIELD_KEYSTORE_PATH"].isNullOrBlank()) {
        return mapOf(
            "storeFile" to (env["SECURESHIELD_KEYSTORE_PATH"] ?: ""),
            "storePassword" to (env["SECURESHIELD_KEYSTORE_PASSWORD"] ?: ""),
            "keyAlias" to (env["SECURESHIELD_KEY_ALIAS"] ?: ""),
            "keyPassword" to (env["SECURESHIELD_KEY_PASSWORD"] ?: ""),
        )
    }
    val file = rootProject.file("key.properties")
    if (!file.exists()) return emptyMap()
    val p = Properties()
    file.inputStream().use { p.load(it) }
    return listOf("storeFile", "storePassword", "keyAlias", "keyPassword").associateWith { p.getProperty(it, "") }
}

val releaseRequested = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
val signingInputs = releaseSigningInputs()
var releaseStoreFile: File? = null

if (releaseRequested) {
    val problems = mutableListOf<String>()
    if (signingInputs.isEmpty()) {
        problems += "no signing configuration found (set the SECURESHIELD_* environment variables or create android/key.properties from key.properties.example)"
    } else {
        signingInputs.forEach { (k, v) ->
            if (v.isBlank()) problems += "$k is empty"
            else if (v.trim().uppercase().let { it.startsWith("CHANGE") || it.startsWith("YOUR_") || it == "TODO" }) problems += "$k is still a placeholder"
        }
        val path = signingInputs["storeFile"].orEmpty()
        if (path.isNotBlank()) {
            val f = File(path).let { if (it.isAbsolute) it else rootProject.file(path) }.canonicalFile
            val projectRoot = rootProject.projectDir.parentFile.canonicalFile
            if (!f.exists()) problems += "the keystore file does not exist"
            else if (f.canonicalPath.startsWith(projectRoot.canonicalPath + File.separator)) problems += "the keystore is inside the project folder; keep it outside the repository"
            else releaseStoreFile = f
        }
    }
    if (problems.isNotEmpty()) {
        throw GradleException(
            "Release signing is not configured correctly: " + problems.joinToString("; ") +
                ". Release builds are never signed with the debug key. Nothing was built.",
        )
    }
}

android {
    namespace = "com.secureshield.secureshield_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.secureshield.secureshield_app"
        minSdk = flutter.minSdkVersion  // flutter_local_notifications requires API 21+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseRequested) {
            create("release") {
                storeFile = releaseStoreFile
                storePassword = signingInputs["storePassword"]
                keyAlias = signingInputs["keyAlias"]
                keyPassword = signingInputs["keyPassword"]
            }
        }
    }

    buildTypes {
        release {
            // Only the externally supplied upload key; when no release task is requested (IDE sync, debug builds)
            // no signing config is attached and nothing can be produced from it.
            if (releaseRequested) signingConfig = signingConfigs.getByName("release")
            // R8 code shrinking/obfuscation + resource shrinking.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Required for ServiceCompat.startForeground(service, id, notif, foregroundServiceType)
    // which is the Android 14+ safe-call. Version 1.12.0 added the 4-arg overload.
    implementation("androidx.core:core-ktx:1.13.1")
    // local_auth (BiometricPrompt) needs a FragmentActivity with an AppCompat theme.
    implementation("androidx.appcompat:appcompat:1.7.0")
}
