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

                val appName = (receiptData["appName"] as? String ?: "ONIMTA POS").uppercase()
                val invoiceNo = receiptData["invoiceNo"] as? String ?: ""
                val customerName = (receiptData["customerName"] as? String ?: "Walk-in Customer").uppercase()
                val cashierName = (receiptData["cashierName"] as? String ?: "Admin").uppercase()
                val dateStr = receiptData["dateTime"] as? String ?: ""
                val items = receiptData["items"] as? List<Map<String, Any?>> ?: emptyList()
                val subtotal = receiptData["subtotal"] as? String ?: ""
                val discount = receiptData["discount"] as? String ?: ""
                val exchangeCredit = receiptData["exchangeCredit"] as? String ?: ""
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
                        exchangeCredit = exchangeCredit,
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

                        pTwoCols("INVOICE #:", invoiceNo, 20, true)
                        if (dateStr.isNotEmpty()) pTwoCols("DATE:", dateStr, 18, false)
                        pTwoCols("CASHIER:", cashierName, 18, false)
                        pTwoCols("CUSTOMER:", customerName, 18, false)
                        pLine("--------------------------------", 18, 1, false)

                        pTwoCols("LN  PRODUCT", "PRICE QTY TOTAL", 18, true)
                        pLine("--------------------------------", 18, 1, false)

                        var lineNum = 1
                        for (item in items) {
                            val desc = (item["description"] as? String ?: "").uppercase()
                            val qty = item["qty"] as? String ?: "1"
                            val price = item["price"] as? String ?: ""
                            val itemDisc = item["discount"] as? String ?: ""
                            val total = item["total"] as? String ?: ""

                            val lnStr = String.format("%2d. ", lineNum)
                            pLine(lnStr + desc, 19, 0, true)
                            val priceQtyTotal = String.format("%9s %4s %9s", price, qty, total)
                            val pad = (32 - priceQtyTotal.length).coerceAtLeast(0)
                            pLine(" ".repeat(pad) + priceQtyTotal, 18, 0, false)
                            if (itemDisc.isNotEmpty() && itemDisc != "LKR 0.00" && itemDisc != "0.00") {
                                pTwoCols("    ITEM DISC:", "-$itemDisc", 16, false)
                            }
                            lineNum++
                        }
                        pLine("--------------------------------", 18, 1, false)

                        pTwoCols("SUBTOTAL:", subtotal, 20, false)
                        if (discount.isNotEmpty() && discount != "LKR 0.00" && discount != "0.00") {
                            pTwoCols("DISCOUNT:", "-$discount", 20, false)
                        }
                        if (tax.isNotEmpty() && tax != "LKR 0.00" && tax != "0.00") {
                            pTwoCols("TAX:", tax, 20, false)
                        }
                        pLine("--------------------------------", 18, 1, false)
                        pTwoCols("GRAND TOTAL:", grandTotal, 24, true)
                        pLine("--------------------------------", 18, 1, false)

                        if (payments.isNotEmpty()) {
                            for (p in payments) {
                                val method = (p["method"] as? String ?: "PAYMENT").uppercase()
                                val amt = p["amount"] as? String ?: ""
                                pTwoCols(method, amt, 18, false)
                            }
                        }

                        if (totalPaid.isNotEmpty()) pTwoCols("TOTAL PAID:", totalPaid, 20, true)
                        if (change.isNotEmpty() && change != "LKR 0.00" && change != "0.00") {
                            pTwoCols("CHANGE RETURNED:", change, 22, true)
                        }

                        pLine("--------------------------------", 18, 1, false)
                        pLine("THANK YOU FOR SHOPPING!", 18, 1, true)
                        pLine("PLEASE COME AGAIN", 16, 1, false)
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

                val appName = (movementData["appName"] as? String ?: "ONIMTA POS").uppercase()
                val type = (movementData["type"] as? String ?: "CASH MOVEMENT").uppercase()
                val amount = movementData["amount"] as? String ?: ""
                val reason = (movementData["reason"] as? String ?: "").uppercase()
                val cashier = (movementData["cashier"] as? String ?: "Admin").uppercase()
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
        exchangeCredit: String = "",
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
            paint.typeface = Typeface.create(Typeface.MONOSPACE, if (bold) Typeface.BOLD else Typeface.NORMAL)
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
            paint.typeface = Typeface.create(Typeface.MONOSPACE, if (bold) Typeface.BOLD else Typeface.NORMAL)
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText(left, 14f, y, paint)
            paint.textAlign = Paint.Align.RIGHT
            canvas.drawText(right, (width - 14).toFloat(), y, paint)
            y += size + 8f
        }

        fun drawTableCols(
            ln: String,
            product: String,
            price: String,
            qty: String,
            total: String,
            size: Float = 17f,
            bold: Boolean = false
        ) {
            paint.textSize = size
            paint.typeface = Typeface.create(Typeface.MONOSPACE, if (bold) Typeface.BOLD else Typeface.NORMAL)
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText(ln, 14f, y, paint)
            canvas.drawText(product, 46f, y, paint)
            paint.textAlign = Paint.Align.RIGHT
            canvas.drawText(price, 230f, y, paint)
            canvas.drawText(qty, 285f, y, paint)
            canvas.drawText(total, (width - 14).toFloat(), y, paint)
            y += size + 8f
        }

        drawCenter(appName.uppercase(), 26f, true)
        drawCenter("TAX INVOICE RECEIPT", 19f, true)
        drawDivider(false)

        drawTwoCols("INVOICE #:", invoiceNo, 20f, true)
        if (dateStr.isNotEmpty()) drawTwoCols("DATE:", dateStr, 18f, false)
        drawTwoCols("CASHIER:", cashierName.uppercase(), 18f, false)
        drawTwoCols("CUSTOMER:", customerName.uppercase(), 18f, false)
        drawDivider()

        drawTableCols("LN", "PRODUCT", "PRICE", "QTY", "TOTAL", size = 17f, bold = true)
        drawDivider(true)

        var itemIndex = 1
        for (item in items) {
            val desc = (item["description"] as? String ?: "").uppercase()
            val qty = item["qty"] as? String ?: "1"
            val price = item["price"] as? String ?: ""
            val itemDisc = item["discount"] as? String ?: ""
            val total = item["total"] as? String ?: ""

            // Line 1: LN and Product Name
            paint.textSize = 18f
            paint.typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            paint.textAlign = Paint.Align.LEFT
            val lnStr = String.format("%2d.", itemIndex)
            canvas.drawText(lnStr, 14f, y, paint)
            canvas.drawText(desc, 46f, y, paint)
            y += 24f

            // Line 2: Price, Qty, Total aligned under headers
            paint.textSize = 17f
            paint.typeface = Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL)
            paint.textAlign = Paint.Align.RIGHT
            canvas.drawText(price, 230f, y, paint)
            canvas.drawText(qty, 285f, y, paint)
            canvas.drawText(total, (width - 14).toFloat(), y, paint)
            y += 24f

            if (itemDisc.isNotEmpty() && itemDisc != "LKR 0.00" && itemDisc != "0.00") {
                drawTwoCols("    ITEM DISC:", "-$itemDisc", 16f, false)
            }
            itemIndex++
        }
        drawDivider()

        drawTwoCols("SUBTOTAL:", subtotal, 20f, false)
        if (discount.isNotEmpty() && discount != "LKR 0.00" && discount != "0.00") {
            drawTwoCols("DISCOUNT:", "-$discount", 20f, false)
        }
        if (exchangeCredit.isNotEmpty() && exchangeCredit != "LKR 0.00" && exchangeCredit != "0.00") {
            drawTwoCols("EXCHANGE CREDIT:", "-$exchangeCredit", 20f, false)
        }
        if (tax.isNotEmpty() && tax != "LKR 0.00" && tax != "0.00") {
            drawTwoCols("TAX:", tax, 20f, false)
        }
        drawDivider(false)
        drawTwoCols("GRAND TOTAL:", grandTotal, 24f, true)
        drawDivider(false)

        if (payments.isNotEmpty()) {
            for (p in payments) {
                val method = (p["method"] as? String ?: "PAYMENT").uppercase()
                val amt = p["amount"] as? String ?: ""
                drawTwoCols(method, amt, 19f, false)
            }
        }

        if (totalPaid.isNotEmpty()) drawTwoCols("TOTAL PAID:", totalPaid, 20f, true)
        if (change.isNotEmpty() && change != "LKR 0.00" && change != "0.00") {
            drawTwoCols("CHANGE RETURNED:", change, 22f, true)
        }

        drawDivider(true)
        drawCenter("THANK YOU FOR YOUR BUSINESS!", 18f, true)
        drawCenter("PLEASE COME AGAIN", 16f, false)
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

        drawCenter(appName.uppercase(), 26f, true)
        drawCenter(type.uppercase(), 20f, true)
        drawDivider(false)

        drawTwoCols("TOTAL $type:", amount, 24f, true)
        drawTwoCols("REASON / REMARK:", reason.uppercase(), 18f, false)
        drawTwoCols("CASHIER:", cashier.uppercase(), 18f, false)
        drawTwoCols("DATE & TIME:", dateTime, 18f, false)
        drawDivider(true)

        y += 40f
        drawCenter("____________________________", 16f, false)
        drawCenter("CASHIER / MANAGER SIGNATURE", 16f, false)
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

        val appName = (reportData["appName"] as? String ?: "ONIMTA POS").uppercase()
        val title = (reportData["title"] as? String ?: "SHIFT REPORT").uppercase()
        val dayNumber = reportData["dayNumber"] as? String ?: ""
        val shiftNumber = reportData["shiftNumber"] as? String ?: ""
        val cashier = (reportData["cashier"] as? String ?: "").uppercase()
        val isEndReport = reportData["isEndReport"] as? Boolean ?: false
        val openingBalance = reportData["openingBalance"] as? String ?: ""
        val dateTime = reportData["dateTime"] as? String ?: ""

        drawCenter(appName, 26f, true)
        drawCenter(title, 22f, true)
        drawDivider(false)

        drawTwoCols("BUSINESS DAY:", dayNumber, 19f, false)
        drawTwoCols("SHIFT #:", shiftNumber, 19f, false)
        drawTwoCols("CASHIER:", cashier, 19f, false)
        drawTwoCols("DATE & TIME:", dateTime, 17f, false)
        drawDivider(true)

        drawTwoCols("OPENING BALANCE:", openingBalance, 20f, true)

        if (isEndReport) {
            val totalInvoices = reportData["totalInvoices"] as? String ?: "0"
            val grossSales = reportData["grossSales"] as? String ?: ""
            val discount = reportData["discount"] as? String ?: ""
            val netSales = reportData["netSales"] as? String ?: ""
            val cashSales = reportData["cashSales"] as? String ?: ""
            val nonCashSales = reportData["nonCashSales"] as? String ?: "LKR 0.00"
            val nonCashBreakdown = (reportData["nonCashBreakdown"] as? Map<*, *>)?.mapNotNull { (k, v) ->
                if (k != null && v != null) k.toString().uppercase() to v.toString() else null
            }?.toMap() ?: emptyMap()
            val cardSales = reportData["cardSales"] as? String ?: ""
            val paidIn = reportData["paidIn"] as? String ?: ""
            val paidOut = reportData["paidOut"] as? String ?: ""
            val expectedCash = reportData["expectedCash"] as? String ?: ""
            val actualCash = reportData["actualCash"] as? String ?: ""
            val cashDiff = reportData["cashDiff"] as? String ?: ""

            drawTwoCols("TOTAL INVOICES:", totalInvoices, 19f, false)
            drawTwoCols("GROSS SALES:", grossSales, 19f, false)
            if (discount.isNotEmpty() && discount != "LKR 0.00") drawTwoCols("DISCOUNT:", "-$discount", 19f, false)
            drawDivider(true)
            drawTwoCols("NET SALES:", netSales, 21f, true)
            drawDivider(true)

            drawTwoCols("CASH SALES:", cashSales, 19f, true)
            drawTwoCols("NON-CASH SALES:", nonCashSales, 19f, true)
            if (nonCashBreakdown.isNotEmpty()) {
                for ((method, amount) in nonCashBreakdown) {
                    drawTwoCols("  • ${method.uppercase()}:", amount, 17f, false)
                }
            } else if (cardSales.isNotEmpty() && cardSales != "LKR 0.00") {
                drawTwoCols("  • CARD SALES:", cardSales, 17f, false)
            }
            drawTwoCols("CASH PAID IN (+):", paidIn, 19f, false)
            drawTwoCols("CASH PAID OUT (-):", paidOut, 19f, false)
            drawDivider(true)

            drawTwoCols("EXPECTED CASH:", expectedCash, 20f, true)
            drawTwoCols("ACTUAL CASH IN HAND:", actualCash, 20f, true)
            drawTwoCols("CASH DIFFERENCE:", cashDiff, 21f, true)
        }

        drawDivider(false)
        y += 40f
        drawCenter("____________________________", 16f, false)
        drawCenter("SUPERVISOR / CASHIER SIGNATURE", 16f, false)
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
            paint.typeface = Typeface.create(Typeface.MONOSPACE, if (bold) Typeface.BOLD else Typeface.NORMAL)
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText(left, 14f, y, paint)
            paint.textAlign = Paint.Align.RIGHT
            canvas.drawText(right, (width - 14).toFloat(), y, paint)
            y += size + 8f
        }

        fun drawTableCols(
            ln: String,
            product: String,
            price: String,
            qty: String,
            total: String,
            size: Float = 17f,
            bold: Boolean = false
        ) {
            paint.textSize = size
            paint.typeface = Typeface.create(Typeface.MONOSPACE, if (bold) Typeface.BOLD else Typeface.NORMAL)
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText(ln, 14f, y, paint)
            canvas.drawText(product, 46f, y, paint)
            paint.textAlign = Paint.Align.RIGHT
            canvas.drawText(price, 230f, y, paint)
            canvas.drawText(qty, 285f, y, paint)
            canvas.drawText(total, (width - 14).toFloat(), y, paint)
            y += size + 8f
        }

        val appName = (exchangeData["appName"] as? String ?: "ONIMTA POS").uppercase()
        val voucherCode = exchangeData["voucherCode"] as? String ?: ""
        val totalAmount = exchangeData["totalAmount"] as? String ?: "LKR 0.00"
        val customerName = (exchangeData["customerName"] as? String ?: "Walk-in Customer").uppercase()
        val cashierName = (exchangeData["cashierName"] as? String ?: "Admin").uppercase()
        val dateTime = exchangeData["dateTime"] as? String ?: ""

        drawCenter(appName, 26f, true)
        drawCenter("EXCHANGE VOUCHER / SLIP", 20f, true)
        drawDivider(false)

        drawTwoCols("VOUCHER #:", voucherCode, 22f, true)
        drawTwoCols("DATE:", dateTime, 18f, false)
        drawTwoCols("CASHIER:", cashierName, 18f, false)
        if (customerName.isNotEmpty() && customerName != "WALK-IN CUSTOMER") {
            drawTwoCols("CUSTOMER:", customerName, 18f, false)
        }
        drawDivider(true)

        drawTableCols("LN", "PRODUCT", "PRICE", "QTY", "TOTAL", size = 17f, bold = true)
        drawDivider(true)

        var itemIndex = 1
        for (item in items) {
            val desc = (item["description"] as? String ?: "").uppercase()
            val qty = item["qty"] as? String ?: "1"
            val price = item["price"] as? String ?: ""
            val total = item["total"] as? String ?: ""

            // Line 1: LN and Product Name
            paint.textSize = 18f
            paint.typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            paint.textAlign = Paint.Align.LEFT
            val lnStr = String.format("%2d.", itemIndex)
            canvas.drawText(lnStr, 14f, y, paint)
            canvas.drawText(desc, 46f, y, paint)
            y += 24f

            // Line 2: Price, Qty, Total aligned under headers
            paint.textSize = 17f
            paint.typeface = Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL)
            paint.textAlign = Paint.Align.RIGHT
            canvas.drawText(price, 230f, y, paint)
            canvas.drawText(qty, 285f, y, paint)
            canvas.drawText(total, (width - 14).toFloat(), y, paint)
            y += 24f

            itemIndex++
        }

        drawDivider(false)
        drawTwoCols("TOTAL CREDIT VALUE:", totalAmount, 24f, true)
        drawDivider(false)

        y += 10f
        val barcodeBmp = BarcodeBitmapHelper.createCrispCode128(voucherCode, width, 110)
        if (barcodeBmp != null) {
            val left = (width - barcodeBmp.width) / 2f
            canvas.drawBitmap(barcodeBmp, left, y, null)
            y += barcodeBmp.height + 8f
        }
        drawCenter("* $voucherCode *", 20f, true)

        val qrBmp = BarcodeBitmapHelper.createCrispQrCode(voucherCode, 180)
        if (qrBmp != null) {
            val qrLeft = (width - qrBmp.width) / 2f
            canvas.drawBitmap(qrBmp, qrLeft, y, null)
            y += qrBmp.height + 8f
        }

        drawDivider(true)
        drawCenter("Scan barcode or QR code to redeem", 16f, false)
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
            paint.typeface = Typeface.create(Typeface.MONOSPACE, if (bold) Typeface.BOLD else Typeface.NORMAL)
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText(left, 14f, y, paint)
            paint.textAlign = Paint.Align.RIGHT
            canvas.drawText(right, (width - 14).toFloat(), y, paint)
            y += size + 8f
        }

        fun drawTableCols(
            ln: String,
            product: String,
            price: String,
            qty: String,
            total: String,
            size: Float = 17f,
            bold: Boolean = false
        ) {
            paint.textSize = size
            paint.typeface = Typeface.create(Typeface.MONOSPACE, if (bold) Typeface.BOLD else Typeface.NORMAL)
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText(ln, 14f, y, paint)
            canvas.drawText(product, 46f, y, paint)
            paint.textAlign = Paint.Align.RIGHT
            canvas.drawText(price, 230f, y, paint)
            canvas.drawText(qty, 285f, y, paint)
            canvas.drawText(total, (width - 14).toFloat(), y, paint)
            y += size + 8f
        }

        val appName = (returnData["appName"] as? String ?: "ONIMTA POS").uppercase()
        val returnNo = returnData["returnNo"] as? String ?: ""
        val refundAmount = returnData["refundAmount"] as? String ?: "LKR 0.00"
        val paymentMethod = (returnData["paymentMethod"] as? String ?: "CASH").uppercase()
        val reason = (returnData["reason"] as? String ?: "CUSTOMER RETURN").uppercase()
        val customerName = (returnData["customerName"] as? String ?: "Walk-in Customer").uppercase()
        val cashierName = (returnData["cashierName"] as? String ?: "Admin").uppercase()
        val dateTime = returnData["dateTime"] as? String ?: ""

        drawCenter(appName, 26f, true)
        drawCenter("RETURN / REFUND RECEIPT", 20f, true)
        drawDivider(false)

        drawTwoCols("RETURN REF #:", returnNo, 20f, true)
        drawTwoCols("DATE:", dateTime, 18f, false)
        drawTwoCols("CASHIER:", cashierName, 18f, false)
        if (customerName.isNotEmpty() && customerName != "WALK-IN CUSTOMER") {
            drawTwoCols("CUSTOMER:", customerName, 18f, false)
        }
        drawTwoCols("REASON:", reason, 18f, false)
        drawDivider(true)

        drawTableCols("LN", "PRODUCT", "PRICE", "QTY", "TOTAL", size = 17f, bold = true)
        drawDivider(true)

        var itemIndex = 1
        for (item in items) {
            val desc = (item["description"] as? String ?: "").uppercase()
            val qty = item["qty"] as? String ?: "1"
            val price = item["price"] as? String ?: ""
            val total = item["total"] as? String ?: ""

            // Line 1: LN and Product Name
            paint.textSize = 18f
            paint.typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            paint.textAlign = Paint.Align.LEFT
            val lnStr = String.format("%2d.", itemIndex)
            canvas.drawText(lnStr, 14f, y, paint)
            canvas.drawText(desc, 46f, y, paint)
            y += 24f

            // Line 2: Price, Qty, Total aligned under headers
            paint.textSize = 17f
            paint.typeface = Typeface.create(Typeface.MONOSPACE, Typeface.NORMAL)
            paint.textAlign = Paint.Align.RIGHT
            canvas.drawText(price, 230f, y, paint)
            canvas.drawText(qty, 285f, y, paint)
            canvas.drawText(total, (width - 14).toFloat(), y, paint)
            y += 24f

            itemIndex++
        }

        drawDivider(false)
        drawTwoCols("REFUNDED VIA:", paymentMethod, 20f, true)
        drawTwoCols("TOTAL REFUNDED:", refundAmount, 24f, true)
        drawDivider(false)

        y += 30f
        drawCenter("____________________________", 16f, false)
        drawCenter("CASHIER SIGNATURE", 16f, false)
        y += 20f
        drawCenter("____________________________", 16f, false)
        drawCenter("CUSTOMER SIGNATURE", 16f, false)
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

        val appName = (holdData["appName"] as? String ?: "ONIMTA POS").uppercase()
        val holdNo = holdData["holdNo"] as? String ?: ""
        val totalAmount = holdData["totalAmount"] as? String ?: "LKR 0.00"
        val totalItems = (holdData["totalItems"] as? String ?: "0 items").uppercase()
        val customerName = (holdData["customerName"] as? String ?: "Walk-in Customer").uppercase()
        val cashierName = (holdData["cashierName"] as? String ?: "Admin").uppercase()
        val dateTime = holdData["dateTime"] as? String ?: ""

        drawCenter(appName, 26f, true)
        drawCenter("*** HELD BILL RECEIPT ***", 22f, true)
        drawDivider(false)

        drawTwoCols("HOLD BILL #:", holdNo, 22f, true)
        drawTwoCols("DATE:", dateTime, 18f, false)
        drawTwoCols("CASHIER:", cashierName, 18f, false)
        if (customerName.isNotEmpty() && customerName != "WALK-IN CUSTOMER") {
            drawTwoCols("CUSTOMER:", customerName, 18f, false)
        }
        drawDivider(true)

        drawTwoCols("TOTAL ITEMS:", totalItems, 20f, true)
        drawTwoCols("HELD AMOUNT:", totalAmount, 24f, true)
        drawDivider(false)

        y += 10f
        val barcodeBmp = BarcodeBitmapHelper.createCrispCode128(holdNo, width, 110)
        if (barcodeBmp != null) {
            val left = (width - barcodeBmp.width) / 2f
            canvas.drawBitmap(barcodeBmp, left, y, null)
            y += barcodeBmp.height + 8f
        }
        drawCenter("* $holdNo *", 20f, true)

        val qrBmp = BarcodeBitmapHelper.createCrispQrCode(holdNo, 180)
        if (qrBmp != null) {
            val qrLeft = (width - qrBmp.width) / 2f
            canvas.drawBitmap(qrBmp, qrLeft, y, null)
            y += qrBmp.height + 8f
        }

        drawDivider(true)
        drawCenter("Scan barcode / QR code at POS to recall.", 16f, false)
        drawCenter("Note: Active cart must be empty to recall.", 16f, false)
        drawDivider(false)
        y += 20f

        return Bitmap.createBitmap(bitmap, 0, 0, width, y.toInt().coerceAtLeast(100))
    }

    fun printItemWiseSalesReport(
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

                    val bitmap = renderItemWiseReportBitmap(reportData)
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
                Log.e(TAG, "Error printing item-wise sales report on W-POS 3: ${e.message}", e)
                onComplete(false, "W-POS 3 print error: ${e.message}")
            }
        }.start()
    }

    fun printTotalSalesReport(
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

                    val bitmap = renderTotalSalesReportBitmap(reportData)
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
                Log.e(TAG, "Error printing total sales report on W-POS 3: ${e.message}", e)
                onComplete(false, "W-POS 3 print error: ${e.message}")
            }
        }.start()
    }

    private fun renderItemWiseReportBitmap(reportData: Map<String, Any?>): Bitmap {
        val width = 384
        val items = reportData["items"] as? List<Map<String, Any?>> ?: emptyList()
        val estimatedHeight = 450 + (items.size * 55)
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

        val appName = (reportData["appName"] as? String ?: "ONIMTA POS").uppercase()
        val title = (reportData["title"] as? String ?: "ITEM-WISE SALES REPORT").uppercase()
        val period = (reportData["period"] as? String ?: "TODAY").uppercase()
        val cashier = (reportData["cashierName"] as? String ?: "Admin").uppercase()
        val dateTime = reportData["dateTime"] as? String ?: ""
        val totalQty = reportData["totalQuantity"] as? String ?: "0"
        val totalRevenue = reportData["totalRevenue"] as? String ?: "LKR 0.00"

        drawCenter(appName, 26f, true)
        drawCenter(title, 20f, true)
        drawDivider(false)

        drawTwoCols("PERIOD:", period, 18f, false)
        drawTwoCols("CASHIER:", cashier, 18f, false)
        if (dateTime.isNotEmpty()) drawTwoCols("DATE & TIME:", dateTime, 18f, false)
        drawDivider(true)

        paint.textSize = 18f
        paint.typeface = Typeface.DEFAULT_BOLD
        paint.textAlign = Paint.Align.LEFT
        canvas.drawText("ITEM DESCRIPTION", 14f, y, paint)
        y += 22f
        drawTwoCols("  SOLD QTY", "TOTAL AMOUNT", 18f, true)
        drawDivider(true)

        var rank = 1
        for (item in items) {
            val desc = (item["description"] as? String ?: "").uppercase()
            val qty = item["qty"] as? String ?: "0"
            val total = item["total"] as? String ?: "LKR 0.00"

            paint.textSize = 19f
            paint.typeface = Typeface.DEFAULT_BOLD
            paint.textAlign = Paint.Align.LEFT
            canvas.drawText("$rank. $desc", 14f, y, paint)
            y += 24f

            drawTwoCols("   QTY: $qty", total, 18f, false)
            rank++
        }

        drawDivider(false)
        drawTwoCols("TOTAL ITEMS SOLD:", totalQty, 20f, true)
        drawTwoCols("TOTAL REVENUE:", totalRevenue, 24f, true)
        drawDivider(false)
        y += 20f

        return Bitmap.createBitmap(bitmap, 0, 0, width, y.toInt().coerceAtLeast(100))
    }

    private fun renderTotalSalesReportBitmap(reportData: Map<String, Any?>): Bitmap {
        val width = 384
        val estimatedHeight = 650
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

        val appName = (reportData["appName"] as? String ?: "ONIMTA POS").uppercase()
        val title = (reportData["title"] as? String ?: "TOTAL SALES REPORT").uppercase()
        val period = (reportData["period"] as? String ?: "TODAY").uppercase()
        val cashier = (reportData["cashierName"] as? String ?: "Admin").uppercase()
        val dateTime = reportData["dateTime"] as? String ?: ""

        val totalInvoices = reportData["totalInvoices"] as? String ?: "0"
        val grossSales = reportData["grossSales"] as? String ?: "LKR 0.00"
        val discount = reportData["discount"] as? String ?: "LKR 0.00"
        val tax = reportData["tax"] as? String ?: "LKR 0.00"
        val netSales = reportData["netSales"] as? String ?: "LKR 0.00"

        val returnsCount = reportData["returnsCount"] as? String ?: "0"
        val returnsAmount = reportData["returnsAmount"] as? String ?: "LKR 0.00"
        val totalNetRevenue = reportData["totalNetRevenue"] as? String ?: "LKR 0.00"

        val cashSales = reportData["cashSales"] as? String ?: "LKR 0.00"
        val nonCashSales = reportData["nonCashSales"] as? String ?: "LKR 0.00"
        val nonCashBreakdown = (reportData["nonCashBreakdown"] as? Map<*, *>)?.mapNotNull { (k, v) ->
            if (k != null && v != null) k.toString().uppercase() to v.toString() else null
        }?.toMap() ?: emptyMap()
        val cardSales = reportData["cardSales"] as? String ?: "LKR 0.00"
        val qrSales = reportData["qrSales"] as? String ?: "LKR 0.00"
        val creditSales = reportData["creditSales"] as? String ?: "LKR 0.00"

        drawCenter(appName, 28f, true)
        drawCenter(title, 22f, true)
        drawDivider(false)

        drawTwoCols("PERIOD:", period, 18f, false)
        drawTwoCols("CASHIER:", cashier, 18f, false)
        if (dateTime.isNotEmpty()) drawTwoCols("DATE:", dateTime, 18f, false)
        drawDivider(true)

        paint.textSize = 18f
        paint.typeface = Typeface.DEFAULT_BOLD
        paint.textAlign = Paint.Align.LEFT
        canvas.drawText("SALES SUMMARY", 14f, y, paint)
        y += 24f

        drawTwoCols("TOTAL INVOICES:", totalInvoices, 18f, false)
        drawTwoCols("GROSS SALES:", grossSales, 18f, false)
        if (discount.isNotEmpty() && discount != "LKR 0.00") drawTwoCols("DISCOUNTS:", "-$discount", 18f, false)
        if (tax.isNotEmpty() && tax != "LKR 0.00") drawTwoCols("TAX:", tax, 18f, false)
        drawDivider(true)
        drawTwoCols("NET SALES:", netSales, 20f, true)
        if (returnsCount != "0") drawTwoCols("RETURNS ($returnsCount BILLS):", "-$returnsAmount", 18f, false)
        drawDivider(false)
        drawTwoCols("TOTAL NET REVENUE:", totalNetRevenue, 24f, true)
        drawDivider(false)

        paint.textSize = 18f
        paint.typeface = Typeface.DEFAULT_BOLD
        paint.textAlign = Paint.Align.LEFT
        canvas.drawText("PAYMENTS / TENDER BREAKDOWN", 14f, y, paint)
        y += 24f

        drawTwoCols("CASH SALES:", cashSales, 18f, true)
        drawTwoCols("NON-CASH SALES:", nonCashSales, 18f, true)
        if (nonCashBreakdown.isNotEmpty()) {
            for ((method, amount) in nonCashBreakdown) {
                drawTwoCols("  • ${method.uppercase()}:", amount, 16f, false)
            }
        } else {
            if (cardSales != "LKR 0.00" && cardSales.isNotEmpty()) drawTwoCols("  • CARD SALES:", cardSales, 16f, false)
            if (qrSales != "LKR 0.00" && qrSales.isNotEmpty()) drawTwoCols("  • QR / ONLINE:", qrSales, 16f, false)
            if (creditSales != "LKR 0.00" && creditSales.isNotEmpty()) drawTwoCols("  • CREDIT SALES:", creditSales, 16f, false)
        }
        drawDivider(false)
        y += 20f

        return Bitmap.createBitmap(bitmap, 0, 0, width, y.toInt().coerceAtLeast(100))
    }
}
