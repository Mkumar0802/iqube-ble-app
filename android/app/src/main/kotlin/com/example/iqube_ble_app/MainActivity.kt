package com.example.iqube_ble_app

import android.content.Context
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Shows the UI of the shared engine (see [EngineHolder]). Closing the app
 * keeps the engine running so ScooterService can stay connected.
 *
 * Configures the display mode to unlock the hardware's maximum refresh rate
 * (e.g., 90Hz, 120Hz, 144Hz) for ultra-smooth rendering.
 */
class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine =
        EngineHolder.get(context)

    override fun shouldDestroyEngineWithHost() = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableMaxRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        enableMaxRefreshRate()
    }

    /**
     * Unlocks the display refresh rate from standard 60Hz up to the maximum
     * supported by the phone's hardware (90Hz, 120Hz ProMotion, 144Hz).
     */
    private fun enableMaxRefreshRate() {
        // Android 6 (API 23)+: Set the preferred display mode to the highest refresh rate mode
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val currentDisplay = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    display
                } else {
                    @Suppress("DEPRECATION")
                    windowManager.defaultDisplay
                }

                val modes = currentDisplay?.supportedModes
                if (!modes.isNullOrEmpty()) {
                    val maxMode = modes.maxByOrNull { it.refreshRate }
                    if (maxMode != null) {
                        val params = window.attributes
                        params.preferredDisplayModeId = maxMode.modeId
                        params.preferredRefreshRate = maxMode.refreshRate
                        window.attributes = params
                    }
                }
            } catch (_: Exception) {}
        }
    }
}
