# Flutter / Dart
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# flutter_local_notifications + background isolate
-keep class com.dexterous.** { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes SourceFile,LineNumberTable

# Gson / JSON usados em payload de notificação
-dontwarn com.google.gson.**
-keep class com.google.gson.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Secure storage / crypto
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-dontwarn com.it_nomads.fluttersecurestorage.**

# Pusher
-keep class com.pusher.** { *; }
-dontwarn com.pusher.**

-dontwarn org.slf4j.impl.StaticLoggerBinder

# Play Core (Flutter deferred components — não usado no app, só referencia)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-dontwarn com.google.android.play.core.**
