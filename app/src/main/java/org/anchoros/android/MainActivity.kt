package org.anchoros.android

import android.os.Bundle
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
