package com.onimta.mobile_pos

import android.content.Context
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Vibrator
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val TAG = "MainActivity"
    private val FEEDBACK_CHANNEL = "com.onimta.mobile_pos/feedback"
    private val PRINTER_CHANNEL = "com.onimta.mobile_pos/printer"
    private var toneGenerator: ToneGenerator? = null

    private var selectedDevice = "NEXGO_N5"
    private var nexgoPrinter: NexgoPrinterManager? = null
    private var wpos3Printer: Wpos3PrinterManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        try {
            nexgoPrinter = NexgoPrinterManager(applicationContext)
        } catch (e: Exception) {
            Log.w(TAG, "Nexgo printer init skipped/failed: ${e.message}")
        }

        try {
            wpos3Printer = Wpos3PrinterManager(applicationContext)
        } catch (e: Exception) {
            Log.w(TAG, "W-POS 3 printer init skipped/failed: ${e.message}")
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
                "setSelectedDevice" -> {
                    val device = call.argument<String>("device") ?: "NEXGO_N5"
                    selectedDevice = device
                    Log.d(TAG, "Printer target device switched to: $selectedDevice")
                    result.success(true)
                }

                "isPrinterAvailable" -> {
                    val available = when (selectedDevice) {
                        "WPOS_3" -> wpos3Printer?.isPrinterReady() ?: false
                        "NEXGO_N5" -> nexgoPrinter?.isPrinterReady() ?: false
                        else -> (nexgoPrinter?.isPrinterReady() == true) || (wpos3Printer?.isPrinterReady() == true)
                    }
                    result.success(available)
                }

                "printReceipt" -> {
                    val arguments = call.arguments as? Map<String, Any?>
                    if (arguments == null) {
                        result.error("INVALID_ARGS", "Receipt data cannot be null", null)
                        return@setMethodCallHandler
                    }

                    if (selectedDevice == "WPOS_3") {
                        val wp = wpos3Printer ?: Wpos3PrinterManager(applicationContext).also { wpos3Printer = it }
                        wp.printReceipt(arguments) { success, errorMsg ->
                            runOnUiThread {
                                if (success) result.success(true)
                                else result.error("PRINT_FAILED", errorMsg ?: "W-POS 3 print failed", null)
                            }
                        }
                    } else {
                        val np = nexgoPrinter ?: NexgoPrinterManager(applicationContext).also { nexgoPrinter = it }
                        np.printReceipt(arguments) { success, errorMsg ->
                            runOnUiThread {
                                if (success) {
                                    result.success(true)
                                } else {
                                    // Fallback to WPOS3 if Nexgo fails or isn't present
                                    wpos3Printer?.printReceipt(arguments) { wSuccess, wMsg ->
                                        runOnUiThread {
                                            if (wSuccess) result.success(true)
                                            else result.error("PRINT_FAILED", errorMsg ?: wMsg ?: "Print error", null)
                                        }
                                    } ?: result.error("PRINT_FAILED", errorMsg ?: "Unknown error", null)
                                }
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

                    if (selectedDevice == "WPOS_3") {
                        val wp = wpos3Printer ?: Wpos3PrinterManager(applicationContext).also { wpos3Printer = it }
                        wp.printCashMovement(arguments) { success, errorMsg ->
                            runOnUiThread {
                                if (success) result.success(true)
                                else result.error("PRINT_FAILED", errorMsg ?: "W-POS 3 print failed", null)
                            }
                        }
                    } else {
                        val np = nexgoPrinter ?: NexgoPrinterManager(applicationContext).also { nexgoPrinter = it }
                        np.printCashMovement(arguments) { success, errorMsg ->
                            runOnUiThread {
                                if (success) {
                                    result.success(true)
                                } else {
                                    wpos3Printer?.printCashMovement(arguments) { wSuccess, wMsg ->
                                        runOnUiThread {
                                            if (wSuccess) result.success(true)
                                            else result.error("PRINT_FAILED", errorMsg ?: wMsg ?: "Print error", null)
                                        }
                                    } ?: result.error("PRINT_FAILED", errorMsg ?: "Unknown error", null)
                                }
                            }
                        }
                    }
                }

                "printShiftReport" -> {
                    val arguments = call.arguments as? Map<String, Any?>
                    if (arguments == null) {
                        result.error("INVALID_ARGS", "Shift report data cannot be null", null)
                        return@setMethodCallHandler
                    }

                    if (selectedDevice == "WPOS_3") {
                        val wp = wpos3Printer ?: Wpos3PrinterManager(applicationContext).also { wpos3Printer = it }
                        wp.printShiftReport(arguments) { success, errorMsg ->
                            runOnUiThread {
                                if (success) result.success(true)
                                else result.error("PRINT_FAILED", errorMsg ?: "W-POS 3 print failed", null)
                            }
                        }
                    } else {
                        val np = nexgoPrinter ?: NexgoPrinterManager(applicationContext).also { nexgoPrinter = it }
                        np.printShiftReport(arguments) { success, errorMsg ->
                            runOnUiThread {
                                if (success) {
                                    result.success(true)
                                } else {
                                    wpos3Printer?.printShiftReport(arguments) { wSuccess, wMsg ->
                                        runOnUiThread {
                                            if (wSuccess) result.success(true)
                                            else result.error("PRINT_FAILED", errorMsg ?: wMsg ?: "Print error", null)
                                        }
                                    } ?: result.error("PRINT_FAILED", errorMsg ?: "Unknown error", null)
                                }
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
