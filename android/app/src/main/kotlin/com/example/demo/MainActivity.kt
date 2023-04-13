package com.example.demo

import android.content.Context
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {

  override fun provideFlutterEngine(context: Context): FlutterEngine? {
    return (applicationContext as App).engines.createAndRunDefaultEngine(context);
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    val binaryMessenger = flutterEngine.dartExecutor.binaryMessenger
    
    MethodChannel(binaryMessenger, "com.example.demo/isolate").apply {
      setMethodCallHandler { method, result ->
        if (method.method == "startService") {
                Log.i("MainActivity", "Starting service")
                ForegroundService.startService(this@MainActivity)
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
    }
  }
}
