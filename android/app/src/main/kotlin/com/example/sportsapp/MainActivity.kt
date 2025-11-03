
package com.example.sportsapp

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "nfc_hce/channel"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAttendance" -> {
                    val payload = call.argument<String>("payload") ?: ""
                    val ttlSeconds = call.argument<Int>("ttlSeconds") ?: 30
                    HceService.startBroadcast(applicationContext, HceService.Mode.ATTENDANCE, payload, ttlSeconds)
                    result.success(null)
                }
                "startReward" -> {
                    val payload = call.argument<String>("payload") ?: ""
                    val ttlSeconds = call.argument<Int>("ttlSeconds") ?: 30
                    HceService.startBroadcast(applicationContext, HceService.Mode.REWARD, payload, ttlSeconds)
                    result.success(null)
                }
                "stop" -> {
                    HceService.stopBroadcast()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
