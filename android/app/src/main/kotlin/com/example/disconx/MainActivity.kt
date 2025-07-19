package com.example.disconx

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val WIFI_CHANNEL = "com.dict.disconx/wifi"
    
    private lateinit var wifiController: WiFiController

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize Wi-Fi controller
        wifiController = WiFiController(this)
        
        // Set up method channel for Wi-Fi operations
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIFI_CHANNEL)
            .setMethodCallHandler(wifiController)
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::wifiController.isInitialized) {
            wifiController.cleanup()
        }
    }
}
