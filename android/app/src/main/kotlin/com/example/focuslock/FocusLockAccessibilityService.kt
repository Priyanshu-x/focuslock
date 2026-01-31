package com.example.focuslock

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.content.Intent
import android.content.Context
import android.content.SharedPreferences
import android.widget.Toast
import android.view.KeyEvent

class FocusLockAccessibilityService : AccessibilityService() {

    private val PREFS_NAME = "FlutterSharedPreferences"
    private val KEY_IS_LOCKED = "flutter.isLocked" // 'flutter.' prefix is standard for shared_preferences plugin

    override fun onServiceConnected() {
        super.onServiceConnected()
        android.util.Log.d("FocusLockService", "Service Connected")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isLocked = prefs.getBoolean(KEY_IS_LOCKED, false)

        if (isLocked) {
             // Block Notification Shade and Recents
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                 val packageName = event.packageName?.toString()
                 if (packageName != null && packageName != this.packageName) {
                     // If user enters Recents (SystemUI) or any other app
                     // 1. Force close system dialogs/shade
                     performGlobalAction(GLOBAL_ACTION_DISMISS_NOTIFICATION_SHADE)
                     performGlobalAction(GLOBAL_ACTION_HOME) // Go Home (which should be us)
                     
                     // 2. Bring FocusLock to front immediately
                     bringAppToFront()
                 }
            }
        }
    }

    override fun onKeyEvent(event: KeyEvent): Boolean {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isLocked = prefs.getBoolean(KEY_IS_LOCKED, false)

        if (isLocked) {
            // Block Back, Home, Recents
            val action = event.action
            val keyCode = event.keyCode
            
            if (keyCode == KeyEvent.KEYCODE_BACK || 
                keyCode == KeyEvent.KEYCODE_HOME || 
                keyCode == KeyEvent.KEYCODE_APP_SWITCH) {
                return true // Consume the event
            }
        }
        return super.onKeyEvent(event)
    }

    private fun bringAppToFront() {
        val intent = Intent(this, MainActivity::class.java)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        startActivity(intent)
    }

    override fun onInterrupt() {
        // Required method
    }
}
