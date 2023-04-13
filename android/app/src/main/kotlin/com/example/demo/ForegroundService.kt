package com.example.demo

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

class ForegroundService : Service() {

    private var flutterEngine: FlutterEngine? = null

    override fun onCreate() {
        Log.i(TAG, "Creating foreground service.")
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {

        val manager =
            this.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val groups = listOf(
                NotificationChannelGroup(
                    "services", "Services"
                )
            )

            val channels = listOf(
                NotificationChannel(
                "foreground_service",
                "Status",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                group = "services"
                setShowBadge(false)
            })

            manager.createNotificationChannelGroups(groups)
            manager.createNotificationChannels(channels)


        val id = 1
        val notification = NotificationCompat
        .Builder(this, "foreground_service")
        .setPriority(NotificationCompat.PRIORITY_LOW)
        .setContentTitle("Notification")
        .setContentText("content")
        .setOngoing(true)
        .build()

        startForeground(id, notification)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "Starting foreground service.")

        startFlutterNativeView()

        return START_STICKY
    }

    override fun onBind(intent: Intent): IBinder? = null


    private fun startFlutterNativeView() {
        if (flutterEngine != null) return

        Log.i(TAG, "Starting foreground service isolate.");

        val appBundlePath =
            FlutterInjector.instance().flutterLoader().findAppBundlePath()

        Log.i(TAG, "Executing background entrypoint from $appBundlePath.")

        val entryPoint = DartExecutor.DartEntrypoint(appBundlePath, "package:demo/main.dart", "background")

        flutterEngine = (applicationContext as App).engines.createAndRunEngine(this, entryPoint)
    }

    private fun stopFlutterNativeView() {
        Log.i(TAG, "Stopping foreground service isolate.")
        flutterEngine?.destroy()
        flutterEngine = null
    }

    companion object {
        private const val TAG = "ForegroundService"

        fun startService(context: Context) {
            val intent =
                Intent(context, ForegroundService::class.java)

            ContextCompat.startForegroundService(context, intent)
        }
    }
}
