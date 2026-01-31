package com.example.focuslock

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.view.WindowManager
import android.graphics.PixelFormat
import android.view.Gravity
import android.view.View
import android.graphics.Color
import android.widget.TextView
import android.widget.Toast

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.focuslock/detox"
    private lateinit var devicePolicyManager: DevicePolicyManager
    private lateinit var adminComponentName: ComponentName
    private var overlayView: View? = null

    companion object {
        const val REQUEST_CODE_ENABLE_ADMIN = 1
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        adminComponentName = ComponentName(this, FocusLockDeviceAdminReceiver::class.java)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "startLockTask" -> {
                     // Try to start Lock Task.
                     // If Device Owner, this enters strict Kiosk mode.
                     // If not, it enters standard Screen Pinning (which can be bypassed).
                    try {
                        if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
                             // Correctly whitelist before locking if we are DO
                             devicePolicyManager.setLockTaskPackages(adminComponentName, arrayOf(packageName))
                        }
                        
                        startLockTask()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("LOCK_FAILED", "Failed to start lock task: ${e.message}", null)
                    }
                }
                "stopLockTask" -> {
                    try {
                        stopLockTask()
                        result.success(null)
                    } catch (e: Exception) {
                         result.error("UNLOCK_FAILED", "Failed to stop lock task: ${e.message}", null)
                    }
                }
                "enableDeviceAdmin" -> {
                    val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                    intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponentName)
                    intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "FocusLock needs to be a device administrator to enable lock task mode.")
                    startActivityForResult(intent, REQUEST_CODE_ENABLE_ADMIN)
                    result.success(null)
                }
                "isLockTaskPermitted" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                        result.success(devicePolicyManager.isLockTaskPermitted(packageName))
                    } else {
                        result.success(false)
                    }
                }
                "isInLockTaskMode" -> {
                    val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val lockTaskMode = activityManager.lockTaskModeState
                        result.success(lockTaskMode != ActivityManager.LOCK_TASK_MODE_NONE)
                    } else {
                         // Fallback for older APIs
                        result.success(activityManager.isInLockTaskMode)
                    }
                }
                "bringAppToForeground" -> {
                    val intent = Intent(this, MainActivity::class.java).apply {
                        action = Intent.ACTION_MAIN
                        addCategory(Intent.CATEGORY_LAUNCHER)
                        addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(null)
                }
                "openAccessibilitySettings" -> {
                    val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    startActivity(intent)
                    result.success(null)
                }
                "isDeviceOwner" -> {
                    result.success(devicePolicyManager.isDeviceOwnerApp(packageName))
                }
                "checkMultiWindow" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        result.success(isInMultiWindowMode || isInPictureInPictureMode)
                    } else {
                        result.success(false)
                    }
                }
                "setBackGestureExclusion" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val view = window.decorView
                        view.post {
                            val exclusionRects = listOf(
                                android.graphics.Rect(0, 0, view.width, 200), // Top
                                android.graphics.Rect(0, 0, 200, view.height), // Left
                                android.graphics.Rect(view.width - 200, 0, view.width, view.height), // Right
                                android.graphics.Rect(0, view.height - 200, view.width, view.height) // Bottom
                            )
                            view.systemGestureExclusionRects = exclusionRects
                        }
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "getRealScreenSize" -> {
                    val metrics = android.util.DisplayMetrics()
                    windowManager.defaultDisplay.getRealMetrics(metrics)
                    result.success(mapOf("width" to metrics.widthPixels, "height" to metrics.heightPixels))
                }
                "showOverlay" -> {
                    if (android.provider.Settings.canDrawOverlays(this)) {
                        showBlockingOverlay()
                        result.success(true)
                    } else {
                        result.error("PERMISSION_DENIED", "Overlay permission not granted", null)
                    }
                }
                "hideOverlay" -> {
                    hideBlockingOverlay()
                    result.success(true)
                }
                "checkOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        result.success(android.provider.Settings.canDrawOverlays(this))
                    } else {
                        result.success(true)
                    }
                }
                "maxVolume" -> { // Alias fix if needed, or just keep setMaxVolume
                     // ...
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            // Try specific package
                            val intent = Intent(android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION, 
                                                android.net.Uri.parse("package:$packageName"))
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                        } catch (e: Exception) {
                            // Fallback to generic list
                            try {
                                val intent = Intent(android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                startActivity(intent)
                            } catch (e2: Exception) {
                                // Failed completely
                                android.util.Log.e(CHANNEL, "Failed to open overlay settings: $e2")
                            }
                        }
                        result.success(null)
                    } else {
                        result.success(null)
                    }
                }
                "isAdminActive" -> {
                    result.success(devicePolicyManager.isAdminActive(adminComponentName))
                }
                "isAccessibilityEnabled" -> {
                    val enabledServices = android.provider.Settings.Secure.getString(contentResolver, android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
                    val componentName = ComponentName(this, FocusLockAccessibilityService::class.java).flattenToString()
                    result.success(enabledServices?.contains(componentName) == true)
                }
                "setMaxVolume" -> {
                    val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                    val maxVolume = audioManager.getStreamMaxVolume(android.media.AudioManager.STREAM_MUSIC)
                    audioManager.setStreamVolume(android.media.AudioManager.STREAM_MUSIC, maxVolume, 0)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun showBlockingOverlay() {
        if (overlayView != null) return // Already showing

        val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) 
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY 
            else 
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or 
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or 
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            PixelFormat.TRANSLUCENT
        )
        params.gravity = Gravity.CENTER

        val view = TextView(this)
        view.text = "FOCUS DETOX\nGo back to the app!"
        view.textSize = 24f
        view.setTextColor(Color.WHITE)
        view.setBackgroundColor(Color.BLACK)
        view.gravity = Gravity.CENTER
        
        view.setOnClickListener {
            // Bring main activity to front on click
            val intent = Intent(this, MainActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            startActivity(intent)
        }

        windowManager.addView(view, params)
        overlayView = view
    }

    private fun hideBlockingOverlay() {
        if (overlayView != null) {
            val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            windowManager.removeView(overlayView)
            overlayView = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_ENABLE_ADMIN) {
            if (resultCode == RESULT_OK) {
                Toast.makeText(this, "Device Admin Enabled", Toast.LENGTH_SHORT).show()
            } else {
                Toast.makeText(this, "Device Admin Activation Failed", Toast.LENGTH_SHORT).show()
            }
        }
    }
}
