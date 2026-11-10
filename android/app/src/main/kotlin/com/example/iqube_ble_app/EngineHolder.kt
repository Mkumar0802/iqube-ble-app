package com.example.iqube_ble_app

import android.content.Context
import android.content.Intent
import android.location.Geocoder
import android.media.AudioManager
import android.view.KeyEvent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * One Flutter engine for the whole app. ScooterService starts it so the
 * scooter connection, heartbeat and cluster notifications keep running with
 * the app closed. MainActivity shows its UI on the same engine.
 */
object EngineHolder {
    private const val ID = "main"

    fun get(context: Context): FlutterEngine {
        FlutterEngineCache.getInstance().get(ID)?.let { return it }
        val app = context.applicationContext
        val engine = FlutterEngine(app)
        setupChannels(engine, app)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ID, engine)
        return engine
    }

    private fun setupChannels(engine: FlutterEngine, app: Context) {
        val messenger = engine.dartExecutor.binaryMessenger

        EventChannel(messenger, "iqube/notifications").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink) {
                    NotificationRelayService.sink = events
                }

                override fun onCancel(args: Any?) {
                    NotificationRelayService.sink = null
                }
            })

        MethodChannel(messenger, "iqube/notification_access").setMethodCallHandler { call, result ->
            when (call.method) {
                "isEnabled" -> {
                    val enabled = Settings.Secure.getString(
                        app.contentResolver, "enabled_notification_listeners") ?: ""
                    result.success(enabled.contains(app.packageName))
                }
                "openSettings" -> {
                    app.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Area name for the cluster, e.g. "Kamaraja Puram". Geocoder blocks,
        // so it runs off the main thread.
        val main = Handler(Looper.getMainLooper())
        MethodChannel(messenger, "iqube/geo").setMethodCallHandler { call, result ->
            if (call.method != "placeName") return@setMethodCallHandler result.notImplemented()
            val lat = call.argument<Double>("lat") ?: 0.0
            val lon = call.argument<Double>("lon") ?: 0.0
            Thread {
                val name = try {
                    @Suppress("DEPRECATION")
                    Geocoder(app).getFromLocation(lat, lon, 1)?.firstOrNull()?.let {
                        it.subLocality ?: it.locality ?: it.featureName
                    }
                } catch (e: Exception) {
                    null
                }
                main.post { result.success(name) }
            }.start()
        }

        // Media keys for the cluster's music buttons, as TVS Connect does.
        MethodChannel(messenger, "iqube/media").setMethodCallHandler { call, result ->
            val audio = app.getSystemService(AudioManager::class.java)
            fun key(code: Int) {
                audio.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, code))
                audio.dispatchMediaKeyEvent(KeyEvent(KeyEvent.ACTION_UP, code))
            }
            when (call.method) {
                "play" -> key(KeyEvent.KEYCODE_MEDIA_PLAY)
                "pause" -> key(KeyEvent.KEYCODE_MEDIA_PAUSE)
                "toggle" -> key(KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
                "next" -> key(KeyEvent.KEYCODE_MEDIA_NEXT)
                "previous" -> key(KeyEvent.KEYCODE_MEDIA_PREVIOUS)
                "volumeUp" -> audio.adjustStreamVolume(
                    AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, 0)
                "volumeDown" -> audio.adjustStreamVolume(
                    AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, 0)
                // TVS Connect opens its voice assistant on this button.
                "assistant" -> app.startActivity(Intent(Intent.ACTION_VOICE_COMMAND)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                else -> return@setMethodCallHandler result.notImplemented()
            }
            result.success(null)
        }

        MethodChannel(messenger, "iqube/service").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    ScooterService.start(app)
                    result.success(null)
                }
                "status" -> {
                    ScooterService.setStatus(app, call.argument<String>("text") ?: "")
                    result.success(null)
                }
                "alert" -> {
                    ScooterService.alert(app, call.argument<Int>("id") ?: 0,
                        call.argument<String>("title") ?: "",
                        call.argument<String>("text") ?: "")
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
