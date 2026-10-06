package com.onimta.mobile_pos

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.os.IBinder
import android.os.Parcel
import android.util.Log
import java.lang.reflect.Method

/**
 * Intelligent Auto-Discovery Hardware Printer Manager for W-POS 3 (Wiseasy / WangPOS) smart POS terminals.
 * Features:
 * 1. Deep package scanning for all installed WangPOS / Wiseasy / W-POS 3 printer services
 * 2. Dynamic classloader stub resolution from connected service classloaders
 * 3. Asynchronous service connection with synchronous timeout wait for print jobs
 * 4. High-resolution 58mm (384-dot) bitmap rendering and native formatted text fallback
 */
class Wpos3PrinterManager(private val context: Context) {
    private val TAG = "Wpos3PrinterManager"

    private var printerInstance: Any? = null
    private var printerServiceBinder: Any? = null
    private var rawBinder: IBinder? = null
    private var isBound = false
    private var isInitialized = false

    // Method caches
    private var printInitMethod: Method? = null
    private var clearCacheMethod: Method? = null
    private var printStringMethod: Method? = null
    private var print2StringMethod: Method? = null
    private var printPictureMethod: Method? = null
    private var printPaperMethod: Method? = null
    private var printFinishMethod: Method? = null

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            Log.d(TAG, "W-POS 3 Service Connected: $name, binder class: ${service?.javaClass?.name}")
            rawBinder = service
            isBound = true

            if (service != null) {
                // 1. Try resolving stub from service's own ClassLoader
                val serviceClassLoader = service.javaClass.classLoader
                val stubClassNames = listOf(
                    "wangpos.sdk4.libbasebinder.Core\$Stub",
                    "wangpos.sdk4.libbasebinder.Printer\$Stub",
                    "com.wangpos.printerservice.IPrinterService\$Stub",
                    "com.wiseasy.printer.IPrinterService\$Stub",
                    "com.wiseasy.printer.PrinterService\$Stub",
                    "com.wiseasy.smartpos.printer.IPrinterService\$Stub",
                    "com.pos.sdk.printer.IPrinterService\$Stub"
                )

                for (stubName in stubClassNames) {
                    try {
                        val clazz = try {
                            serviceClassLoader?.loadClass(stubName) ?: Class.forName(stubName)
                        } catch (_: Exception) {
                            Class.forName(stubName)
                        }

                        val asInterface = clazz.getMethod("asInterface", IBinder::class.java)
                        printerServiceBinder = asInterface.invoke(null, service)
                        if (printerServiceBinder != null) {
                            Log.d(TAG, "Successfully resolved W-POS 3 binder interface via $stubName: $printerServiceBinder")
                            cacheMethods(printerServiceBinder!!.javaClass)
                            isInitialized = true
                            break
                        }
                    } catch (_: Exception) {}
                }

                // If stub resolution didn't find specific wrapper, use binder directly
                if (printerServiceBinder == null) {
                    printerServiceBinder = service
                    cacheMethods(service.javaClass)
                    isInitialized = true
                }
            }

