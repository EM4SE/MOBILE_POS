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

    private val isZ93Hardware by lazy {
        android.os.Build.DISPLAY.contains("Z93", ignoreCase = true) ||
        android.os.Build.MODEL.contains("Z93", ignoreCase = true) ||
        android.os.Build.PRODUCT.contains("Z93", ignoreCase = true) ||
        android.os.Build.FINGERPRINT.contains("Z93", ignoreCase = true)
    }

    private val isZ92Hardware by lazy {
        !isZ93Hardware && (
            android.os.Build.DISPLAY.contains("Z92", ignoreCase = true) ||
            android.os.Build.MODEL.contains("Z92", ignoreCase = true) ||
            android.os.Build.PRODUCT.contains("Z92", ignoreCase = true) ||
            android.os.Build.MANUFACTURER.contains("ZCS", ignoreCase = true) ||
            android.os.Build.BRAND.contains("ZCS", ignoreCase = true) ||
            android.os.Build.FINGERPRINT.contains("Z92", ignoreCase = true)
        )
    }

    private var selectedDevice = "NEXGO_N5"
    private var printerFont = "MONOSPACE"
    private var nexgoPrinter: NexgoPrinterManager? = null
    private var wpos3Printer: Wpos3PrinterManager? = null
    private var dblZ92Printer: Z92PrinterManager? = null
    private var dblZ93Printer: Z93PrinterManager? = null

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

        try {
            dblZ92Printer = Z92PrinterManager(applicationContext)
        } catch (e: Exception) {
            Log.w(TAG, "DBL Z92 printer init skipped/failed: ${e.message}")
        }

        try {
            dblZ93Printer = Z93PrinterManager(applicationContext)
        } catch (e: Exception) {
            Log.w(TAG, "DBL Z93 printer init skipped/failed: ${e.message}")
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

                "setPrinterFont" -> {
                    val font = call.argument<String>("font") ?: "MONOSPACE"
                    printerFont = font
                    dblZ92Printer?.activeFont = font
                    dblZ93Printer?.activeFont = font
                    Log.d(TAG, "Printer font updated to: $font")
                    result.success(true)
                }

                "printFontTest" -> {
                    val font = call.argument<String>("font") ?: printerFont
                    printerFont = font
                    dblZ92Printer?.activeFont = font
                    dblZ93Printer?.activeFont = font
                    executePrint(
                        result,
                        printOnZ93 = { p, cb -> p.printFontTest(font, cb) },
                        printOnZ92 = { p, cb -> p.printFontTest(font, cb) },
                        printOnWpos3 = { _, cb -> cb(true, null) },
                        printOnNexgo = { _, cb -> cb(true, null) }
                    )
                }

                "isPrinterAvailable" -> {
                    val target = when {
                        isZ93Hardware && selectedDevice != "WPOS_3" -> "DBL_Z93"
                        isZ92Hardware && selectedDevice != "WPOS_3" -> "DBL_Z92"
                        else -> selectedDevice
                    }
                    val available = when (target) {
                        "DBL_Z93" -> dblZ93Printer?.isPrinterReady() ?: false
                        "DBL_Z92" -> dblZ92Printer?.isPrinterReady() ?: false
                        "WPOS_3" -> wpos3Printer?.isPrinterReady() ?: false
                        "NEXGO_N5" -> nexgoPrinter?.isPrinterReady() ?: false
                        else -> (dblZ93Printer?.isPrinterReady() == true) || (dblZ92Printer?.isPrinterReady() == true) || (nexgoPrinter?.isPrinterReady() == true) || (wpos3Printer?.isPrinterReady() == true)
                    }
                    result.success(available)
                }

                "printReceipt" -> {
                    val arguments = call.arguments as? Map<String, Any?>
                    if (arguments == null) {
                        result.error("INVALID_ARGS", "Receipt data cannot be null", null)
                        return@setMethodCallHandler
                    }
                    executePrint(
                        result,
                        printOnZ93 = { p, cb -> p.printReceipt(arguments, cb) },
                        printOnZ92 = { p, cb -> p.printReceipt(arguments, cb) },
                        printOnWpos3 = { p, cb -> p.printReceipt(arguments, cb) },
                        printOnNexgo = { p, cb -> p.printReceipt(arguments, cb) }
                    )
                }

                "printCashMovement" -> {
                    val arguments = call.arguments as? Map<String, Any?>
                    if (arguments == null) {
                        result.error("INVALID_ARGS", "Cash movement data cannot be null", null)
                        return@setMethodCallHandler
                    }
                    executePrint(
                        result,
                        printOnZ93 = { p, cb -> p.printCashMovement(arguments, cb) },
                        printOnZ92 = { p, cb -> p.printCashMovement(arguments, cb) },
                        printOnWpos3 = { p, cb -> p.printCashMovement(arguments, cb) },
                        printOnNexgo = { p, cb -> p.printCashMovement(arguments, cb) }
                    )
                }

                "printShiftReport" -> {
                    val arguments = call.arguments as? Map<String, Any?>
                    if (arguments == null) {
                        result.error("INVALID_ARGS", "Shift report data cannot be null", null)
                        return@setMethodCallHandler
                    }
                    executePrint(
                        result,
                        printOnZ93 = { p, cb -> p.printShiftReport(arguments, cb) },
                        printOnZ92 = { p, cb -> p.printShiftReport(arguments, cb) },
                        printOnWpos3 = { p, cb -> p.printShiftReport(arguments, cb) },
                        printOnNexgo = { p, cb -> p.printShiftReport(arguments, cb) }
                    )
                }

                "printExchangeReceipt" -> {
                    val arguments = call.arguments as? Map<String, Any?>
                    if (arguments == null) {
                        result.error("INVALID_ARGS", "Exchange data cannot be null", null)
                        return@setMethodCallHandler
                    }
                    executePrint(
                        result,
                        printOnZ93 = { p, cb -> p.printExchangeReceipt(arguments, cb) },
                        printOnZ92 = { p, cb -> p.printExchangeReceipt(arguments, cb) },
                        printOnWpos3 = { p, cb -> p.printExchangeReceipt(arguments, cb) },
                        printOnNexgo = { p, cb -> p.printExchangeReceipt(arguments, cb) }
                    )
                }

                "printReturnReceipt" -> {
                    val arguments = call.arguments as? Map<String, Any?>
                    if (arguments == null) {
                        result.error("INVALID_ARGS", "Return data cannot be null", null)
                        return@setMethodCallHandler
                    }
                    executePrint(
                        result,
                        printOnZ93 = { p, cb -> p.printReturnReceipt(arguments, cb) },
                        printOnZ92 = { p, cb -> p.printReturnReceipt(arguments, cb) },
                        printOnWpos3 = { p, cb -> p.printReturnReceipt(arguments, cb) },
                        printOnNexgo = { p, cb -> p.printReturnReceipt(arguments, cb) }
                    )
                }

                "printItemWiseSalesReport" -> {
                    val arguments = call.arguments as? Map<String, Any?>
                    if (arguments == null) {
                        result.error("INVALID_ARGS", "Report data cannot be null", null)
                        return@setMethodCallHandler
                    }
                    executePrint(
                        result,
                        printOnZ93 = { p, cb -> p.printItemWiseSalesReport(arguments, cb) },
                        printOnZ92 = { p, cb -> p.printItemWiseSalesReport(arguments, cb) },
                        printOnWpos3 = { p, cb -> p.printItemWiseSalesReport(arguments, cb) },
                        printOnNexgo = { p, cb -> p.printItemWiseSalesReport(arguments, cb) }
                    )
                }

                "printTotalSalesReport" -> {
                    val arguments = call.arguments as? Map<String, Any?>
                    if (arguments == null) {
                        result.error("INVALID_ARGS", "Report data cannot be null", null)
                        return@setMethodCallHandler
                    }
                    executePrint(
                        result,
                        printOnZ93 = { p, cb -> p.printTotalSalesReport(arguments, cb) },
                        printOnZ92 = { p, cb -> p.printTotalSalesReport(arguments, cb) },
                        printOnWpos3 = { p, cb -> p.printTotalSalesReport(arguments, cb) },
                        printOnNexgo = { p, cb -> p.printTotalSalesReport(arguments, cb) }
                    )
                }

                "printHoldReceipt" -> {
                    val arguments = call.arguments as? Map<String, Any?>
                    if (arguments == null) {
                        result.error("INVALID_ARGS", "Hold receipt data cannot be null", null)
                        return@setMethodCallHandler
                    }
                    executePrint(
                        result,
                        printOnZ93 = { p, cb -> p.printHoldReceipt(arguments, cb) },
                        printOnZ92 = { p, cb -> p.printHoldReceipt(arguments, cb) },
                        printOnWpos3 = { p, cb -> p.printHoldReceipt(arguments, cb) },
                        printOnNexgo = { p, cb -> p.printHoldReceipt(arguments, cb) }
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun executePrint(
        result: MethodChannel.Result,
        printOnZ93: (Z93PrinterManager, (Boolean, String?) -> Unit) -> Unit,
        printOnZ92: (Z92PrinterManager, (Boolean, String?) -> Unit) -> Unit,
        printOnWpos3: (Wpos3PrinterManager, (Boolean, String?) -> Unit) -> Unit,
        printOnNexgo: (NexgoPrinterManager, (Boolean, String?) -> Unit) -> Unit
    ) {
        val z93 = (dblZ93Printer ?: Z93PrinterManager(applicationContext).also { dblZ93Printer = it }).apply { activeFont = printerFont }
        val z92 = (dblZ92Printer ?: Z92PrinterManager(applicationContext).also { dblZ92Printer = it }).apply { activeFont = printerFont }
        val wpos = wpos3Printer ?: Wpos3PrinterManager(applicationContext).also { wpos3Printer = it }
        val nexgo = nexgoPrinter ?: NexgoPrinterManager(applicationContext).also { nexgoPrinter = it }

        val targetDevice = when {
            isZ93Hardware && selectedDevice != "WPOS_3" -> "DBL_Z93"
            isZ92Hardware && selectedDevice != "WPOS_3" -> "DBL_Z92"
            else -> selectedDevice
        }

        when (targetDevice) {
            "DBL_Z93" -> {
                printOnZ93(z93) { success, errorMsg ->
                    runOnUiThread {
                        if (success) result.success(true)
                        else result.error("PRINT_FAILED", errorMsg ?: "DBL Z93 print failed", null)
                    }
                }
            }
            "DBL_Z92" -> {
                printOnZ92(z92) { success, errorMsg ->
                    runOnUiThread {
                        if (success) result.success(true)
                        else result.error("PRINT_FAILED", errorMsg ?: "DBL Z92 print failed", null)
                    }
                }
            }
            "WPOS_3" -> {
                printOnWpos3(wpos) { success, errorMsg ->
                    runOnUiThread {
                        if (success) result.success(true)
                        else result.error("PRINT_FAILED", errorMsg ?: "W-POS 3 print failed", null)
                    }
                }
            }
            "NEXGO_N5" -> {
                printOnNexgo(nexgo) { success, errorMsg ->
                    runOnUiThread {
                        if (success) {
                            result.success(true)
                        } else {
                            // Fallback to DBL Z93/Z92, then WPOS 3
                            val fallback = if (z93.isPrinterReady()) {
                                printOnZ93(z93) { zSuccess, zMsg ->
                                    if (zSuccess) runOnUiThread { result.success(true) }
                                    else runOnUiThread { result.error("PRINT_FAILED", errorMsg ?: zMsg ?: "Print error", null) }
                                }
                            } else {
                                printOnZ92(z92) { zSuccess, zMsg ->
                                    if (zSuccess) {
                                        runOnUiThread { result.success(true) }
                                    } else {
                                        printOnWpos3(wpos) { wSuccess, wMsg ->
                                            runOnUiThread {
                                                if (wSuccess) result.success(true)
                                                else result.error("PRINT_FAILED", errorMsg ?: zMsg ?: wMsg ?: "Print error", null)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            else -> { // AUTO mode
                if (z93.isPrinterReady()) {
                    printOnZ93(z93) { success, errorMsg ->
                        runOnUiThread {
                            if (success) result.success(true)
                            else result.error("PRINT_FAILED", errorMsg ?: "DBL Z93 print failed", null)
                        }
                    }
                } else if (z92.isPrinterReady()) {
                    printOnZ92(z92) { success, errorMsg ->
                        runOnUiThread {
                            if (success) result.success(true)
                            else result.error("PRINT_FAILED", errorMsg ?: "DBL Z92 print failed", null)
                        }
                    }
                } else if (wpos.isPrinterReady()) {
                    printOnWpos3(wpos) { success, errorMsg ->
                        runOnUiThread {
                            if (success) result.success(true)
                            else result.error("PRINT_FAILED", errorMsg ?: "W-POS 3 print failed", null)
                        }
                    }
                } else {
                    printOnNexgo(nexgo) { success, errorMsg ->
                        runOnUiThread {
                            if (success) {
                                result.success(true)
                            } else {
                                printOnZ93(z93) { zSuccess, zMsg ->
                                    if (zSuccess) {
                                        runOnUiThread { result.success(true) }
                                    } else {
                                        printOnZ92(z92) { z2Success, z2Msg ->
                                            runOnUiThread {
                                                if (z2Success) result.success(true)
                                                else result.error("PRINT_FAILED", errorMsg ?: zMsg ?: z2Msg ?: "Print failed", null)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }
}
