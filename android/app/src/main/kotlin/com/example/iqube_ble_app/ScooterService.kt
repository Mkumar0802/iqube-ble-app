package com.example.iqube_ble_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Foreground service that keeps the app (and its Flutter engine) alive so
 * the scooter stays connected with the app closed, like TVS Connect does.
 */
class ScooterService : Service() {
    companion object {
        private const val CHANNEL = "scooter"
        private const val ALERTS = "alerts"
        private const val NOTIFICATION_ID = 1
        private var status = "Looking for your iQube"

        fun start(context: Context) {
            context.startForegroundService(Intent(context, ScooterService::class.java))
        }

        fun setStatus(context: Context, text: String) {
            if (text == status) return
            status = text
            context.getSystemService(NotificationManager::class.java)
                .notify(NOTIFICATION_ID, notification(context))
        }

        /** A normal (dismissable) notification: ride summary, rain alert. */
        fun alert(context: Context, id: Int, title: String, text: String) {
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(NotificationChannel(
                ALERTS, "Ride summary & alerts", NotificationManager.IMPORTANCE_DEFAULT))
            val open = PendingIntent.getActivity(
                context, 0, Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE)
            manager.notify(NOTIFICATION_ID + 1 + id, Notification.Builder(context, ALERTS)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(Notification.BigTextStyle().bigText(text))
                .setContentIntent(open)
                .setAutoCancel(true)
                .build())
        }

        private fun notification(context: Context): Notification {
            val open = PendingIntent.getActivity(
                context, 0, Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE)
            return Notification.Builder(context, CHANNEL)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle("My iQube")
                .setContentText(status)
                .setContentIntent(open)
                .setOngoing(true)
                .build()
        }
    }

    override fun onCreate() {
        super.onCreate()
        getSystemService(NotificationManager::class.java).createNotificationChannel(
            NotificationChannel(CHANNEL, "Scooter connection", NotificationManager.IMPORTANCE_LOW))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Location lets the cluster weather follow the rider with the
            // app in the background. Android refuses it without location
            // permission, so fall back to the Bluetooth link alone.
            try {
                startForeground(NOTIFICATION_ID, notification(this),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE or
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            } catch (e: SecurityException) {
                startForeground(NOTIFICATION_ID, notification(this),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
            }
        } else {
            startForeground(NOTIFICATION_ID, notification(this))
        }
        EngineHolder.get(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int) = START_STICKY

    override fun onBind(intent: Intent?): IBinder? = null
}

/** Starts the service after a reboot, once a scooter has been paired. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        if (prefs.getString("flutter.deviceId", null) == null) return
        ScooterService.start(context)
    }
}
