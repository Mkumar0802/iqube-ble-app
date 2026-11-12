# ---------------------------------------------------------------------------
# R8 ProGuard Rules for My iQube BLE Companion
# Enables aggressive code shrinking, tree-shaking, and optimization while
# preserving Flutter JNI bindings, background services, and native BLE channels.
# ---------------------------------------------------------------------------

# Flutter Engine & Embedding
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# iQube BLE Companion App Native Classes & Services
-keep class com.example.iqube_ble_app.** { *; }
-keep class com.example.iqube_ble_app.ScooterService { *; }
-keep class com.example.iqube_ble_app.NotificationRelayService { *; }
-keep class com.example.iqube_ble_app.CallStateReceiver { *; }
-keep class com.example.iqube_ble_app.EngineHolder { *; }

# FlutterBluePlus BLE Plugin
-keep class com.boskokg.flutter_blue_plus.** { *; }
-dontwarn com.boskokg.flutter_blue_plus.**

# Geolocator Location Plugin
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# Permission Handler Plugin
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# Shared Preferences Plugin
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Preserve Annotations & JNI Signatures
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes SourceFile,LineNumberTable

# Preserve native JNI methods
-keepclasseswithmembernames class * {
    native <methods>;
}

