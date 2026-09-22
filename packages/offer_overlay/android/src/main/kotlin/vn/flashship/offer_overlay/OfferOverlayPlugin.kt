package vn.flashship.offer_overlay

import android.app.Activity
import android.app.Application
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.view.Gravity
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/** Registered on both UI and FCM engines; the window is shared by the process. */
class OfferOverlayPlugin : FlutterPlugin {
    private lateinit var channel: MethodChannel
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        Overlay.install(context)
        channel = MethodChannel(binding.binaryMessenger, "flashship/offer_overlay")
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "allowed" -> result.success(Settings.canDrawOverlays(context))
                    "xiaomi" -> result.success(Build.MANUFACTURER.equals("xiaomi", true) ||
                        Build.BRAND.equals("redmi", true) || Build.BRAND.equals("poco", true))
                    "autostartSettings", "batterySettings" -> {
                        val intent = if (call.method == "autostartSettings")
                            Intent().setClassName("com.miui.securitycenter",
                                "com.miui.permcenter.autostart.AutoStartManagementActivity")
                        else Intent().setClassName("com.miui.powerkeeper",
                            "com.miui.powerkeeper.ui.HiddenAppsConfigActivity")
                            .putExtra("package_name", context.packageName)
                            .putExtra("package_label", "Flash Driver")
                        try {
                            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        } catch (_: Exception) {
                            context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:${context.packageName}"))
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        }
                        result.success(true)
                    }
                    "googleMaps" -> {
                        val destination = call.argument<String>("destination")?.trim().orEmpty()
                        if (destination.isBlank()) {
                            result.success(false)
                        } else {
                            val navigation = Intent(Intent.ACTION_VIEW,
                                Uri.parse("google.navigation:q=${Uri.encode(destination)}&mode=d"))
                                .setPackage("com.google.android.apps.maps")
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            try {
                                context.startActivity(navigation)
                                result.success(true)
                            } catch (_: Exception) {
                                val web = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=${Uri.encode(destination)}&travelmode=driving")
                                try {
                                    context.startActivity(Intent(Intent.ACTION_VIEW, web)
                                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                                    result.success(true)
                                } catch (_: Exception) {
                                    result.success(false)
                                }
                            }
                        }
                    }
                    "ring" -> result.success(LockedOfferRinger.start(context,
                        call.argument<String>("order_code") ?: "",
                        call.argument<Any>("expires_at")?.toString()?.toLongOrNull() ?: 0))
                    "locked" -> result.success(
                        (context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked ||
                        !(context.getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive)
                    "settings" -> {
                        context.startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:${context.packageName}"))
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                        result.success(true)
                    }
                    "show" -> result.success(Overlay.show(context,
                        call.argument<String>("order_code") ?: "",
                        call.argument<Any>("expires_at")?.toString()?.toLongOrNull() ?: 0,
                        call.argument<String>("view_url") ?: ""))
                    "hide" -> { Overlay.hide(call.argument<String>("order_code")); result.success(true) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("overlay", e.message, null)
            }
        }
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}

private object Overlay : Application.ActivityLifecycleCallbacks {
    private val handler = Handler(Looper.getMainLooper())
    private var installed = false
    private val resumed = mutableSetOf<Activity>()
    private var window: LinearLayout? = null
    private var manager: WindowManager? = null
    private var code: String? = null
    private var ticker: Runnable? = null
    private var player: MediaPlayer? = null
    private val withdrawn = mutableMapOf<String, Long>()
    fun canRing(orderCode: String): Boolean = resumed.isEmpty() &&
        (withdrawn[orderCode] ?: 0L) <= System.currentTimeMillis()

    fun install(context: Context) {
        if (!installed) {
            (context.applicationContext as Application).registerActivityLifecycleCallbacks(this)
            installed = true
        }
    }

    private fun unlocked(context: Context): Boolean =
        (context.getSystemService(Context.POWER_SERVICE) as PowerManager).isInteractive &&
        !(context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked

    fun show(context: Context, orderCode: String, expiresAt: Long, viewUrl: String): Boolean {
        val deadline = expiresAt * 1000
        withdrawn.entries.removeAll { it.value < System.currentTimeMillis() }
        if (withdrawn.containsKey(orderCode)) return false
        if (orderCode.isBlank() || deadline <= System.currentTimeMillis() ||
            resumed.isNotEmpty() || !unlocked(context) || !Settings.canDrawOverlays(context)) return false
        hide()
        fun dp(value: Int) = (value * context.resources.displayMetrics.density).toInt()
        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(10), dp(16), dp(10))
            elevation = dp(12).toFloat()
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = dp(14).toFloat()
                setStroke(dp(1), Color.rgb(230, 81, 0))
            }
        }
        val title = TextView(context).apply {
            text = "Có đơn mới"
            textSize = 17f
            setTextColor(Color.rgb(180, 60, 0))
        }
        val countdown = TextView(context).apply {
            textSize = 14f
            setTextColor(Color.DKGRAY)
        }
        val action = TextView(context).apply {
            text = "Click xem đơn"
            textSize = 14f
            setTextColor(Color.rgb(230, 81, 0))
            gravity = Gravity.END
        }
        val infoRow = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            addView(countdown, LinearLayout.LayoutParams(
                0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            addView(action, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT))
        }
        card.addView(title)
        card.addView(infoRow)
        card.setOnClickListener {
            if (System.currentTimeMillis() >= deadline || !unlocked(context)) {
                hide()
                return@setOnClickListener
            }
            postViewed(viewUrl)
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (intent != null) {
                // Launch while the user-clicked overlay is still visible.
                try { context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)) }
                catch (_: Exception) { /* Notification remains available. */ }
            }
            hide()
        }
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        @Suppress("DEPRECATION")
        val type = if (Build.VERSION.SDK_INT >= 26) WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else WindowManager.LayoutParams.TYPE_PHONE
        val params = WindowManager.LayoutParams(
            context.resources.displayMetrics.widthPixels - dp(24),
            WindowManager.LayoutParams.WRAP_CONTENT, type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE, PixelFormat.TRANSLUCENT).apply {
                gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
                y = dp(72)
            }
        try { wm.addView(card, params) } catch (_: Exception) { return false }
        window = card
        manager = wm
        code = orderCode
        val soundId = context.resources.getIdentifier("order_offer", "raw", context.packageName)
        val soundDeadline = minOf(deadline, System.currentTimeMillis() + 25000)
        if (soundId != 0) {
            try {
                val attributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                player = MediaPlayer.create(context, soundId, attributes, 0)?.apply {
                    isLooping = true
                    start()
                }
            } catch (_: Exception) { player = null }
        }
        val tick = object : Runnable {
            override fun run() {
                val now = System.currentTimeMillis()
                val remaining = deadline - now
                if (remaining <= 0 || !unlocked(context) || !Settings.canDrawOverlays(context)) { hide(); return }
                if (now >= soundDeadline) stopSound()
                countdown.text = "Còn ${(remaining + 999) / 1000} giây"
                handler.postDelayed(this, 250)
            }
        }
        ticker = tick
        tick.run()
        return true
    }

    private fun postViewed(url: String) {
        if (!url.startsWith("https://") && !url.startsWith("http://")) return
        thread(name = "offer-viewed", isDaemon = true) {
            try {
                val connection = URL(url).openConnection() as HttpURLConnection
                connection.requestMethod = "POST"
                connection.connectTimeout = 3000
                connection.readTimeout = 3000
                connection.doOutput = true
                connection.outputStream.use { }
                connection.responseCode
                connection.disconnect()
            } catch (_: Exception) { }
        }
    }

    fun hide(expectedCode: String? = null) {
        LockedOfferRinger.stop(expectedCode)
        // A delayed FCM must not recreate an offer already withdrawn by RTDB.
        if (expectedCode != null) withdrawn[expectedCode] = System.currentTimeMillis() + 60000
        if (expectedCode != null && expectedCode != code) return
        ticker?.let { handler.removeCallbacks(it) }
        ticker = null
        stopSound()
        window?.let { try { manager?.removeView(it) } catch (_: Exception) {} }
        window = null
        manager = null
        code = null
    }
    private fun stopSound() {
        player?.let { try { it.stop(); it.release() } catch (_: Exception) {} }
        player = null
    }
    override fun onActivityResumed(activity: Activity) { resumed.add(activity); hide() }
    override fun onActivityPaused(activity: Activity) { resumed.remove(activity) }
    override fun onActivityDestroyed(activity: Activity) { resumed.remove(activity) }
    override fun onActivityCreated(activity: Activity, state: Bundle?) {}
    override fun onActivityStarted(activity: Activity) {}
    override fun onActivityStopped(activity: Activity) {}
    override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) {}
}