            initDirectSdk()
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            Log.d(TAG, "W-POS 3 Service Disconnected: $name")
            printerServiceBinder = null
            rawBinder = null
            isBound = false
            isInitialized = false
        }
    }

    init {
        initSdk()
    }

    fun initSdk() {
        initDirectSdk()
        bindDiscoveredServices()
    }

    private fun initDirectSdk() {
        if (printerInstance != null) return

        val candidateClassNames = listOf(
            "wangpos.sdk4.libbasebinder.Printer",
            "wangpos.sdk4.libbasebinder.Core",
            "com.wiseasy.printer.Printer",
            "com.wangpos.printerservice.Printer",
            "com.wangpos.printer.Printer",
            "com.pos.sdk.printer.PosPrinter",
            "com.wangpos.sdk4.libbasebinder.Printer"
        )

        for (className in candidateClassNames) {
            try {
                val clazz = try {
                    Class.forName(className)
                } catch (_: Exception) {
                    context.classLoader.loadClass(className)
                }

                Log.d(TAG, "Found candidate WPOS class in classpath: $className")

                // Try Constructor(Context)
                val constructorWithContext = clazz.constructors.firstOrNull {
                    it.parameterTypes.size == 1 && Context::class.java.isAssignableFrom(it.parameterTypes[0])
                }

                if (constructorWithContext != null) {
                    printerInstance = constructorWithContext.newInstance(context.applicationContext)
                    Log.d(TAG, "Instantiated $className with application context: $printerInstance")
                } else {
                    val emptyConstructor = clazz.constructors.firstOrNull { it.parameterTypes.isEmpty() }
                    if (emptyConstructor != null) {
                        printerInstance = emptyConstructor.newInstance()
                        Log.d(TAG, "Instantiated $className with empty constructor: $printerInstance")
                    }
                }

                if (printerInstance != null) {
                    cacheMethods(printerInstance!!.javaClass)
                    isInitialized = true
                    break
                }
            } catch (e: Throwable) {
                Log.w(TAG, "Candidate $className not directly loadable: ${e.message}")
            }
        }
    }

    private fun bindDiscoveredServices() {
        if (isBound) return

        val explicitIntents = mutableListOf(
            Intent().setComponent(ComponentName("wangpos.sdk4.libbasebinder", "wangpos.sdk4.libbasebinder.CoreService")),
            Intent("wangpos.sdk4.libbasebinder.CoreService").setPackage("wangpos.sdk4.libbasebinder"),
            Intent().setComponent(ComponentName("com.wangpos.printerservice", "com.wangpos.printerservice.PrinterService")),
            Intent("com.wangpos.printerservice.PrinterService").setPackage("com.wangpos.printerservice"),
            Intent().setComponent(ComponentName("com.wiseasy.printer", "com.wiseasy.printer.PrinterService")),
            Intent("com.wiseasy.printer.PrinterService").setPackage("com.wiseasy.printer"),
            Intent("com.wiseasy.printer.service").setPackage("com.wiseasy.printer")
        )

        // Dynamically discover all installed printer packages and implicit action services
        try {
            val pm = context.packageManager

            // Resolve implicit action "android.intent.action.WANGPOS_PRINTER_SERVICE" explicitly
            val actionIntent = Intent("android.intent.action.WANGPOS_PRINTER_SERVICE")
            val resolveInfos = pm.queryIntentServices(actionIntent, 0)
            for (resolveInfo in resolveInfos) {
                val serviceInfo = resolveInfo.serviceInfo
                if (serviceInfo != null) {
                    explicitIntents.add(
                        Intent().setComponent(ComponentName(serviceInfo.packageName, serviceInfo.name))
                    )
                }
            }

            val installedPackages = pm.getInstalledPackages(PackageManager.GET_SERVICES)
            for (pkg in installedPackages) {
                val pkgName = pkg.packageName.lowercase()
                if (pkgName.contains("wangpos") || pkgName.contains("wiseasy") ||
                    pkgName.contains("wpos") || (pkgName.contains("printer") && !pkgName.contains("printspooler"))) {
                    Log.d(TAG, "Discovered POS printer package: ${pkg.packageName}")
                    pkg.services?.forEach { serviceInfo ->
                        Log.d(TAG, "  -> Found Service: ${serviceInfo.name}")
                        explicitIntents.add(
                            Intent().setComponent(ComponentName(pkg.packageName, serviceInfo.name))
                        )
                    }
                }
            }
        } catch (e: Throwable) {
            Log.w(TAG, "Error scanning installed packages: ${e.message}")
        }

        for (intent in explicitIntents) {
            try {
                val bound = context.bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
                if (bound) {
                    Log.d(TAG, "Triggered bindService with intent: $intent")
                    isBound = true
                    break
                }
            } catch (e: Throwable) {
                Log.w(TAG, "Failed binding intent $intent: ${e.message}")
            }
        }
    }

    private fun cacheMethods(clazz: Class<*>) {
        printInitMethod = clazz.methods.firstOrNull { it.name == "printInit" }
        clearCacheMethod = clazz.methods.firstOrNull { it.name == "clearPrintDataCache" || it.name == "cleanData" }
        printStringMethod = clazz.methods.firstOrNull { it.name == "printString" || it.name == "printText" }
        print2StringMethod = clazz.methods.firstOrNull { it.name == "print2String" || it.name == "printTwoColumn" }
        printPictureMethod = clazz.methods.firstOrNull { it.name == "printPicture" || it.name == "printBitmap" || it.name == "printImage" }
        printPaperMethod = clazz.methods.firstOrNull { it.name == "printPaper" || it.name == "feedPaper" || it.name == "lineWrap" }
        printFinishMethod = clazz.methods.firstOrNull { it.name == "printFinish" || it.name == "printContent" || it.name == "commitPrint" }

        Log.d(TAG, "Cached methods on ${clazz.name}: " +
                "init=${printInitMethod?.name}, " +
                "clear=${clearCacheMethod?.name}, " +
                "printStr=${printStringMethod?.name}, " +
                "printPic=${printPictureMethod?.name}, " +
                "feed=${printPaperMethod?.name}, " +
                "finish=${printFinishMethod?.name}")
    }

    private fun waitForPrinterReady(timeoutMs: Long = 1800): Boolean {
        if (printerInstance != null || printerServiceBinder != null) return true
        initSdk()
        val startTime = System.currentTimeMillis()
        while (System.currentTimeMillis() - startTime < timeoutMs) {
            if (printerInstance != null || printerServiceBinder != null) return true
            try {
                Thread.sleep(100)
            } catch (_: InterruptedException) {}
        }
        return printerInstance != null || printerServiceBinder != null
    }

    fun isPrinterReady(): Boolean {
        return printerInstance != null || printerServiceBinder != null || isBound
    }

    fun printReceipt(
        receiptData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!waitForPrinterReady()) {
                    onComplete(false, "W-POS 3 printer service is connecting or not installed on this terminal")
                    return@Thread
                }

                val appName = receiptData["appName"] as? String ?: "ONIMTA POS"
                val invoiceNo = receiptData["invoiceNo"] as? String ?: ""
                val customerName = receiptData["customerName"] as? String ?: "Walk-in Customer"
                val cashierName = receiptData["cashierName"] as? String ?: "Admin"
                val dateStr = receiptData["dateTime"] as? String ?: ""
                val items = receiptData["items"] as? List<Map<String, Any?>> ?: emptyList()
                val subtotal = receiptData["subtotal"] as? String ?: ""
                val discount = receiptData["discount"] as? String ?: ""
                val tax = receiptData["tax"] as? String ?: ""
                val grandTotal = receiptData["grandTotal"] as? String ?: ""
                val payments = receiptData["payments"] as? List<Map<String, Any?>> ?: emptyList()
                val totalPaid = receiptData["paidAmount"] as? String ?: ""
                val change = receiptData["changeAmount"] as? String ?: ""

                val target = printerInstance ?: printerServiceBinder
                if (target != null) {
                    val targetClass = target.javaClass
                    cacheMethods(targetClass)

                    // 1. Initialize Printer Session
                    try {
                        printInitMethod?.invoke(target)
                        clearCacheMethod?.invoke(target)
                    } catch (e: Throwable) {
                        Log.w(TAG, "printInit/clear error: ${e.message}")
                    }

                    // 2. Try High-Resolution Bitmap Print first
                    val bitmap = renderReceiptBitmap(
                        appName = appName,
                        invoiceNo = invoiceNo,
                        customerName = customerName,
                        cashierName = cashierName,
                        dateStr = dateStr,
                        items = items,
                        subtotal = subtotal,
                        discount = discount,
                        tax = tax,
                        grandTotal = grandTotal,
                        payments = payments,
                        totalPaid = totalPaid,
                        change = change
                    )

                    var bitmapSuccess = false
                    if (printPictureMethod != null) {
                        try {
                            val params = printPictureMethod!!.parameterTypes
                            if (params.size == 1 && params[0] == Bitmap::class.java) {
                                printPictureMethod!!.invoke(target, bitmap)
                                bitmapSuccess = true
                            } else if (params.size == 2 && params[0] == Bitmap::class.java) {
                                printPictureMethod!!.invoke(target, bitmap, 1) // 1 = center
                                bitmapSuccess = true
                            }
                        } catch (e: Throwable) {
                            Log.w(TAG, "printPicture invocation failed: ${e.message}")
                        }
                    }

                    // 3. Text fallback if bitmap method not supported
                    if (!bitmapSuccess && printStringMethod != null) {
                        fun pLine(text: String, size: Int = 22, align: Int = 0, bold: Boolean = false) {
                            try {
                                val params = printStringMethod!!.parameterTypes
                                if (params.size == 5) {
                                    printStringMethod!!.invoke(target, text, size, align, bold, false)
                                } else if (params.size == 4) {
                                    printStringMethod!!.invoke(target, text, size, align, bold)
                                } else if (params.size == 3) {
                                    printStringMethod!!.invoke(target, text, size, align)
                                } else if (params.size == 1) {
                                    printStringMethod!!.invoke(target, text + "\n")
                                }
                            } catch (_: Throwable) {}
                        }

                        fun pTwoCols(left: String, right: String, size: Int = 20, bold: Boolean = false) {
                            val totalWidth = 32
                            val pad = (totalWidth - left.length - right.length).coerceAtLeast(1)
                            pLine(left + " ".repeat(pad) + right, size, 0, bold)
                        }

                        pLine(appName, 28, 1, true)
                        pLine("TAX INVOICE RECEIPT", 20, 1, false)
                        pLine("--------------------------------", 18, 1, false)

                        pTwoCols("Invoice #:", invoiceNo, 20, true)
                        if (dateStr.isNotEmpty()) pTwoCols("Date:", dateStr, 18, false)
                        pTwoCols("Cashier:", cashierName, 18, false)
                        pTwoCols("Customer:", customerName, 18, false)
                        pLine("--------------------------------", 18, 1, false)

                        pLine("ITEM DESCRIPTION", 18, 0, true)
                        pLine("--------------------------------", 18, 1, false)

                        for (item in items) {
                            val desc = item["description"] as? String ?: ""
                            val qty = item["qty"] as? String ?: "1"
                            val price = item["price"] as? String ?: ""
                            val itemDisc = item["discount"] as? String ?: ""
                            val total = item["total"] as? String ?: ""

                            pLine(desc, 20, 0, true)
                            pTwoCols("  $qty x $price", total, 18, false)
                            if (itemDisc.isNotEmpty() && itemDisc != "LKR 0.00" && itemDisc != "0.00") {
                                pTwoCols("    Item Disc:", "-$itemDisc", 16, false)
                            }
                        }
                        pLine("--------------------------------", 18, 1, false)

                        pTwoCols("Subtotal:", subtotal, 20, false)
                        if (discount.isNotEmpty() && discount != "LKR 0.00" && discount != "0.00") {
                            pTwoCols("Discount:", "-$discount", 20, false)
                        }
                        if (tax.isNotEmpty() && tax != "LKR 0.00" && tax != "0.00") {
                            pTwoCols("Tax:", tax, 20, false)
                        }
                        pLine("--------------------------------", 18, 1, false)
                        pTwoCols("GRAND TOTAL:", grandTotal, 24, true)
                        pLine("--------------------------------", 18, 1, false)

                        if (payments.isNotEmpty()) {
                            for (p in payments) {
                                val method = p["method"] as? String ?: "Payment"
                                val amt = p["amount"] as? String ?: ""
                                pTwoCols(method, amt, 18, false)
                            }
                        }

                        if (totalPaid.isNotEmpty()) pTwoCols("Total Paid:", totalPaid, 20, true)
                        if (change.isNotEmpty() && change != "LKR 0.00" && change != "0.00") {
                            pTwoCols("Change Returned:", change, 22, true)
                        }

                        pLine("--------------------------------", 18, 1, false)
                        pLine("THANK YOU FOR SHOPPING!", 18, 1, true)
                        pLine("Please come again", 16, 1, false)
                    }

                    // 4. Feed & Commit Print
                    try {
                        printPaperMethod?.invoke(target, 4)
                    } catch (_: Throwable) {}

                    try {
                        printFinishMethod?.invoke(target)
                    } catch (_: Throwable) {}

                    Log.d(TAG, "W-POS 3 receipt printed successfully")
                    onComplete(true, null)
                } else {
                    onComplete(false, "W-POS 3 printer service is not connected on this terminal")
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing receipt on W-POS 3: ${e.message}", e)
                onComplete(false, "W-POS 3 print error: ${e.message}")
            }
        }.start()
    }

    fun printCashMovement(
        movementData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!waitForPrinterReady()) {
                    onComplete(false, "W-POS 3 printer service is connecting or not installed on this terminal")
                    return@Thread
                }

                val appName = movementData["appName"] as? String ?: "ONIMTA POS"
                val type = movementData["type"] as? String ?: "CASH MOVEMENT"
                val amount = movementData["amount"] as? String ?: ""
                val reason = movementData["reason"] as? String ?: ""
                val cashier = movementData["cashier"] as? String ?: "Admin"
                val dateTime = movementData["dateTime"] as? String ?: ""

                val target = printerInstance ?: printerServiceBinder
                if (target != null) {
                    val targetClass = target.javaClass
                    cacheMethods(targetClass)

                    try {
                        printInitMethod?.invoke(target)
                        clearCacheMethod?.invoke(target)
                    } catch (_: Throwable) {}

                    val bitmap = renderCashMovementBitmap(
                        appName = appName,
                        type = type,
                        amount = amount,
                        reason = reason,
                        cashier = cashier,
                        dateTime = dateTime
                    )

                    if (printPictureMethod != null) {
                        try {
                            val params = printPictureMethod!!.parameterTypes
                            if (params.size == 1 && params[0] == Bitmap::class.java) {
                                printPictureMethod!!.invoke(target, bitmap)
                            } else if (params.size == 2 && params[0] == Bitmap::class.java) {
                                printPictureMethod!!.invoke(target, bitmap, 1)
                            }
                        } catch (_: Throwable) {}
                    }

                    try {
                        printPaperMethod?.invoke(target, 4)
                        printFinishMethod?.invoke(target)
                    } catch (_: Throwable) {}

                    onComplete(true, null)
                } else {
                    onComplete(false, "W-POS 3 printer service not connected")
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing cash movement on W-POS 3: ${e.message}", e)
                onComplete(false, "W-POS 3 print error: ${e.message}")
            }
        }.start()
    }

    fun printShiftReport(
        reportData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!waitForPrinterReady()) {
                    onComplete(false, "W-POS 3 printer service is connecting or not installed on this terminal")
                    return@Thread
                }

                val target = printerInstance ?: printerServiceBinder
                if (target != null) {
                    val targetClass = target.javaClass
                    cacheMethods(targetClass)

                    try {
                        printInitMethod?.invoke(target)
                        clearCacheMethod?.invoke(target)
                    } catch (_: Throwable) {}

                    val bitmap = renderShiftReportBitmap(reportData)

                    if (printPictureMethod != null) {
                        try {
                            val params = printPictureMethod!!.parameterTypes
                            if (params.size == 1 && params[0] == Bitmap::class.java) {
                                printPictureMethod!!.invoke(target, bitmap)
                            } else if (params.size == 2 && params[0] == Bitmap::class.java) {
                                printPictureMethod!!.invoke(target, bitmap, 1)
                            }
                        } catch (_: Throwable) {}
                    }

                    try {
                        printPaperMethod?.invoke(target, 4)
                        printFinishMethod?.invoke(target)
                    } catch (_: Throwable) {}

                    onComplete(true, null)
                } else {
                    onComplete(false, "W-POS 3 printer service not connected")
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing shift report on W-POS 3: ${e.message}", e)
                onComplete(false, "W-POS 3 print error: ${e.message}")
            }
        }.start()
    }

    fun printExchangeReceipt(
        exchangeData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!waitForPrinterReady()) {
                    onComplete(false, "W-POS 3 printer service is connecting or not installed on this terminal")
                    return@Thread
                }

                val target = printerInstance ?: printerServiceBinder
                if (target != null) {
                    val targetClass = target.javaClass
                    cacheMethods(targetClass)

                    try {
                        printInitMethod?.invoke(target)
                        clearCacheMethod?.invoke(target)
                    } catch (_: Throwable) {}

                    val bitmap = renderExchangeBitmap(exchangeData)

                    if (printPictureMethod != null) {
                        try {
                            val params = printPictureMethod!!.parameterTypes
                            if (params.size == 1 && params[0] == Bitmap::class.java) {
                                printPictureMethod!!.invoke(target, bitmap)
                            } else if (params.size == 2 && params[0] == Bitmap::class.java) {
                                printPictureMethod!!.invoke(target, bitmap, 1)
                            }
                        } catch (_: Throwable) {}
                    }

                    try {
                        printPaperMethod?.invoke(target, 4)
                        printFinishMethod?.invoke(target)
                    } catch (_: Throwable) {}

                    onComplete(true, null)
                } else {
                    onComplete(false, "W-POS 3 printer service not connected")
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing exchange receipt on W-POS 3: ${e.message}", e)
                onComplete(false, "W-POS 3 print error: ${e.message}")
            }
        }.start()
    }

    fun printReturnReceipt(
        returnData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!waitForPrinterReady()) {
                    onComplete(false, "W-POS 3 printer service is connecting or not installed on this terminal")
                    return@Thread
                }

                val target = printerInstance ?: printerServiceBinder
                if (target != null) {
                    val targetClass = target.javaClass
                    cacheMethods(targetClass)

                    try {
                        printInitMethod?.invoke(target)
                        clearCacheMethod?.invoke(target)
                    } catch (_: Throwable) {}

                    val bitmap = renderReturnBitmap(returnData)

                    if (printPictureMethod != null) {
                        try {
                            val params = printPictureMethod!!.parameterTypes
                            if (params.size == 1 && params[0] == Bitmap::class.java) {
                                printPictureMethod!!.invoke(target, bitmap)
                            } else if (params.size == 2 && params[0] == Bitmap::class.java) {
                                printPictureMethod!!.invoke(target, bitmap, 1)
                            }
                        } catch (_: Throwable) {}
                    }

                    try {
                        printPaperMethod?.invoke(target, 4)
                        printFinishMethod?.invoke(target)
                    } catch (_: Throwable) {}

                    onComplete(true, null)
                } else {
                    onComplete(false, "W-POS 3 printer service not connected")
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing return receipt on W-POS 3: ${e.message}", e)
                onComplete(false, "W-POS 3 print error: ${e.message}")
            }
        }.start()
    }

    // ==========================================
    // 58mm (384px width) Bitmap Rendering Engine
    // ==========================================

    private fun renderReceiptBitmap(
        appName: String,
        invoiceNo: String,
        customerName: String,
        cashierName: String,
        dateStr: String,
        items: List<Map<String, Any?>>,
        subtotal: String,
        discount: String,
        tax: String,
        grandTotal: String,
        payments: List<Map<String, Any?>>,
        totalPaid: String,
        change: String
    ): Bitmap {
        val width = 384
        val estimatedHeight = 550 + (items.size * 60) + (payments.size * 30)
        val bitmap = Bitmap.createBitmap(width, estimatedHeight, Bitmap.Config.RGB_565)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)

        val paint = Paint().apply {
            color = Color.BLACK
            isAntiAlias = true
        }

        var y = 35f

        fun drawCenter(text: String, size: Float, bold: Boolean = false) {
            paint.textSize = size
            paint.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            paint.textAlign = Paint.Align.CENTER
            canvas.drawText(text, width / 2f, y, paint)
            y += size + 8f
        }

        fun drawDivider(dotted: Boolean = true) {
            paint.textSize = 16f
            paint.typeface = Typeface.MONOSPACE
            paint.textAlign = Paint.Align.CENTER
            val line = if (dotted) "- - - - - - - - - - - - - - - - - -" else "-----------------------------------"
            canvas.drawText(line, width / 2f, y, paint)
            y += 22f
        }

        fun drawTwoCols(left: String, right: String, size: Float = 20f, bold: Boolean = false) {
            paint.textSize = size
            paint.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText(left, 14f, y, paint)
            paint.textAlign = Paint.Align.RIGHT
            canvas.drawText(right, (width - 14).toFloat(), y, paint)
            y += size + 8f
        }

        drawCenter(appName, 28f, true)
        drawCenter("TAX INVOICE RECEIPT", 18f, false)
        drawDivider(false)

        drawTwoCols("Invoice #:", invoiceNo, 20f, true)
        if (dateStr.isNotEmpty()) drawTwoCols("Date:", dateStr, 18f, false)
        drawTwoCols("Cashier:", cashierName, 18f, false)
        drawTwoCols("Customer:", customerName, 18f, false)
        drawDivider()

        paint.textSize = 18f
        paint.typeface = Typeface.DEFAULT_BOLD
        paint.textAlign = Paint.Align.LEFT
        canvas.drawText("ITEM DESCRIPTION", 14f, y, paint)
        y += 24f
        drawDivider(true)

        for (item in items) {
            val desc = item["description"] as? String ?: ""
            val qty = item["qty"] as? String ?: "1"
            val price = item["price"] as? String ?: ""
            val itemDisc = item["discount"] as? String ?: ""
            val total = item["total"] as? String ?: ""

            paint.textSize = 20f
            paint.typeface = Typeface.DEFAULT_BOLD
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText(desc, 14f, y, paint)
            y += 24f

            drawTwoCols("  $qty x $price", total, 18f, false)
            if (itemDisc.isNotEmpty() && itemDisc != "LKR 0.00" && itemDisc != "0.00") {
                drawTwoCols("    Item Disc:", "-$itemDisc", 16f, false)
            }
        }
        drawDivider()

        drawTwoCols("Subtotal:", subtotal, 20f, false)
        if (discount.isNotEmpty() && discount != "LKR 0.00" && discount != "0.00") {
            drawTwoCols("Discount:", "-$discount", 20f, false)
        }
        if (tax.isNotEmpty() && tax != "LKR 0.00" && tax != "0.00") {
            drawTwoCols("Tax:", tax, 20f, false)
        }
        drawDivider(false)
        drawTwoCols("GRAND TOTAL:", grandTotal, 24f, true)
        drawDivider(false)

        if (payments.isNotEmpty()) {
            for (p in payments) {
                val method = p["method"] as? String ?: "Payment"
                val amt = p["amount"] as? String ?: ""
                drawTwoCols(method, amt, 19f, false)
            }
        }

        if (totalPaid.isNotEmpty()) drawTwoCols("Total Paid:", totalPaid, 20f, true)
        if (change.isNotEmpty() && change != "LKR 0.00" && change != "0.00") {
            drawTwoCols("Change Returned:", change, 22f, true)
        }

        drawDivider(true)
        drawCenter("THANK YOU FOR YOUR BUSINESS!", 18f, true)
        drawCenter("Please Come Again", 16f, false)
        y += 30f

        return Bitmap.createBitmap(bitmap, 0, 0, width, y.toInt().coerceAtLeast(100))
    }

    private fun renderCashMovementBitmap(
        appName: String,
        type: String,
        amount: String,
        reason: String,
        cashier: String,
        dateTime: String
    ): Bitmap {
        val width = 384
        val estimatedHeight = 460
        val bitmap = Bitmap.createBitmap(width, estimatedHeight, Bitmap.Config.RGB_565)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)

        val paint = Paint().apply {
            color = Color.BLACK
            isAntiAlias = true
        }

        var y = 35f

        fun drawCenter(text: String, size: Float, bold: Boolean = false) {
            paint.textSize = size
            paint.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            paint.textAlign = Paint.Align.CENTER
            canvas.drawText(text, width / 2f, y, paint)
            y += size + 8f
        }

        fun drawDivider(dotted: Boolean = true) {
            paint.textSize = 16f
            paint.typeface = Typeface.MONOSPACE
            paint.textAlign = Paint.Align.CENTER
            val line = if (dotted) "- - - - - - - - - - - - - - - - - -" else "-----------------------------------"
            canvas.drawText(line, width / 2f, y, paint)
            y += 22f
        }

        fun drawTwoCols(left: String, right: String, size: Float = 20f, bold: Boolean = false) {
            paint.textSize = size
            paint.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText(left, 14f, y, paint)
            paint.textAlign = Paint.Align.RIGHT
            canvas.drawText(right, (width - 14).toFloat(), y, paint)
            y += size + 8f
        }

        drawCenter(appName, 26f, true)
        drawCenter(type, 20f, true)
        drawDivider(false)

        drawTwoCols("Amount:", amount, 24f, true)
        drawTwoCols("Reason:", reason, 18f, false)
        drawTwoCols("Cashier:", cashier, 18f, false)
        drawTwoCols("Date & Time:", dateTime, 18f, false)
        drawDivider(true)

        y += 40f
        drawCenter("____________________________", 16f, false)
        drawCenter("Cashier / Manager Signature", 16f, false)
        y += 30f

        return Bitmap.createBitmap(bitmap, 0, 0, width, y.toInt().coerceAtLeast(100))
    }

    private fun renderShiftReportBitmap(reportData: Map<String, Any?>): Bitmap {
        val width = 384
        val estimatedHeight = 700
        val bitmap = Bitmap.createBitmap(width, estimatedHeight, Bitmap.Config.RGB_565)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)

        val paint = Paint().apply {
            color = Color.BLACK
            isAntiAlias = true
        }

        var y = 35f

        fun drawCenter(text: String, size: Float, bold: Boolean = false) {
            paint.textSize = size
            paint.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            paint.textAlign = Paint.Align.CENTER
            canvas.drawText(text, width / 2f, y, paint)
            y += size + 8f
        }

        fun drawDivider(dotted: Boolean = true) {
            paint.textSize = 16f
            paint.typeface = Typeface.MONOSPACE
            paint.textAlign = Paint.Align.CENTER
            val line = if (dotted) "- - - - - - - - - - - - - - - - - -" else "-----------------------------------"
            canvas.drawText(line, width / 2f, y, paint)
            y += 22f
        }

        fun drawTwoCols(left: String, right: String, size: Float = 20f, bold: Boolean = false) {
            paint.textSize = size
            paint.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText(left, 14f, y, paint)
            paint.textAlign = Paint.Align.RIGHT
            canvas.drawText(right, (width - 14).toFloat(), y, paint)
            y += size + 8f
        }

        val appName = reportData["appName"] as? String ?: "ONIMTA POS"
        val title = reportData["title"] as? String ?: "SHIFT REPORT"
        val dayNumber = reportData["dayNumber"] as? String ?: ""
        val shiftNumber = reportData["shiftNumber"] as? String ?: ""
        val cashier = reportData["cashier"] as? String ?: ""
        val isEndReport = reportData["isEndReport"] as? Boolean ?: false
        val openingBalance = reportData["openingBalance"] as? String ?: ""
        val dateTime = reportData["dateTime"] as? String ?: ""

        drawCenter(appName, 26f, true)
        drawCenter(title, 22f, true)
        drawDivider(false)

        drawTwoCols("Business Day:", dayNumber, 19f, false)
        drawTwoCols("Shift #:", shiftNumber, 19f, false)
        drawTwoCols("Cashier:", cashier, 19f, false)
        drawTwoCols("Date & Time:", dateTime, 17f, false)
        drawDivider(true)

        drawTwoCols("Opening Balance:", openingBalance, 20f, true)

        if (isEndReport) {
            val totalInvoices = reportData["totalInvoices"] as? String ?: "0"
            val grossSales = reportData["grossSales"] as? String ?: ""
            val discount = reportData["discount"] as? String ?: ""
            val netSales = reportData["netSales"] as? String ?: ""
            val cashSales = reportData["cashSales"] as? String ?: ""
            val cardSales = reportData["cardSales"] as? String ?: ""
            val paidIn = reportData["paidIn"] as? String ?: ""
            val paidOut = reportData["paidOut"] as? String ?: ""
            val expectedCash = reportData["expectedCash"] as? String ?: ""
            val actualCash = reportData["actualCash"] as? String ?: ""
            val cashDiff = reportData["cashDiff"] as? String ?: ""

            drawTwoCols("Total Invoices:", totalInvoices, 19f, false)
            drawTwoCols("Gross Sales:", grossSales, 19f, false)
            if (discount.isNotEmpty() && discount != "LKR 0.00") drawTwoCols("Discount:", "-$discount", 19f, false)
            drawDivider(true)
            drawTwoCols("NET SALES:", netSales, 21f, true)
            drawDivider(true)

            drawTwoCols("Cash Sales:", cashSales, 19f, false)
            drawTwoCols("Card Sales:", cardSales, 19f, false)
            drawTwoCols("Cash Paid In (+):", paidIn, 19f, false)
            drawTwoCols("Cash Paid Out (-):", paidOut, 19f, false)
            drawDivider(true)

            drawTwoCols("Expected Cash:", expectedCash, 20f, true)
            drawTwoCols("Actual Cash In Hand:", actualCash, 20f, true)
            drawTwoCols("Cash Difference:", cashDiff, 21f, true)
        }

        drawDivider(false)
        y += 40f
        drawCenter("____________________________", 16f, false)
        drawCenter("Supervisor / Cashier Signature", 16f, false)
        y += 30f

        return Bitmap.createBitmap(bitmap, 0, 0, width, y.toInt().coerceAtLeast(100))
    }

    private fun renderExchangeBitmap(exchangeData: Map<String, Any?>): Bitmap {
        val width = 384
        val items = exchangeData["items"] as? List<Map<String, Any?>> ?: emptyList()
        val estimatedHeight = 550 + (items.size * 55)
        val bitmap = Bitmap.createBitmap(width, estimatedHeight, Bitmap.Config.RGB_565)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)

        val paint = Paint().apply {
            color = Color.BLACK
            isAntiAlias = true
        }

        var y = 35f

        fun drawCenter(text: String, size: Float, bold: Boolean = false) {
            paint.textSize = size
            paint.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            paint.textAlign = Paint.Align.CENTER
            canvas.drawText(text, width / 2f, y, paint)
            y += size + 8f
        }

        fun drawDivider(dotted: Boolean = true) {
            paint.textSize = 16f
            paint.typeface = Typeface.MONOSPACE
            paint.textAlign = Paint.Align.CENTER
            val line = if (dotted) "- - - - - - - - - - - - - - - - - -" else "-----------------------------------"
            canvas.drawText(line, width / 2f, y, paint)
            y += 22f
        }

        fun drawTwoCols(left: String, right: String, size: Float = 20f, bold: Boolean = false) {
            paint.textSize = size
            paint.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText(left, 14f, y, paint)
            paint.textAlign = Paint.Align.RIGHT
            canvas.drawText(right, (width - 14).toFloat(), y, paint)
            y += size + 8f
        }

        val appName = exchangeData["appName"] as? String ?: "ONIMTA POS"
        val voucherCode = exchangeData["voucherCode"] as? String ?: ""
        val totalAmount = exchangeData["totalAmount"] as? String ?: "LKR 0.00"
        val customerName = exchangeData["customerName"] as? String ?: "Walk-in Customer"
        val cashierName = exchangeData["cashierName"] as? String ?: "Admin"
        val dateTime = exchangeData["dateTime"] as? String ?: ""

        drawCenter(appName, 26f, true)
        drawCenter("EXCHANGE VOUCHER / SLIP", 20f, true)
        drawDivider(false)

        drawTwoCols("Voucher #:", voucherCode, 22f, true)
        drawTwoCols("Date:", dateTime, 18f, false)
        drawTwoCols("Cashier:", cashierName, 18f, false)
        if (customerName.isNotEmpty() && customerName != "Walk-in Customer") {
            drawTwoCols("Customer:", customerName, 18f, false)
        }
        drawDivider(true)

        drawCenter("EXCHANGED ITEMS RETURNED", 19f, true)
        drawDivider(true)

        for (item in items) {
            val desc = item["description"] as? String ?: ""
            val qty = item["qty"] as? String ?: "1"
            val price = item["price"] as? String ?: ""
            val total = item["total"] as? String ?: ""

            paint.textSize = 20f
            paint.typeface = Typeface.DEFAULT_BOLD
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText(desc, 14f, y, paint)
            y += 26f

            drawTwoCols("  $qty x $price", total, 18f, false)
        }

        drawDivider(false)
        drawTwoCols("TOTAL CREDIT VALUE:", totalAmount, 24f, true)
        drawDivider(false)

        y += 10f
        drawCenter("||| |||| | ||||| ||| || ||||", 20f, true)
        drawCenter("* $voucherCode *", 22f, true)
        drawDivider(true)
        drawCenter("Present this voucher barcode to redeem", 16f, false)
        drawCenter("exchange credit on your next bill.", 16f, false)
        y += 20f

        return Bitmap.createBitmap(bitmap, 0, 0, width, y.toInt().coerceAtLeast(100))
    }

    private fun renderReturnBitmap(returnData: Map<String, Any?>): Bitmap {
        val width = 384
        val items = returnData["items"] as? List<Map<String, Any?>> ?: emptyList()
        val estimatedHeight = 550 + (items.size * 55)
        val bitmap = Bitmap.createBitmap(width, estimatedHeight, Bitmap.Config.RGB_565)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)

        val paint = Paint().apply {
            color = Color.BLACK
            isAntiAlias = true
        }

        var y = 35f

        fun drawCenter(text: String, size: Float, bold: Boolean = false) {
            paint.textSize = size
            paint.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            paint.textAlign = Paint.Align.CENTER
            canvas.drawText(text, width / 2f, y, paint)
            y += size + 8f
        }

        fun drawDivider(dotted: Boolean = true) {
            paint.textSize = 16f
            paint.typeface = Typeface.MONOSPACE
            paint.textAlign = Paint.Align.CENTER
            val line = if (dotted) "- - - - - - - - - - - - - - - - - -" else "-----------------------------------"
            canvas.drawText(line, width / 2f, y, paint)
            y += 22f
        }

        fun drawTwoCols(left: String, right: String, size: Float = 20f, bold: Boolean = false) {
            paint.textSize = size
            paint.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText(left, 14f, y, paint)
            paint.textAlign = Paint.Align.RIGHT
            canvas.drawText(right, (width - 14).toFloat(), y, paint)
            y += size + 8f
        }

        val appName = returnData["appName"] as? String ?: "ONIMTA POS"
        val returnNo = returnData["returnNo"] as? String ?: ""
        val refundAmount = returnData["refundAmount"] as? String ?: "LKR 0.00"
        val paymentMethod = returnData["paymentMethod"] as? String ?: "Cash"
        val reason = returnData["reason"] as? String ?: "Customer Return"
        val customerName = returnData["customerName"] as? String ?: "Walk-in Customer"
        val cashierName = returnData["cashierName"] as? String ?: "Admin"
        val dateTime = returnData["dateTime"] as? String ?: ""

        drawCenter(appName, 26f, true)
        drawCenter("RETURN / REFUND RECEIPT", 20f, true)
        drawDivider(false)

        drawTwoCols("Return Ref #:", returnNo, 20f, true)
        drawTwoCols("Date:", dateTime, 18f, false)
        drawTwoCols("Cashier:", cashierName, 18f, false)
        if (customerName.isNotEmpty() && customerName != "Walk-in Customer") {
            drawTwoCols("Customer:", customerName, 18f, false)
        }
        drawTwoCols("Reason:", reason, 18f, false)
        drawDivider(true)

        drawCenter("RETURNED ITEMS", 19f, true)
        drawDivider(true)

        for (item in items) {
            val desc = item["description"] as? String ?: ""
            val qty = item["qty"] as? String ?: "1"
            val price = item["price"] as? String ?: ""
            val total = item["total"] as? String ?: ""

            paint.textSize = 20f
            paint.typeface = Typeface.DEFAULT_BOLD
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText(desc, 14f, y, paint)
            y += 26f

            drawTwoCols("  $qty x $price", total, 18f, false)
        }

        drawDivider(false)
        drawTwoCols("REFUNDED VIA:", paymentMethod, 20f, true)
        drawTwoCols("TOTAL REFUNDED:", refundAmount, 24f, true)
        drawDivider(false)

        y += 30f
        drawCenter("____________________________", 16f, false)
        drawCenter("Cashier Signature", 16f, false)
        y += 20f
        drawCenter("____________________________", 16f, false)
        drawCenter("Customer Signature", 16f, false)
        y += 20f

        return Bitmap.createBitmap(bitmap, 0, 0, width, y.toInt().coerceAtLeast(100))
    }

    fun printHoldReceipt(
        holdData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!waitForPrinterReady()) {
                    onComplete(false, "W-POS 3 printer service is connecting or not installed on this terminal")
                    return@Thread
                }

                val target = printerInstance ?: printerServiceBinder
                if (target != null) {
                    val targetClass = target.javaClass
                    cacheMethods(targetClass)

                    try {
                        printInitMethod?.invoke(target)
                        clearCacheMethod?.invoke(target)
                    } catch (_: Throwable) {}

                    val bitmap = renderHoldBitmap(holdData)

                    if (printPictureMethod != null) {
                        try {
                            val params = printPictureMethod!!.parameterTypes
                            if (params.size == 1 && params[0] == Bitmap::class.java) {
                                printPictureMethod!!.invoke(target, bitmap)
                            } else if (params.size == 2 && params[0] == Bitmap::class.java) {
                                printPictureMethod!!.invoke(target, bitmap, 1)
                            }
                        } catch (_: Throwable) {}
                    }

                    try {
                        printPaperMethod?.invoke(target, 4)
                        printFinishMethod?.invoke(target)
                    } catch (_: Throwable) {}

                    onComplete(true, null)
                } else {
                    onComplete(false, "W-POS 3 printer service not connected")
                }
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing hold receipt on W-POS 3: ${e.message}", e)
                onComplete(false, "W-POS 3 print error: ${e.message}")
            }
        }.start()
    }

    private fun renderHoldBitmap(holdData: Map<String, Any?>): Bitmap {
        val width = 384
        val estimatedHeight = 520
        val bitmap = Bitmap.createBitmap(width, estimatedHeight, Bitmap.Config.RGB_565)
        val canvas = Canvas(bitmap)
        canvas.drawColor(Color.WHITE)

        val paint = Paint().apply {
            color = Color.BLACK
            isAntiAlias = true
        }

        var y = 35f

        fun drawCenter(text: String, size: Float, bold: Boolean = false) {
            paint.textSize = size
            paint.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            paint.textAlign = Paint.Align.CENTER
            canvas.drawText(text, width / 2f, y, paint)
            y += size + 8f
        }

        fun drawDivider(dotted: Boolean = true) {
            paint.textSize = 16f
            paint.typeface = Typeface.MONOSPACE
            paint.textAlign = Paint.Align.CENTER
            val line = if (dotted) "- - - - - - - - - - - - - - - - - -" else "-----------------------------------"
            canvas.drawText(line, width / 2f, y, paint)
            y += 22f
        }

        fun drawTwoCols(left: String, right: String, size: Float = 20f, bold: Boolean = false) {
            paint.textSize = size
            paint.typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText(left, 14f, y, paint)
            paint.textAlign = Paint.Align.RIGHT
            canvas.drawText(right, (width - 14).toFloat(), y, paint)
            y += size + 8f
        }

        val appName = holdData["appName"] as? String ?: "ONIMTA POS"
        val holdNo = holdData["holdNo"] as? String ?: ""
        val totalAmount = holdData["totalAmount"] as? String ?: "LKR 0.00"
        val totalItems = holdData["totalItems"] as? String ?: "0 items"
        val customerName = holdData["customerName"] as? String ?: "Walk-in Customer"
        val cashierName = holdData["cashierName"] as? String ?: "Admin"
        val dateTime = holdData["dateTime"] as? String ?: ""

        drawCenter(appName, 26f, true)
        drawCenter("*** HELD BILL RECEIPT ***", 22f, true)
        drawDivider(false)

        drawTwoCols("Hold Bill #:", holdNo, 22f, true)
        drawTwoCols("Date:", dateTime, 18f, false)
        drawTwoCols("Cashier:", cashierName, 18f, false)
        if (customerName.isNotEmpty() && customerName != "Walk-in Customer") {
            drawTwoCols("Customer:", customerName, 18f, false)
        }
        drawDivider(true)

        drawTwoCols("Total Items:", totalItems, 20f, true)
        drawTwoCols("HELD AMOUNT:", totalAmount, 24f, true)
        drawDivider(false)

        y += 10f
        drawCenter("||| |||| | ||||| ||| || ||||", 20f, true)
        drawCenter("* $holdNo *", 20f, true)
        drawDivider(true)
        drawCenter("Scan barcode at POS to recall bill.", 16f, false)
        drawCenter("Note: Active cart must be empty to recall.", 16f, false)
        drawDivider(false)
        y += 20f

        return Bitmap.createBitmap(bitmap, 0, 0, width, y.toInt().coerceAtLeast(100))
    }
}
