package org.anchoros.android

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File

/**
 * Background Service that runs the Anchor Engine (Node.js)
 * 
 * This service:
 * 1. Bundles the Node.js runtime via nodejs-mobile
 * 2. Starts the engine on localhost:3160
 * 3. Runs as a foreground service to avoid being killed
 * 4. Manages the mirrored_brain/ directory
 */
class EngineService : Service() {
    
    companion object {
        private const val TAG = "EngineService"
        private const val NOTIFICATION_ID = 1
        private const val CHANNEL_ID = "anchor_engine_channel"
        
        fun start(context: Context) {
            val intent = Intent(context, EngineService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }
        
        fun stop(context: Context) {
            val intent = Intent(context, EngineService::class.java)
            context.stopService(intent)
        }
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "Starting Anchor Engine service")
        
        // Create notification for foreground service
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        // Initialize the engine
        // This would normally call nodejs-mobile to start Node.js
        // For now, we'll just log it
        initializeEngine()
        
        return START_STICKY
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Anchor Engine",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Runs the Anchor knowledge engine in the background"
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Anchor Engine")
            .setContentText("Running on port 3160")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
    
    private fun initializeEngine() {
        // This is where we'd integrate with nodejs-mobile
        // The basic flow:
        // 1. Copy Node.js assets from APK to app storage
        // 2. Copy engine JavaScript from assets/ to app storage
        // 3. Start Node.js runtime with engine script
        // 4. Wait for engine to be ready on port 3160
        
        // For the prototype, you would:
        // - Add nodejs-mobile as a dependency
        // - Bundle the engine code in assets/
        // - Call NodeJSMobile.start() with the engine script
        
        Log.i(TAG, "Engine initialization would happen here")
        Log.i(TAG, "In production, this starts Node.js via nodejs-mobile")
        
        // Simulate engine startup
        setupMirroredBrain()
    }
    
    private fun setupMirroredBrain() {
        // Create the mirrored_brain directory in app storage
        val mirroredBrain = File(filesDir, "mirrored_brain")
        if (!mirroredBrain.exists()) {
            mirroredBrain.mkdirs()
            Log.i(TAG, "Created mirrored_brain directory: ${mirroredBrain.absolutePath}")
        }
        
        // This is where GitHub tarballs would be unpacked
        val githubDir = File(mirroredBrain, "github")
        if (!githubDir.exists()) {
            githubDir.mkdirs()
        }
    }
    
    override fun onDestroy() {
        Log.i(TAG, "Stopping Anchor Engine service")
        // Clean shutdown of Node.js runtime would happen here
        super.onDestroy()
    }
}
