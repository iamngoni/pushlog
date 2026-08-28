package za.co.codecraftsolutions.pushlog

import android.app.Activity
import android.graphics.Typeface
import android.os.Bundle
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

class PermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        title = "Pushlog health data"

        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(32), dp(24), dp(32))
        }
        content.addView(TextView(this).apply {
            text = "Pushlog and Health Connect"
            textSize = 28f
            setTypeface(typeface, Typeface.BOLD)
        })
        content.addView(TextView(this).apply {
            text =
                "When Health Connect sync is enabled, Pushlog writes only " +
                "the live workouts you choose to save. Each record includes " +
                "the workout time, push-up count, and exercise type. When a " +
                "paired watch records a session, the saved record can also " +
                "include its heart-rate samples and calories burned.\n\n" +
                "Pushlog does not read your Health Connect data, use it for " +
                "advertising, or sell it. You can revoke access or delete " +
                "Pushlog records at any time in Health Connect settings."
            textSize = 17f
            setPadding(0, dp(20), 0, dp(24))
        })
        content.addView(Button(this).apply {
            text = "Done"
            setOnClickListener { finish() }
        }, ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
        ))

        setContentView(ScrollView(this).apply { addView(content) })
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()
}
