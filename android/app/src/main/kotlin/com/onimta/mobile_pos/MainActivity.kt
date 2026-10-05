package com.onimta.mobile_pos

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Vibrator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val FEEDBACK_CHANNEL = "com.onimta.mobile_pos/feedback"
    private val PRINTER_CHANNEL = "com.onimta.mobile_pos/printer"
    private var toneGenerator: ToneGenerator? = null
    private var printerManager: NexgoPrinterManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        try {
            printerManager = NexgoPrinterManager(applicationContext)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        // Feedback Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FEEDBACK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "beep", "vibrate", "beepAndVibrate" -> {
                    // 1. Play Tone Beep
                    if (call.method == "beep" || call.method == "beepAndVibrate") {
                        try {
                            if (toneGenerator == null) {
                                toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                            }
                            toneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP, 150)
                        } catch (e: Exception) {
                            try {
                                val altTone = ToneGenerator(AudioManager.STREAM_SYSTEM, 100)
                                altTone.startTone(ToneGenerator.TONE_PROP_BEEP, 150)
                            } catch (e2: Exception) {
                                e2.printStackTrace()
                            }
                        }
                    }

                    // 2. Play Hardware Vibration
                    if (call.method == "vibrate" || call.method == "beepAndVibrate") {
                        try {
                            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
                            vibrator?.vibrate(120)
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }

                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Printer Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRINTER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPrinterAvailable" -> {
                    val available = printerManager?.isPrinterReady() ?: false
                    result.success(available)
                }
                "printReceipt" -> {
                    val arguments = call.arguments as? Map<String, Any?>
                    if (arguments == null) {
                        result.error("INVALID_ARGS", "Receipt data cannot be null", null)
                        return@setMethodCallHandler
                    }

                    val pm = printerManager ?: NexgoPrinterManager(applicationContext).also { printerManager = it }
                    pm.printReceipt(arguments) { success, errorMsg ->
                        runOnUiThread {
                            if (success) {
                                result.success(true)
                            } else {
                                result.error("PRINT_FAILED", errorMsg ?: "Unknown error", null)
                            }
                        }
                    }
                }
                "printCashMovement" -> {
                    val arguments = call.arguments as? Map<String, Any?>
                    if (arguments == null) {
                        result.error("INVALID_ARGS", "Cash movement data cannot be null", null)
                        return@setMethodCallHandler
                    }

                    val pm = printerManager ?: NexgoPrinterManager(applicationContext).also { printerManager = it }
                    pm.printCashMovement(arguments) { success, errorMsg ->
                        runOnUiThread {
                            if (success) {
                                result.success(true)
                            } else {
                                result.error("PRINT_FAILED", errorMsg ?: "Unknown error", null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }
}
