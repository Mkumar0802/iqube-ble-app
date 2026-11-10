package com.example.iqube_ble_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.ContactsContract
import android.telephony.TelephonyManager

/**
 * Sends incoming calls to Flutter the moment the phone starts ringing, and
 * a "call_ended" event once it is answered or stops ringing.
 * The dialer's own notification can arrive only after the call ends, which
 * is too late for the cluster. Needs READ_PHONE_STATE and READ_CALL_LOG
 * (for the number) and READ_CONTACTS (for the name).
 */
class CallStateReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.getStringExtra(TelephonyManager.EXTRA_STATE) !=
            TelephonyManager.EXTRA_STATE_RINGING) {
            // Answered (OFFHOOK) or ended (IDLE): stop showing the call.
            NotificationRelayService.post(mapOf(
                "package" to "phone_state", "title" to "", "text" to "",
                "category" to "call_ended"))
            return
        }
        // Android sends RINGING twice; only the one with READ_CALL_LOG has the number.
        @Suppress("DEPRECATION")
        val number = intent.getStringExtra(TelephonyManager.EXTRA_INCOMING_NUMBER) ?: return
        val event = mapOf(
            "package" to "phone_state",
            "title" to (contactName(context, number) ?: number),
            "text" to "",
            "category" to "call",
        )
        NotificationRelayService.post(event)
    }

    private fun contactName(context: Context, number: String): String? = try {
        val uri = Uri.withAppendedPath(
            ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(number))
        context.contentResolver.query(
            uri, arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME), null, null, null
        )?.use { if (it.moveToFirst()) it.getString(0) else null }
    } catch (e: SecurityException) {
        null
    }
}
