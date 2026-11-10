package com.example.iqube_ble_app

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Shows the UI of the shared engine (see [EngineHolder]). Closing the app
 * keeps the engine running so ScooterService can stay connected.
 */
class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine =
        EngineHolder.get(context)

    override fun shouldDestroyEngineWithHost() = false
}