/** Audio belongs to the offer, not the system notification shade. */
private object LockedOfferRinger {
    private val handler = Handler(Looper.getMainLooper())
    private var player: MediaPlayer? = null
    private var code: String? = null
    private var timeout: Runnable? = null

    fun start(context: Context, orderCode: String, expiresAt: Long): Boolean {
        val remaining = minOf(25000L, expiresAt * 1000 - System.currentTimeMillis())
        if (remaining <= 0 || orderCode.isBlank() || !Overlay.canRing(orderCode)) return false
        if (code == orderCode && player != null) return true
        stop()
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
        val notifications = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
        // Respect silent/vibrate mode and Do Not Disturb.
        if (audio.ringerMode != android.media.AudioManager.RINGER_MODE_NORMAL ||
            notifications.currentInterruptionFilter != android.app.NotificationManager.INTERRUPTION_FILTER_ALL) return false
        val soundId = context.resources.getIdentifier("order_offer", "raw", context.packageName)
        if (soundId == 0) return false
        try {
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
            val sound = MediaPlayer.create(context, soundId, attributes, 0) ?: return false
            player = sound
            code = orderCode
            sound.setWakeMode(context, PowerManager.PARTIAL_WAKE_LOCK)
            sound.isLooping = true
            sound.start()
            val finish = Runnable { stop(orderCode) }
            timeout = finish
            handler.postDelayed(finish, remaining)
            return true
        } catch (_: Exception) {
            stop()
            return false
        }
    }

    fun stop(expectedCode: String? = null) {
        if (expectedCode != null && expectedCode != code) return
        timeout?.let { handler.removeCallbacks(it) }
        timeout = null
        player?.let { sound ->
            try { sound.stop() } catch (_: Exception) {}
            sound.release()
        }
        player = null
        code = null
    }
}
