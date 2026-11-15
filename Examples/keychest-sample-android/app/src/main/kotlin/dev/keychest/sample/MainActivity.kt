package dev.keychest.sample

import android.app.Activity
import android.graphics.Typeface
import android.os.Bundle
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import dev.keychest.sample.keys.Secrets
import dev.keychest.sample.keys.SecretsEnvironment

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Secrets.Global, Secrets.Debug and Secrets.Release come from the generated keychest-keys module.
        // Pick the environment that matches the build type.
        val secrets: SecretsEnvironment = if (BuildConfig.DEBUG) Secrets.Debug else Secrets.Release
        val buildType = if (BuildConfig.DEBUG) "debug" else "release"

        val padding = dp(24)
        val column = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(padding, padding, padding, padding)
            addView(label("Keychest sample", size = 24f, bold = true))
            addView(label("Build type: $buildType", top = 4))
            addView(label("clientID (global)", size = 12f, top = 24))
            addView(label(Secrets.Global.clientID, mono = true))
            addView(label("apiKey ($buildType)", size = 12f, top = 16))
            addView(label(secrets.apiKey, mono = true))
        }

        // The outer layout keeps the content clear of the system bars.
        setContentView(FrameLayout(this).apply {
            fitsSystemWindows = true
            addView(column)
        })
    }

    private fun label(text: String, size: Float = 16f, bold: Boolean = false, mono: Boolean = false, top: Int = 0) =
        TextView(this).apply {
            this.text = text
            textSize = size
            setPadding(0, dp(top), 0, 0)
            if (bold) setTypeface(typeface, Typeface.BOLD)
            if (mono) typeface = Typeface.MONOSPACE
        }

    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
}
