# R8 rules for SecureShield. Flutter's own rules are added by the Flutter Gradle plugin.

# Keep line numbers for crash reports, hide the original source file name.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# App code reached through platform channels / services / receivers declared in the manifest.
-keep class com.secureshield.secureshield_app.** { *; }

# workmanager background dispatcher is looked up by name.
-keep class be.tramckrack.workmanager.** { *; }
-keep class dev.fluttercommunity.workmanager.** { *; }

# flutter_local_notifications serialises notification payloads with Gson (reflection).
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Play core deferred components are referenced by Flutter but not used.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# ML Kit text recognition: optional script packs the app does not bundle (Latin only).
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
