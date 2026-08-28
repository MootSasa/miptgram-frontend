package com.example.miptgram

import android.graphics.RectF
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.example.app/cutout"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register push detector MethodChannel handler
        val pushDetector = PushDetectorHandler(this)
        pushDetector.setup(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getCutoutInfo") {
                val cutoutInfo = getDisplayCutout()
                result.success(cutoutInfo)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getDisplayCutout(): List<Map<String, Float>> {
        val cutoutList = mutableListOf<Map<String, Float>>()
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val windowInsets = window.decorView.rootWindowInsets
            val displayCutout = windowInsets?.displayCutout
            
            if (displayCutout != null) {
                val density = resources.displayMetrics.density

                // Пытаемся получить точный контур (только для Android 11+)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    val path = displayCutout.cutoutPath
                    if (path != null) {
                        val pathBounds = RectF()
                        // Вычисляем реальный прямоугольник вокруг самого векторного выреза
                        path.computeBounds(pathBounds, true)
                        
                        if (!pathBounds.isEmpty) {
                            cutoutList.add(mapOf(
                                "left" to pathBounds.left / density,
                                "top" to pathBounds.top / density,
                                "right" to pathBounds.right / density,
                                "bottom" to pathBounds.bottom / density,
                                "width" to pathBounds.width() / density,
                                "height" to pathBounds.height() / density
                            ))
                            return cutoutList
                        }
                    }
                }

                // Фоллбэк для старых версий (Android 9 и 10) или если Path не задан
                for (rect in displayCutout.boundingRects) {
                    cutoutList.add(mapOf(
                        "left" to rect.left / density,
                        "top" to rect.top / density,
                        "right" to rect.right / density,
                        "bottom" to rect.bottom / density,
                        "width" to rect.width().toFloat() / density,
                        "height" to rect.height().toFloat() / density
                    ))
                }
            }
        }
        return cutoutList
    }
}
