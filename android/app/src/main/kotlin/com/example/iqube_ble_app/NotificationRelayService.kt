package com.example.iqube_ble_app

import android.app.Notification
import android.content.ComponentName
import android.media.MediaMetadata
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Handler
import android.os.Looper
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import io.flutter.plugin.common.EventChannel

/**
 * Receives every posted notification (once the user grants Notification
 * access) and forwards the basics to Flutter, which decides what to send
 * to the scooter's cluster. Notification access also lets it follow the
 * phone's media sessions, so the playing song is forwarded too.
 */
class NotificationRelayService : NotificationListenerService() {
    companion object {
        var sink: EventChannel.EventSink? = null
        private val main = Handler(Looper.getMainLooper())

        fun post(event: Map<String, Any>) {
            main.post { sink?.success(event) }
        }
    }

    private var sessions: MediaSessionManager? = null
    private var controller: MediaController? = null
    private var lastSong: Map<String, Any>? = null

    private val sessionsChanged =
        MediaSessionManager.OnActiveSessionsChangedListener { follow(it) }

    private val mediaCallback = object : MediaController.Callback() {
        override fun onMetadataChanged(metadata: MediaMetadata?) = postSong()
        override fun onPlaybackStateChanged(state: PlaybackState?) = postSong()
    }

    override fun onListenerConnected() {
        val manager = getSystemService(MediaSessionManager::class.java) ?: return
        val me = ComponentName(this, NotificationRelayService::class.java)
        manager.addOnActiveSessionsChangedListener(sessionsChanged, me)
        sessions = manager
        follow(manager.getActiveSessions(me))
    }

    override fun onListenerDisconnected() {
        sessions?.removeOnActiveSessionsChangedListener(sessionsChanged)
        controller?.unregisterCallback(mediaCallback)
        controller = null
    }

    /** Follows the playing session, or else the most recent one. */
    private fun follow(active: List<MediaController>?) {
        val next = active?.firstOrNull { it.playbackState?.state == PlaybackState.STATE_PLAYING }
            ?: active?.firstOrNull()
        if (next?.sessionToken == controller?.sessionToken) return
        controller?.unregisterCallback(mediaCallback)
        controller = next
        next?.registerCallback(mediaCallback, main)
        postSong()
    }

    private fun postSong() {
        val c = controller
        val meta = c?.metadata
        val song = mapOf(
            "package" to "media",
            "category" to "media",
            "app" to (c?.packageName ?: ""),
            "title" to (meta?.getString(MediaMetadata.METADATA_KEY_TITLE) ?: ""),
            "text" to (meta?.getString(MediaMetadata.METADATA_KEY_ARTIST) ?: ""),
            "playing" to (c?.playbackState?.state == PlaybackState.STATE_PLAYING),
        )
        if (song == lastSong) return
        lastSong = song
        post(song)
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val n = sbn.notification ?: return
        if (n.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        val extras = n.extras ?: return
        val event = mapOf(
            "package" to sbn.packageName,
            "title" to (extras.getCharSequence(Notification.EXTRA_TITLE)?.toString() ?: ""),
            "text" to (extras.getCharSequence(Notification.EXTRA_TEXT)?.toString() ?: ""),
            "subText" to (extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString() ?: ""),
            "category" to (n.category ?: ""),
            // Every text extra and the timestamp: Google Maps does not
            // always put the trip ("14 min · 3.8 km") in the sub-text.
            "extras" to extras.keySet().mapNotNull { k ->
                @Suppress("DEPRECATION")
                val v = extras.get(k)
                if (v is CharSequence) k to v.toString() else null
            }.toMap(),
            "when" to n.`when`,
            "countDown" to extras.getBoolean(Notification.EXTRA_CHRONOMETER_COUNT_DOWN),
        )
        post(event)
    }

    // Lets Flutter know when Google Maps navigation (an ongoing
    // notification) ends.
    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        if (sbn.notification.flags and Notification.FLAG_ONGOING_EVENT == 0) return
        post(mapOf("package" to sbn.packageName, "category" to "removed"))
    }
}
