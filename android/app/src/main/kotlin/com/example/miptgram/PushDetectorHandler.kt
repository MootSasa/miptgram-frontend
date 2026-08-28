package com.example.miptgram

import android.content.Context
import android.content.pm.PackageManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * MethodChannel handler for push service detection.
 * 
 * Detects availability of:
 * - Google Play Services (GMS) → FCM
 * - HMS Core → Huawei Push Kit
 * 
 * Uses PackageManager instead of SDK classes to avoid
 * compile-time dependencies on GMS/HMS libraries.
 */
class PushDetectorHandler(private val context: Context) {

    companion object {
        private const val PUSH_DETECTOR_CHANNEL = "com.example.miptgram/push_detector"
        private const val HMS_PUSH_CHANNEL = "com.example.miptgram/hms_push"
    }

    fun setup(flutterEngine: FlutterEngine) {
        // Push detector channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PUSH_DETECTOR_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isGmsAvailable" -> {
                        result.success(isGmsAvailable())
                    }
                    "isHmsAvailable" -> {
                        result.success(isHmsAvailable())
                    }
                    else -> result.notImplemented()
                }
            }

        // HMS Push channel (placeholder — actual HMS Push handled by Flutter plugin)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HMS_PUSH_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> result.success(true)
                    "getToken" -> result.success(null)
                    "deleteToken" -> result.success(true)
                    "subscribeToTopic" -> result.success(true)
                    "unsubscribeFromTopic" -> result.success(true)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Check if Google Play Services are available on this device.
     * Uses PackageManager to check for the GMS core package.
     */
    private fun isGmsAvailable(): Boolean {
        return try {
            val pm = context.packageManager
            // Check for Google Play Services package
            val gmsPackage = "com.google.android.gms"
            pm.getPackageInfo(gmsPackage, 0)
            // If we got here, GMS is installed
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Check if HMS Core is available on this device.
     * Uses PackageManager to check for the HMS Core package.
     */
    private fun isHmsAvailable(): Boolean {
        return try {
            val pm = context.packageManager
            // Check for HMS Core package
            val hmsPackage = "com.huawei.hwid"
            pm.getPackageInfo(hmsPackage, 0)
            // If we got here, HMS Core is installed
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        } catch (e: Exception) {
            false
        }
    }
}
