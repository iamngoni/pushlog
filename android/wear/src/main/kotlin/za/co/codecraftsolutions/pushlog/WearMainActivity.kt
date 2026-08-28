package za.co.codecraftsolutions.pushlog

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class WearMainActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var status: TextView
    private lateinit var timer: TextView
    private lateinit var reps: TextView
    private lateinit var heartRate: TextView
    private lateinit var calories: TextView
    private lateinit var pauseButton: Button

    private val refresh = object : Runnable {
        override fun run() {
            renderState()
            handler.postDelayed(this, 1_000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildContent())
        requestExercisePermissions()
        sendServiceAction(PushlogExerciseService.ACTION_SYNC)
    }

    override fun onResume() {
        super.onResume()
        handler.post(refresh)
    }

    override fun onPause() {
        handler.removeCallbacks(refresh)
        super.onPause()
    }

    private fun buildContent(): LinearLayout {
        val ink = Color.rgb(248, 245, 240)
        val secondary = Color.rgb(112, 109, 104)
        val accent = Color.rgb(215, 255, 31)
        val danger = Color.rgb(255, 77, 69)

        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(14), dp(10), dp(14), dp(12))
            setBackgroundColor(Color.rgb(10, 9, 8))

            status = label("PHONE READY", 10f, accent, Typeface.BOLD)
            addView(status)

            timer = label("00:00", 38f, ink, Typeface.BOLD)
            timer.setPadding(0, dp(8), 0, 0)
            addView(timer)

            reps = label("0 REPS", 12f, secondary, Typeface.BOLD)
            addView(reps)

            val metrics = LinearLayout(this@WearMainActivity).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
                setPadding(0, dp(8), 0, dp(8))
            }
            heartRate = label("-- BPM", 16f, ink, Typeface.BOLD)
            calories = label("-- CAL", 16f, ink, Typeface.BOLD)
            metrics.addView(heartRate, LinearLayout.LayoutParams(0, dp(44), 1f))
            metrics.addView(calories, LinearLayout.LayoutParams(0, dp(44), 1f))
            addView(metrics, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)

            val controls = LinearLayout(this@WearMainActivity).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER
            }
            pauseButton = Button(this@WearMainActivity).apply {
                text = "PAUSE"
                setTextColor(Color.BLACK)
                setBackgroundColor(accent)
                setOnClickListener {
                    val paused = preferences().getBoolean(PushlogExerciseService.KEY_PAUSED, false)
                    sendServiceAction(
                        if (paused) PushlogExerciseService.ACTION_RESUME
                        else PushlogExerciseService.ACTION_PAUSE,
                    )
                }
            }
            val end = Button(this@WearMainActivity).apply {
                text = "END"
                setTextColor(Color.WHITE)
                setBackgroundColor(danger)
                setOnClickListener { sendServiceAction(PushlogExerciseService.ACTION_END) }
            }
            controls.addView(pauseButton, LinearLayout.LayoutParams(0, dp(42), 1f))
            controls.addView(end, LinearLayout.LayoutParams(0, dp(42), 1f))
            addView(controls, ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        }
    }

    private fun renderState() {
        val prefs = preferences()
        val active = prefs.getBoolean(PushlogExerciseService.KEY_ACTIVE, false)
        val paused = prefs.getBoolean(PushlogExerciseService.KEY_PAUSED, false)
        val elapsed = prefs.getFloat(PushlogExerciseService.KEY_ELAPSED, 0f).toInt()
        val bpm = prefs.getFloat(PushlogExerciseService.KEY_HEART_RATE, 0f).toDouble()
        val kcal = prefs.getFloat(PushlogExerciseService.KEY_CALORIES, 0f).toDouble()
        val error = prefs.getString(PushlogExerciseService.KEY_ERROR, null)

        status.text = when {
            error != null -> "NEEDS ATTENTION"
            paused -> "PAUSED"
            active -> "TRACKING"
            else -> "START ON PHONE"
        }
        timer.text = "%02d:%02d".format(elapsed / 60, elapsed % 60)
        reps.text = "${prefs.getInt(PushlogExerciseService.KEY_REPS, 0)} REPS"
        heartRate.text = if (bpm > 0) "${bpm.toInt()} BPM" else "-- BPM"
        calories.text = if (kcal > 0) "${kcal.toInt()} CAL" else "-- CAL"
        pauseButton.text = if (paused) "RESUME" else "PAUSE"
        pauseButton.isEnabled = active
    }

    private fun requestExercisePermissions() {
        val permissions = mutableListOf(Manifest.permission.ACTIVITY_RECOGNITION)
        permissions += if (Build.VERSION.SDK_INT >= 36) {
            "android.permission.health.READ_HEART_RATE"
        } else {
            Manifest.permission.BODY_SENSORS
        }
        if (Build.VERSION.SDK_INT >= 33) permissions += Manifest.permission.POST_NOTIFICATIONS
        val missing = permissions.filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isNotEmpty()) requestPermissions(missing.toTypedArray(), PERMISSION_REQUEST)
    }

    private fun sendServiceAction(action: String) {
        startService(Intent(this, PushlogExerciseService::class.java).setAction(action))
    }

    private fun label(text: String, size: Float, color: Int, style: Int) =
        TextView(this).apply {
            this.text = text
            textSize = size
            setTextColor(color)
            gravity = Gravity.CENTER
            setTypeface(typeface, style)
        }

    private fun preferences() = getSharedPreferences(
        PushlogExerciseService.PREFERENCES,
        MODE_PRIVATE,
    )

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    private companion object {
        const val PERMISSION_REQUEST = 4702
    }
}
