package org.anchoros.android

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity

/**
 * Main Activity - Displays the Anchor Engine web UI
 * 
 * This is a simple WebView wrapper that points to the local engine API.
 * The engine runs in a background service on localhost:3160.
 */
class MainActivity : AppCompatActivity() {
    
    private lateinit var webView: WebView
    /** True once we have sent the user to the "All files access" settings page. */
    private var storagePermissionRequested = false
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Start the engine service
        EngineService.start(this)
        
        // Create WebView programmatically
        webView = WebView(this).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            webViewClient = WebViewClient()
            
            // Load the local engine UI
            // Once the engine is running, it serves a static UI at /static
            // For now, we'll show a loading page
            loadUrl("http://localhost:3160/")
        }
        
        setContentView(webView)
    }
    
    override fun onResume() {
        super.onResume()
        // On Android 11+ (API 30+), MANAGE_EXTERNAL_STORAGE cannot be granted via the
        // normal permission dialog. We must send the user to the system settings page.
        // We only do this once per session to avoid an infinite redirect loop when the
        // user returns from settings without granting the permission.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R &&
            !Environment.isExternalStorageManager() &&
            !storagePermissionRequested
        ) {
            storagePermissionRequested = true
            val intent = Intent(
                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                Uri.fromParts("package", packageName, null)
            )
            startActivity(intent)
        }
    }
    
    override fun onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        // Keep the service running in background
        // EngineService.stop(this) // Uncomment if you want to stop on exit
    }
}
