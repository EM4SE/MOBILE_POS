package com.onimta.mobile_pos

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.util.Log
import dalvik.system.DexClassLoader
import java.io.File
import java.io.FileOutputStream
import java.lang.reflect.Proxy

class NexgoPrinterManager(private val context: Context) {
    private val TAG = "NexgoPrinterManager"
    private var isInitialized = false
    private var deviceEngine: Any? = null
    private var printer: Any? = null
    private var alignEnumClass: Class<*>? = null
    private var onPrintListenerClass: Class<*>? = null

    init {
        initSdk()
    }

    private fun initSdk() {
        try {
            // 1. Prepare JAR archive from assets
            val dexDir = File(context.codeCacheDir, "nexgo_dex")
            if (!dexDir.exists()) dexDir.mkdirs()
            val optDir = File(dexDir, "opt")
            if (!optDir.exists()) optDir.mkdirs()

            val jarFile = File(dexDir, "nexgo_sdk.jar")

            // Always copy if missing or different size
            val assetStream = context.assets.open("nexgo_sdk.jar")
            val assetLength = assetStream.available()
            if (!jarFile.exists() || jarFile.length() != assetLength.toLong()) {
                assetStream.use { input ->
                    FileOutputStream(jarFile).use { output ->
                        input.copyTo(output)
                    }
                }
                Log.d(TAG, "Copied nexgo_sdk.jar to ${jarFile.absolutePath} (size: ${jarFile.length()})")
            } else {
                assetStream.close()
            }

            val searchPath = "${context.applicationInfo.nativeLibraryDir}:/data/app/com.nexgo.apiv3demo-1/lib/arm:/system/lib"

            // 2. Load SDK classes via DexClassLoader
            val classLoader = DexClassLoader(
                jarFile.absolutePath,
                optDir.absolutePath,
                searchPath,
                context.classLoader
            )

            val apiProxyClass = classLoader.loadClass("com.nexgo.oaf.apiv3.APIProxy")
            Log.d(TAG, "APIProxy methods: ${apiProxyClass.methods.map { it.name + "(" + it.parameterTypes.joinToString { p -> p.simpleName } + ")" }}")

            val getDeviceEngineMethod = apiProxyClass.methods.firstOrNull { it.name == "getDeviceEngine" }
                ?: apiProxyClass.declaredMethods.firstOrNull { it.name == "getDeviceEngine" }

            if (getDeviceEngineMethod == null) {
                Log.e(TAG, "Could not find getDeviceEngine method on APIProxy")
                isInitialized = false
                return
            }

            getDeviceEngineMethod.isAccessible = true
            deviceEngine = if (getDeviceEngineMethod.parameterTypes.isEmpty()) {
                getDeviceEngineMethod.invoke(null)
            } else if (getDeviceEngineMethod.parameterTypes.size == 1 && Context::class.java.isAssignableFrom(getDeviceEngineMethod.parameterTypes[0])) {
                getDeviceEngineMethod.invoke(null, context.applicationContext)
            } else {
                getDeviceEngineMethod.invoke(null, context)
            }

            Log.d(TAG, "deviceEngine obtained: $deviceEngine")

            if (deviceEngine != null) {
                Log.d(TAG, "DeviceEngine methods: ${deviceEngine!!.javaClass.methods.map { it.name }}")
                val getPrinterMethod = deviceEngine!!.javaClass.getMethod("getPrinter")
                printer = getPrinterMethod.invoke(deviceEngine)
                alignEnumClass = classLoader.loadClass("com.nexgo.oaf.apiv3.device.printer.AlignEnum")
                onPrintListenerClass = classLoader.loadClass("com.nexgo.oaf.apiv3.device.printer.OnPrintListener")
                isInitialized = printer != null
                Log.d(TAG, "Nexgo Printer initialized successfully: $printer")
            } else {
                Log.e(TAG, "getDeviceEngine returned null")
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to initialize Nexgo SDK: ${e.message}", e)
            isInitialized = false
        }
    }

    fun isPrinterReady(): Boolean {
        if (!isInitialized || printer == null) {
            initSdk()
        }
        return isInitialized && printer != null
    }

    @Suppress("UNCHECKED_CAST")
    private fun getAlignEnum(alignStr: String): Any? {
        return try {
            val enumCls = alignEnumClass as? Class<out Enum<*>> ?: return null
            java.lang.Enum.valueOf(enumCls, alignStr.uppercase())
        } catch (e: Exception) {
            null
        }
    }

    private fun wrapText(text: String, maxChars: Int): List<String> {
        if (text.length <= maxChars) return listOf(text)
        val words = text.split(" ")
        val result = mutableListOf<String>()
        var cur = StringBuilder()
        for (w in words) {
            if (cur.isEmpty()) {
                cur.append(w)
            } else if (cur.length + 1 + w.length <= maxChars) {
                cur.append(" ").append(w)
            } else {
                result.add(cur.toString())
                cur = StringBuilder(w)
            }
        }
        if (cur.isNotEmpty()) result.add(cur.toString())
        return result
    }

    private fun printDivider(
        p: Any,
        pClass: Class<*>,
        isDouble: Boolean = false,
        alignCenter: Any? = null,
        printFallback: ((String, Int, Any?, Boolean) -> Unit)? = null
    ) {
        try {
            val h = if (isDouble) 18 else 14
            val bmp = Bitmap.createBitmap(384, h, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            canvas.drawColor(Color.WHITE)
            val paint = Paint().apply {
                color = Color.BLACK
                style = Paint.Style.STROKE
                strokeWidth = if (isDouble) 3.0f else 3.5f
                isAntiAlias = false
            }
            val leftX = 4f
            val rightX = 380f
            val y = h / 2f
            if (isDouble) {
                canvas.drawLine(leftX, y - 3.5f, rightX, y - 3.5f, paint)
                canvas.drawLine(leftX, y + 3.5f, rightX, y + 3.5f, paint)
            } else {
                canvas.drawLine(leftX, y, rightX, y, paint)
            }
            val appendImageMethod = pClass.methods.firstOrNull { it.name == "appendImage" }
            if (appendImageMethod != null) {
                val pTypes = appendImageMethod.parameterTypes
                if (pTypes.size == 1 && pTypes[0] == Bitmap::class.java) {
                    appendImageMethod.invoke(p, bmp)
                    return
                } else if (pTypes.size >= 2 && pTypes[0] == Bitmap::class.java) {
                    appendImageMethod.invoke(p, bmp, alignCenter)
                    return
                }
            }
        } catch (e: Throwable) {
            Log.w(TAG, "printDivider error: ${e.message}")
        }
        val char = if (isDouble) "=" else "-"
        printFallback?.invoke(char.repeat(32), 24, alignCenter, true)
    }

    private fun printReceiptHeader(
        receiptData: Map<String, Any?>,
        title: String,
        printLine: (String, Int, Any?, Boolean) -> Unit,
        alignCenter: Any?
    ) {
        val storeNameRaw = (receiptData["storeName"] as? String)?.trim()?.takeIf { it.isNotEmpty() }
            ?: (receiptData["appName"] as? String)?.trim()?.takeIf { it.isNotEmpty() }
            ?: "ONIMTA POS"
        val storeAddress = (receiptData["storeAddress"] as? String)?.trim() ?: ""
        val storePhone = (receiptData["storePhone"] as? String)?.trim() ?: ""

        val normalizedStoreName = storeNameRaw.replace("\\n", "\n")
        val nameLines = normalizedStoreName.split("\n").map { it.trim() }.filter { it.isNotEmpty() }

        if (nameLines.isNotEmpty()) {
            val firstLine = nameLines[0].uppercase()
            val bigSize = if (firstLine.length <= 12) 44 else if (firstLine.length <= 18) 38 else 32
            printLine(firstLine, bigSize, alignCenter, true)

            for (i in 1 until nameLines.size) {
                printLine(nameLines[i].uppercase(), 24, alignCenter, true)
            }
        }

        if (storeAddress.isNotEmpty()) {
            val normalizedAddr = storeAddress.replace("\\n", "\n")
            val addrLines = normalizedAddr.split("\n").map { it.trim() }.filter { it.isNotEmpty() }
            for (addrLine in addrLines) {
                val wrapped = wrapText(addrLine, 32)
                for (wl in wrapped) {
                    printLine(wl, 20, alignCenter, false)
                }
            }
        }

        if (storePhone.isNotEmpty()) {
            val phoneText = if (storePhone.uppercase().startsWith("TEL") || storePhone.uppercase().startsWith("PHONE")) {
                storePhone
            } else {
                "TEL: $storePhone"
            }
            printLine(phoneText, 20, alignCenter, false)
        }

        if (title.isNotEmpty()) {
            printLine(title, 22, alignCenter, true)
        }
        printLine("--------------------------------", 20, alignCenter, false)
    }

    fun printReceipt(
        receiptData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        if (!isPrinterReady()) {
            onComplete(false, "NEXGO thermal printer not initialized or device engine unavailable")
            return
        }

        try {
            val p = printer ?: return onComplete(false, "Printer instance null")
            val pClass = p.javaClass

            // 1. Reset / Init Printer
            pClass.getMethod("initPrinter").invoke(p)
            try {
                pClass.getMethod("setLetterSpacing", Int::class.javaPrimitiveType).invoke(p, 0)
            } catch (_: Exception) {}

            val alignLeft = getAlignEnum("LEFT")
            val alignCenter = getAlignEnum("CENTER")
            val alignRight = getAlignEnum("RIGHT")

            // Method handles
            val appendTextMethod = pClass.getMethod(
                "appendPrnStr",
                String::class.java,
                Int::class.javaPrimitiveType,
                alignEnumClass,
                Boolean::class.javaPrimitiveType
            )

            val appendTwoColsMethod = try {
                pClass.getMethod(
                    "appendPrnStr",
                    String::class.java,
                    String::class.java,
                    Int::class.javaPrimitiveType,
                    Boolean::class.javaPrimitiveType
                )
            } catch (_: Exception) {
                null
            }

            fun printLine(text: String, size: Int = 22, align: Any? = alignLeft, bold: Boolean = false) {
                if (text == "--------------------------------" || text == "-".repeat(32)) {
                    this@NexgoPrinterManager.printDivider(p, pClass, false, alignCenter) { t: String, s: Int, a: Any?, b: Boolean ->
                        appendTextMethod.invoke(p, t, s, a ?: alignLeft, b)
                    }
                    return
                } else if (text == "================================" || text == "=".repeat(32)) {
                    this@NexgoPrinterManager.printDivider(p, pClass, true, alignCenter) { t: String, s: Int, a: Any?, b: Boolean ->
                        appendTextMethod.invoke(p, t, s, a ?: alignLeft, b)
                    }
                    return
                }
                appendTextMethod.invoke(p, text, size, align ?: alignLeft, bold)
            }

            fun printTwoCols(left: String, right: String, size: Int = 22, bold: Boolean = false) {
                if (appendTwoColsMethod != null) {
                    appendTwoColsMethod.invoke(p, left, right, size, bold)
                } else {
                    val totalWidth = 32
                    val pad = (totalWidth - left.length - right.length).coerceAtLeast(1)
                    val line = left + " ".repeat(pad) + right
                    printLine(line, size, alignLeft, bold)
                }
            }

            // Header Info
            val invoiceNo = (receiptData["invoiceNo"] as? String ?: "").uppercase()
            val customerName = (receiptData["customerName"] as? String ?: "WALK-IN CUSTOMER").uppercase()
            val cashierName = (receiptData["cashierName"] as? String ?: "ADMIN").uppercase()
            val dateStr = receiptData["dateTime"] as? String ?: ""

            printReceiptHeader(receiptData, "ORDER INVOICE", ::printLine, alignCenter)

            printTwoCols("INVOICE #:", invoiceNo, 22, true)
            if (dateStr.isNotEmpty()) {
                printTwoCols("DATE:", dateStr, 20, false)
            }
            printTwoCols("CASHIER:", cashierName, 20, false)
            printTwoCols("CUSTOMER:", customerName, 20, false)
            printLine("--------------------------------", 20, alignCenter, false)

            // Items List
            val items = receiptData["items"] as? List<Map<String, Any?>> ?: emptyList()
            printTwoCols("LN  PRODUCT", String.format("%9s %4s %9s", "PRICE", "QTY", "TOTAL"), 20, true)
            printLine("--------------------------------", 20, alignCenter, false)

            var ln = 1
            for (item in items) {
                val desc = (item["description"] as? String ?: "").uppercase()
                val qty = item["qty"] as? String ?: "1"
                val price = item["price"] as? String ?: ""
                val total = item["total"] as? String ?: ""
                val cleanPrice = price.replace("Rs.", "", ignoreCase = true).replace("Rs", "", ignoreCase = true).replace("LKR", "", ignoreCase = true).trim()
                val cleanTotal = total.replace("Rs.", "", ignoreCase = true).replace("Rs", "", ignoreCase = true).replace("LKR", "", ignoreCase = true).trim()
                val itemDisc = item["discount"] as? String ?: ""

                val prefix = String.format("%2d. ", ln)
                val indent = " ".repeat(prefix.length)
                val maxChars = 32 - prefix.length
                val words = desc.split(" ")
                val lines = mutableListOf<String>()
                var cur = StringBuilder()
                for (w in words) {
                    if (w.isEmpty()) continue
                    if (cur.length + w.length + (if (cur.isNotEmpty()) 1 else 0) <= maxChars) {
                        if (cur.isNotEmpty()) cur.append(" ")
                        cur.append(w)
                    } else {
                        if (cur.isNotEmpty()) {
                            lines.add(cur.toString())
                            cur = StringBuilder(w)
                        } else {
                            lines.add(w)
                        }
                    }
                }
                if (cur.isNotEmpty()) lines.add(cur.toString())
                for (i in lines.indices) {
                    if (i == 0) printLine(prefix + lines[i], 21, alignLeft, true)
                    else printLine(indent + lines[i], 21, alignLeft, true)
                }

                val priceQtyTotal = String.format("%9s %4s %9s", cleanPrice, qty, cleanTotal)
                val pad = (32 - priceQtyTotal.length).coerceAtLeast(0)
                printLine(" ".repeat(pad) + priceQtyTotal, 21, alignLeft, true)
                if (itemDisc.isNotEmpty() && itemDisc != "LKR 0.00" && itemDisc != "0.00") {
                    printTwoCols("    ITEM DISC:", "-$itemDisc", 18, false)
                }
                ln++
            }
            printLine("--------------------------------", 20, alignCenter, false)

            // Summary Totals
            val subtotal = receiptData["subtotal"] as? String ?: ""
            val discount = receiptData["discount"] as? String ?: ""
            val exchangeCredit = receiptData["exchangeCredit"] as? String ?: ""
            val tax = receiptData["tax"] as? String ?: ""
            val grandTotal = receiptData["grandTotal"] as? String ?: ""

            printTwoCols("SUBTOTAL:", subtotal, 22, false)
            if (discount.isNotEmpty() && discount != "LKR 0.00" && discount != "0.00") {
                printTwoCols("DISCOUNT:", "-$discount", 22, false)
            }
            if (exchangeCredit.isNotEmpty() && exchangeCredit != "LKR 0.00" && exchangeCredit != "0.00") {
                printTwoCols("EXCHANGE CREDIT:", "-$exchangeCredit", 22, false)
            }
            if (tax.isNotEmpty() && tax != "LKR 0.00" && tax != "0.00") {
                printTwoCols("TAX:", tax, 22, false)
            }
            printLine("================================", 20, alignCenter, false)
            printTwoCols("GRAND TOTAL:", grandTotal, 30, true)
            printLine("================================", 20, alignCenter, false)

            // Payments Breakdown
            val payments = receiptData["payments"] as? List<Map<String, Any?>> ?: emptyList()
            if (payments.isNotEmpty()) {
                printLine("PAYMENTS:", 20, alignLeft, true)
                for (pay in payments) {
                    val method = (pay["method"] as? String ?: "PAYMENT").uppercase()
                    val amt = pay["amount"] as? String ?: ""
                    printTwoCols(method, amt, 22, false)
                }
            }

            val totalPaid = receiptData["paidAmount"] as? String ?: ""
            val change = receiptData["changeAmount"] as? String ?: ""

            if (totalPaid.isNotEmpty()) {
                printTwoCols("TOTAL PAID:", totalPaid, 22, true)
            }
            if (change.isNotEmpty() && change != "LKR 0.00" && change != "0.00") {
                printTwoCols("CHANGE RETURNED:", change, 24, true)
            }

            printLine("--------------------------------", 20, alignCenter, false)
            printLine("THANK YOU FOR SHOPPING WITH US!", 20, alignCenter, true)
            printLine("PLEASE COME AGAIN", 18, alignCenter, false)

            // Feed paper so paper clears the cutter
            try {
                pClass.getMethod("feedPaper", Int::class.javaPrimitiveType).invoke(p, 4)
            } catch (_: Exception) {}

            // Start Print via Listener Proxy
            if (onPrintListenerClass != null) {
                val listenerProxy = Proxy.newProxyInstance(
                    onPrintListenerClass!!.classLoader,
                    arrayOf(onPrintListenerClass)
                ) { _, method, args ->
                    if (method.name == "onPrintResult") {
                        val resultCode = args?.getOrNull(0) as? Int ?: 0
                        Log.d(TAG, "onPrintResult: $resultCode")
                        if (resultCode == 0) {
                            onComplete(true, null)
                        } else {
                            val errorDescription = when (resultCode) {
                                -1005 -> "Printer out of paper. Please insert paper roll."
                                -1006 -> "Printer cover is open. Please close cover."
                                -1003 -> "Printer is overheating. Please wait."
                                -1004 -> "Battery low for printer."
                                -1002 -> "Printer is busy."
                                else -> "Print failed with code: $resultCode"
                            }
                            onComplete(false, errorDescription)
                        }
                    }
                    null
                }

                pClass.getMethod("startPrint", Boolean::class.javaPrimitiveType, onPrintListenerClass)
                    .invoke(p, true, listenerProxy)
            } else {
                pClass.getMethod("startPrint", Boolean::class.javaPrimitiveType, onPrintListenerClass)
                    .invoke(p, false, null)
                onComplete(true, null)
            }

        } catch (e: Throwable) {
            Log.e(TAG, "Error during printReceipt: ${e.message}", e)
            onComplete(false, e.message ?: "Unknown printer error")
        }
    }

    fun printCashMovement(
        movementData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        if (!isPrinterReady()) {
            onComplete(false, "NEXGO thermal printer not initialized or device engine unavailable")
            return
        }

        try {
            val p = printer ?: return onComplete(false, "Printer instance null")
            val pClass = p.javaClass

            // 1. Reset / Init Printer
            pClass.getMethod("initPrinter").invoke(p)
            try {
                pClass.getMethod("setLetterSpacing", Int::class.javaPrimitiveType).invoke(p, 0)
            } catch (_: Exception) {}

            val alignLeft = getAlignEnum("LEFT")
            val alignCenter = getAlignEnum("CENTER")
            val alignRight = getAlignEnum("RIGHT")

            val appendTextMethod = pClass.getMethod(
                "appendPrnStr",
                String::class.java,
                Int::class.javaPrimitiveType,
                alignEnumClass,
                Boolean::class.javaPrimitiveType
            )

            val appendTwoColsMethod = try {
                pClass.getMethod(
                    "appendPrnStr",
                    String::class.java,
                    String::class.java,
                    Int::class.javaPrimitiveType,
                    Boolean::class.javaPrimitiveType
                )
            } catch (_: Exception) {
                null
            }

            fun printLine(text: String, size: Int = 22, align: Any? = alignLeft, bold: Boolean = false) {
                if (text == "--------------------------------" || text == "-".repeat(32)) {
                    this@NexgoPrinterManager.printDivider(p, pClass, false, alignCenter) { t: String, s: Int, a: Any?, b: Boolean ->
                        appendTextMethod.invoke(p, t, s, a ?: alignLeft, b)
                    }
                    return
                } else if (text == "================================" || text == "=".repeat(32)) {
                    this@NexgoPrinterManager.printDivider(p, pClass, true, alignCenter) { t: String, s: Int, a: Any?, b: Boolean ->
                        appendTextMethod.invoke(p, t, s, a ?: alignLeft, b)
                    }
                    return
                }
                appendTextMethod.invoke(p, text, size, align ?: alignLeft, bold)
            }

            fun printTwoCols(left: String, right: String, size: Int = 22, bold: Boolean = false) {
                if (appendTwoColsMethod != null) {
                    appendTwoColsMethod.invoke(p, left, right, size, bold)
                } else {
                    val totalWidth = 32
                    val pad = (totalWidth - left.length - right.length).coerceAtLeast(1)
                    val line = left + " ".repeat(pad) + right
                    printLine(line, size, alignLeft, bold)
                }
            }

            val appName = (movementData["appName"] as? String ?: "ONIMTA POS").uppercase()
            val type = (movementData["type"] as? String ?: "PAID IN").uppercase()
            val amount = movementData["amount"] as? String ?: "LKR 0.00"
            val reason = (movementData["reason"] as? String ?: "Cash Movement").uppercase()
            val cashier = (movementData["cashier"] as? String ?: "Admin").uppercase()
            val dateStr = movementData["dateTime"] as? String ?: ""

            printReceiptHeader(movementData, "*** $type RECEIPT ***", ::printLine, alignCenter)

            if (dateStr.isNotEmpty()) {
                printTwoCols("DATE:", dateStr, 20, false)
            }
            printTwoCols("CASHIER:", cashier, 20, false)
            printTwoCols("TYPE:", type, 22, true)
            printLine("REASON / REMARK:", 20, alignLeft, false)
            printLine("  $reason", 22, alignLeft, true)
            printLine("--------------------------------", 20, alignCenter, false)

            printTwoCols("TOTAL $type:", amount, 26, true)
            printLine("--------------------------------", 20, alignCenter, false)
            printLine("", 16, alignLeft, false)
            printLine("CASHIER SIGNATURE: _____________", 20, alignLeft, false)
            printLine("", 16, alignLeft, false)
            printLine("APPROVED BY:       _____________", 20, alignLeft, false)
            printLine("--------------------------------", 20, alignCenter, false)

            // Feed paper so paper clears the cutter
            try {
                pClass.getMethod("feedPaper", Int::class.javaPrimitiveType).invoke(p, 4)
            } catch (_: Exception) {}

            // Start Print via Listener Proxy
            if (onPrintListenerClass != null) {
                val listenerProxy = Proxy.newProxyInstance(
                    onPrintListenerClass!!.classLoader,
                    arrayOf(onPrintListenerClass)
                ) { _, method, args ->
                    if (method.name == "onPrintResult") {
                        val resultCode = args?.getOrNull(0) as? Int ?: 0
                        Log.d(TAG, "onPrintResult: $resultCode")
                        if (resultCode == 0) {
                            onComplete(true, null)
                        } else {
                            onComplete(false, "Print failed with code: $resultCode")
                        }
                    }
                    null
                }

                pClass.getMethod("startPrint", Boolean::class.javaPrimitiveType, onPrintListenerClass)
                    .invoke(p, true, listenerProxy)
            } else {
                pClass.getMethod("startPrint", Boolean::class.javaPrimitiveType, onPrintListenerClass)
                    .invoke(p, false, null)
                onComplete(true, null)
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Error during printCashMovement: ${e.message}", e)
            onComplete(false, e.message ?: "Unknown printer error")
        }
    }

    fun printShiftReport(
        reportData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        if (!isPrinterReady()) {
            onComplete(false, "NEXGO thermal printer not initialized or device engine unavailable")
            return
        }

        try {
            val p = printer ?: return onComplete(false, "Printer instance null")
            val pClass = p.javaClass

            // 1. Reset / Init Printer
            pClass.getMethod("initPrinter").invoke(p)
            try {
                pClass.getMethod("setLetterSpacing", Int::class.javaPrimitiveType).invoke(p, 0)
            } catch (_: Exception) {}

            val alignLeft = getAlignEnum("LEFT")
            val alignCenter = getAlignEnum("CENTER")

            val appendTextMethod = pClass.getMethod(
                "appendPrnStr",
                String::class.java,
                Int::class.javaPrimitiveType,
                alignEnumClass,
                Boolean::class.javaPrimitiveType
            )

            val appendTwoColsMethod = try {
                pClass.getMethod(
                    "appendPrnStr",
                    String::class.java,
                    String::class.java,
                    Int::class.javaPrimitiveType,
                    Boolean::class.javaPrimitiveType
                )
            } catch (_: Exception) {
                null
            }

            fun printLine(text: String, size: Int = 22, align: Any? = alignLeft, bold: Boolean = false) {
                if (text == "--------------------------------" || text == "-".repeat(32)) {
                    this@NexgoPrinterManager.printDivider(p, pClass, false, alignCenter) { t: String, s: Int, a: Any?, b: Boolean ->
                        appendTextMethod.invoke(p, t, s, a ?: alignLeft, b)
                    }
                    return
                } else if (text == "================================" || text == "=".repeat(32)) {
                    this@NexgoPrinterManager.printDivider(p, pClass, true, alignCenter) { t: String, s: Int, a: Any?, b: Boolean ->
                        appendTextMethod.invoke(p, t, s, a ?: alignLeft, b)
                    }
                    return
                }
                appendTextMethod.invoke(p, text, size, align ?: alignLeft, bold)
            }

            fun printTwoCols(left: String, right: String, size: Int = 22, bold: Boolean = false) {
                if (appendTwoColsMethod != null) {
                    appendTwoColsMethod.invoke(p, left, right, size, bold)
                } else {
                    val totalWidth = 32
                    val pad = (totalWidth - left.length - right.length).coerceAtLeast(1)
                    val line = left + " ".repeat(pad) + right
                    printLine(line, size, alignLeft, bold)
                }
            }

            val appName = (reportData["appName"] as? String ?: "ONIMTA POS").uppercase()
            val title = (reportData["title"] as? String ?: "SHIFT REPORT").uppercase()
            val dayNumber = reportData["dayNumber"] as? String ?: "1"
            val shiftNumber = reportData["shiftNumber"] as? String ?: "1"
            val cashier = (reportData["cashier"] as? String ?: "Admin").uppercase()
            val dateTime = reportData["dateTime"] as? String ?: ""
            val openedAt = reportData["openedAt"] as? String ?: ""
            val isEndReport = reportData["isEndReport"] as? Boolean ?: false

            printReceiptHeader(reportData, title, ::printLine, alignCenter)

            printTwoCols("DAY #:", dayNumber, 20, true)
            printTwoCols("SHIFT #:", shiftNumber, 20, true)
            printTwoCols("CASHIER:", cashier, 20, true)
            if (dateTime.isNotEmpty()) {
                printTwoCols("DATE / TIME:", dateTime, 20, true)
            }
            if (openedAt.isNotEmpty()) {
                printTwoCols("OPENED AT:", openedAt, 20, true)
            }
            printLine("--------------------------------", 20, alignCenter, false)

            if (!isEndReport) {
                // START SHIFT / DAY REPORT
                val openingBalance = reportData["openingBalance"] as? String ?: "LKR 0.00"
                printTwoCols("OPENING FLOAT:", openingBalance, 24, true)
            } else {
                // END SHIFT / DAY REPORT
                val totalInvoices = reportData["totalInvoices"] as? String ?: "0"
                val grossSales = reportData["grossSales"] as? String ?: "LKR 0.00"
                val discount = reportData["discount"] as? String ?: "LKR 0.00"
                val tax = reportData["tax"] as? String ?: "LKR 0.00"
                val netSales = reportData["netSales"] as? String ?: "LKR 0.00"

                val cashSales = reportData["cashSales"] as? String ?: "LKR 0.00"
                val nonCashSales = reportData["nonCashSales"] as? String ?: "LKR 0.00"
                val nonCashBreakdown = (reportData["nonCashBreakdown"] as? Map<*, *>)?.mapNotNull { (k, v) ->
                    if (k != null && v != null) k.toString().uppercase() to v.toString() else null
                }?.toMap() ?: emptyMap()
                val cardSales = reportData["cardSales"] as? String ?: "LKR 0.00"
                val otherSales = reportData["otherSales"] as? String ?: "LKR 0.00"

                val openingBalance = reportData["openingBalance"] as? String ?: "LKR 0.00"
                val paidIn = reportData["paidIn"] as? String ?: "LKR 0.00"
                val paidOut = reportData["paidOut"] as? String ?: "LKR 0.00"
                val expectedCash = reportData["expectedCash"] as? String ?: "LKR 0.00"
                val actualCash = reportData["actualCash"] as? String ?: "LKR 0.00"
                val cashDiff = reportData["cashDiff"] as? String ?: "LKR 0.00"

                printLine("SALES SUMMARY", 20, alignLeft, true)
                printTwoCols("TOTAL INVOICES:", totalInvoices, 20, true)
                printTwoCols("GROSS SALES:", grossSales, 20, true)
                if (discount.isNotEmpty() && discount != "LKR 0.00") {
                    printTwoCols("DISCOUNTS:", "-$discount", 20, true)
                }
                if (tax.isNotEmpty() && tax != "LKR 0.00") {
                    printTwoCols("TAX:", tax, 20, true)
                }
                printTwoCols("NET SALES:", netSales, 22, true)
                printLine("--------------------------------", 20, alignCenter, false)

                printLine("PAYMENTS BREAKDOWN", 20, alignLeft, true)
                printTwoCols("CASH SALES:", cashSales, 20, true)
                printTwoCols("NON-CASH SALES:", nonCashSales, 20, true)
                if (nonCashBreakdown.isNotEmpty()) {
                    for ((method, amount) in nonCashBreakdown) {
                        printTwoCols("  • ${method.uppercase()}:", amount, 18, true)
                    }
                } else if (cardSales.isNotEmpty() && cardSales != "LKR 0.00") {
                    printTwoCols("  • CARD SALES:", cardSales, 18, true)
                }
                printLine("--------------------------------", 20, alignCenter, false)

                printLine("DRAWER RECONCILIATION", 20, alignLeft, true)
                printTwoCols("OPENING BALANCE:", openingBalance, 20, true)
                printTwoCols("+ CASH SALES:", cashSales, 20, true)
                if (paidIn != "LKR 0.00" && paidIn.isNotEmpty()) {
                    printTwoCols("+ PAID IN (ENTRY):", paidIn, 20, true)
                }
                if (paidOut != "LKR 0.00" && paidOut.isNotEmpty()) {
                    printTwoCols("- PAID OUT (EXPENSE):", "-$paidOut", 20, true)
                }
                printLine("--------------------------------", 20, alignCenter, false)
                printTwoCols("EXPECTED CASH:", expectedCash, 22, true)
                printTwoCols("ACTUAL CASH IN HAND:", actualCash, 22, true)
                printTwoCols("OVER / SHORT:", cashDiff, 24, true)
            }

            printLine("--------------------------------", 20, alignCenter, false)
            printLine("", 16, alignLeft, false)
            printLine("CASHIER SIGNATURE: _____________", 20, alignLeft, true)
            printLine("", 16, alignLeft, false)
            printLine("MANAGER SIGNATURE: _____________", 20, alignLeft, true)
            printLine("--------------------------------", 20, alignCenter, false)

            // Feed paper
            try {
                pClass.getMethod("feedPaper", Int::class.javaPrimitiveType).invoke(p, 4)
            } catch (_: Exception) {}

            // Start Print via Listener Proxy
            if (onPrintListenerClass != null) {
                val listenerProxy = Proxy.newProxyInstance(
                    onPrintListenerClass!!.classLoader,
                    arrayOf(onPrintListenerClass)
                ) { _, method, args ->
                    if (method.name == "onPrintResult") {
                        val resultCode = args?.getOrNull(0) as? Int ?: 0
                        Log.d(TAG, "onPrintResult: $resultCode")
                        if (resultCode == 0) {
                            onComplete(true, null)
                        } else {
                            val errorDescription = when (resultCode) {
                                -1005 -> "Printer out of paper. Please insert paper roll."
                                -1006 -> "Printer cover is open. Please close cover."
                                -1003 -> "Printer is overheating. Please wait."
                                -1004 -> "Battery low for printer."
                                -1002 -> "Printer is busy."
                                else -> "Print failed with code: $resultCode"
                            }
                            onComplete(false, errorDescription)
                        }
                    }
                    null
                }

                pClass.getMethod("startPrint", Boolean::class.javaPrimitiveType, onPrintListenerClass)
                    .invoke(p, true, listenerProxy)
            } else {
                pClass.getMethod("startPrint", Boolean::class.javaPrimitiveType, onPrintListenerClass)
                    .invoke(p, false, null)
                onComplete(true, null)
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Error during printShiftReport: ${e.message}", e)
            onComplete(false, e.message ?: "Unknown printer error")
        }
    }

    fun printExchangeReceipt(
        exchangeData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        if (!isPrinterReady()) {
            onComplete(false, "NEXGO thermal printer not initialized")
            return
        }

        try {
            val p = printer ?: return onComplete(false, "Printer instance null")
            val pClass = p.javaClass

            pClass.getMethod("initPrinter").invoke(p)
            try {
                pClass.getMethod("setLetterSpacing", Int::class.javaPrimitiveType).invoke(p, 0)
            } catch (_: Exception) {}

            val alignLeft = getAlignEnum("LEFT")
            val alignCenter = getAlignEnum("CENTER")
            val alignRight = getAlignEnum("RIGHT")

            val appendTextMethod = pClass.getMethod(
                "appendPrnStr",
                String::class.java,
                Int::class.javaPrimitiveType,
                alignEnumClass,
                Boolean::class.javaPrimitiveType
            )

            val appendTwoColsMethod = try {
                pClass.getMethod(
                    "appendPrnStr",
                    String::class.java,
                    String::class.java,
                    Int::class.javaPrimitiveType,
                    Boolean::class.javaPrimitiveType
                )
            } catch (_: Exception) {
                null
            }

            fun printLine(text: String, size: Int = 22, align: Any? = alignLeft, bold: Boolean = false) {
                if (text == "--------------------------------" || text == "-".repeat(32)) {
                    this@NexgoPrinterManager.printDivider(p, pClass, false, alignCenter) { t: String, s: Int, a: Any?, b: Boolean ->
                        appendTextMethod.invoke(p, t, s, a ?: alignLeft, b)
                    }
                    return
                } else if (text == "================================" || text == "=".repeat(32)) {
                    this@NexgoPrinterManager.printDivider(p, pClass, true, alignCenter) { t: String, s: Int, a: Any?, b: Boolean ->
                        appendTextMethod.invoke(p, t, s, a ?: alignLeft, b)
                    }
                    return
                }
                appendTextMethod.invoke(p, text, size, align ?: alignLeft, bold)
            }

            fun printTwoCols(left: String, right: String, size: Int = 22, bold: Boolean = false) {
                if (appendTwoColsMethod != null) {
                    appendTwoColsMethod.invoke(p, left, right, size, bold)
                } else {
                    val totalWidth = 32
                    val pad = (totalWidth - left.length - right.length).coerceAtLeast(1)
                    val line = left + " ".repeat(pad) + right
                    printLine(line, size, alignLeft, bold)
                }
            }

            val appName = (exchangeData["appName"] as? String ?: "ONIMTA POS").uppercase()
            val voucherCode = exchangeData["voucherCode"] as? String ?: ""
            val totalAmount = exchangeData["totalAmount"] as? String ?: "LKR 0.00"
            val customerName = (exchangeData["customerName"] as? String ?: "Walk-in Customer").uppercase()
            val cashierName = (exchangeData["cashierName"] as? String ?: "Admin").uppercase()
            val dateTime = exchangeData["dateTime"] as? String ?: ""
            val items = exchangeData["items"] as? List<Map<String, Any?>> ?: emptyList()

            printReceiptHeader(exchangeData, "EXCHANGE VOUCHER / SLIP", ::printLine, alignCenter)

            printTwoCols("VOUCHER #:", voucherCode, 24, true)
            printTwoCols("DATE:", dateTime, 20, false)
            printTwoCols("CASHIER:", cashierName, 20, false)
            if (customerName.isNotEmpty() && customerName != "WALK-IN CUSTOMER") {
                printTwoCols("CUSTOMER:", customerName, 20, false)
            }
            printLine("--------------------------------", 20, alignCenter, false)

            printTwoCols("LN  PRODUCT", "PRICE QTY TOTAL", 20, true)
            printLine("--------------------------------", 20, alignCenter, false)

            var ln = 1
            for (item in items) {
                val desc = (item["description"] as? String ?: "").uppercase()
                val qty = item["qty"] as? String ?: "1"
                val price = item["price"] as? String ?: ""
                val total = item["total"] as? String ?: ""
                printLine(String.format("%2d. %s", ln, desc), 21, alignLeft, true)
                val priceQtyTotal = String.format("%9s %4s %9s", price, qty, total)
                val pad = (32 - priceQtyTotal.length).coerceAtLeast(0)
                printLine(" ".repeat(pad) + priceQtyTotal, 20, alignLeft, false)
                ln++
            }

            printLine("--------------------------------", 20, alignCenter, false)
            printTwoCols("TOTAL CREDIT VALUE:", totalAmount, 26, true)
            printLine("--------------------------------", 20, alignCenter, false)

            // 1. Razor-sharp 1D Code-128 Barcode Image
            val barcodeBmp = BarcodeBitmapHelper.createCrispCode128(voucherCode, 384, 110)
            if (barcodeBmp != null) {
                try {
                    val appendImageMethod = pClass.methods.firstOrNull { it.name == "appendImage" }
                    if (appendImageMethod != null) {
                        val pTypes = appendImageMethod.parameterTypes
                        if (pTypes.size == 1 && pTypes[0] == Bitmap::class.java) {
                            appendImageMethod.invoke(p, barcodeBmp)
                        } else if (pTypes.size >= 2 && pTypes[0] == Bitmap::class.java) {
                            appendImageMethod.invoke(p, barcodeBmp, alignCenter)
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "appendImage barcode error: ${e.message}")
                }
            }

            printLine("* $voucherCode *", 22, alignCenter, true)

            // 2. High-contrast QR Code for fast 2D / Camera Scanning
            val qrBmp = BarcodeBitmapHelper.createCrispQrCode(voucherCode, 180)
            if (qrBmp != null) {
                try {
                    val appendImageMethod = pClass.methods.firstOrNull { it.name == "appendImage" }
                    if (appendImageMethod != null) {
                        val pTypes = appendImageMethod.parameterTypes
                        if (pTypes.size == 1 && pTypes[0] == Bitmap::class.java) {
                            appendImageMethod.invoke(p, qrBmp)
                        } else if (pTypes.size >= 2 && pTypes[0] == Bitmap::class.java) {
                            appendImageMethod.invoke(p, qrBmp, alignCenter)
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "appendImage QR error: ${e.message}")
                }
            }

            printLine("--------------------------------", 20, alignCenter, false)
            printLine("Scan barcode or QR code to redeem", 18, alignCenter, false)
            printLine("exchange credit on your next bill.", 18, alignCenter, false)
            printLine("--------------------------------", 20, alignCenter, false)

            try {
                pClass.getMethod("feedPaper", Int::class.javaPrimitiveType).invoke(p, 4)
            } catch (_: Exception) {}

            if (onPrintListenerClass != null) {
                val listenerProxy = Proxy.newProxyInstance(
                    onPrintListenerClass!!.classLoader,
                    arrayOf(onPrintListenerClass)
                ) { _, method, args ->
                    if (method.name == "onPrintResult") {
                        val resultCode = args?.getOrNull(0) as? Int ?: 0
                        if (resultCode == 0) onComplete(true, null)
                        else onComplete(false, "Print failed: $resultCode")
                    }
                    null
                }
                pClass.getMethod("startPrint", Boolean::class.javaPrimitiveType, onPrintListenerClass)
                    .invoke(p, true, listenerProxy)
            } else {
                pClass.getMethod("startPrint", Boolean::class.javaPrimitiveType, onPrintListenerClass)
                    .invoke(p, false, null)
                onComplete(true, null)
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Error printing exchange receipt: ${e.message}", e)
            onComplete(false, e.message ?: "Unknown printer error")
        }
    }

    fun printReturnReceipt(
        returnData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        if (!isPrinterReady()) {
            onComplete(false, "NEXGO thermal printer not initialized")
            return
        }

        try {
            val p = printer ?: return onComplete(false, "Printer instance null")
            val pClass = p.javaClass

            pClass.getMethod("initPrinter").invoke(p)
            try {
                pClass.getMethod("setLetterSpacing", Int::class.javaPrimitiveType).invoke(p, 0)
            } catch (_: Exception) {}

            val alignLeft = getAlignEnum("LEFT")
            val alignCenter = getAlignEnum("CENTER")
            val alignRight = getAlignEnum("RIGHT")

            val appendTextMethod = pClass.getMethod(
                "appendPrnStr",
                String::class.java,
                Int::class.javaPrimitiveType,
                alignEnumClass,
                Boolean::class.javaPrimitiveType
            )

            val appendTwoColsMethod = try {
                pClass.getMethod(
                    "appendPrnStr",
                    String::class.java,
                    String::class.java,
                    Int::class.javaPrimitiveType,
                    Boolean::class.javaPrimitiveType
                )
            } catch (_: Exception) {
                null
            }

            fun printLine(text: String, size: Int = 22, align: Any? = alignLeft, bold: Boolean = false) {
                if (text == "--------------------------------" || text == "-".repeat(32)) {
                    this@NexgoPrinterManager.printDivider(p, pClass, false, alignCenter) { t: String, s: Int, a: Any?, b: Boolean ->
                        appendTextMethod.invoke(p, t, s, a ?: alignLeft, b)
                    }
                    return
                } else if (text == "================================" || text == "=".repeat(32)) {
                    this@NexgoPrinterManager.printDivider(p, pClass, true, alignCenter) { t: String, s: Int, a: Any?, b: Boolean ->
                        appendTextMethod.invoke(p, t, s, a ?: alignLeft, b)
                    }
                    return
                }
                appendTextMethod.invoke(p, text, size, align ?: alignLeft, bold)
            }

            fun printTwoCols(left: String, right: String, size: Int = 22, bold: Boolean = false) {
                if (appendTwoColsMethod != null) {
                    appendTwoColsMethod.invoke(p, left, right, size, bold)
                } else {
                    val totalWidth = 32
                    val pad = (totalWidth - left.length - right.length).coerceAtLeast(1)
                    val line = left + " ".repeat(pad) + right
                    printLine(line, size, alignLeft, bold)
                }
            }

            val appName = (returnData["appName"] as? String ?: "ONIMTA POS").uppercase()
            val returnNo = returnData["returnNo"] as? String ?: ""
            val refundAmount = returnData["refundAmount"] as? String ?: "LKR 0.00"
            val paymentMethod = (returnData["paymentMethod"] as? String ?: "CASH").uppercase()
            val reason = (returnData["reason"] as? String ?: "CUSTOMER RETURN").uppercase()
            val customerName = (returnData["customerName"] as? String ?: "Walk-in Customer").uppercase()
            val cashierName = (returnData["cashierName"] as? String ?: "Admin").uppercase()
            val dateTime = returnData["dateTime"] as? String ?: ""
            val items = returnData["items"] as? List<Map<String, Any?>> ?: emptyList()

            printReceiptHeader(returnData, "RETURN / REFUND RECEIPT", ::printLine, alignCenter)

            printTwoCols("RETURN REF #:", returnNo, 22, true)
            printTwoCols("DATE:", dateTime, 20, false)
            printTwoCols("CASHIER:", cashierName, 20, false)
            if (customerName.isNotEmpty() && customerName != "WALK-IN CUSTOMER") {
                printTwoCols("CUSTOMER:", customerName, 20, false)
            }
            printTwoCols("REASON:", reason, 20, false)
            printLine("--------------------------------", 20, alignCenter, false)

            printTwoCols("LN  PRODUCT", "PRICE QTY TOTAL", 20, true)
            printLine("--------------------------------", 20, alignCenter, false)

            var ln = 1
            for (item in items) {
                val desc = (item["description"] as? String ?: "").uppercase()
                val qty = item["qty"] as? String ?: "1"
                val price = item["price"] as? String ?: ""
                val total = item["total"] as? String ?: ""
                printLine(String.format("%2d. %s", ln, desc), 21, alignLeft, true)
                val priceQtyTotal = String.format("%9s %4s %9s", price, qty, total)
                val pad = (32 - priceQtyTotal.length).coerceAtLeast(0)
                printLine(" ".repeat(pad) + priceQtyTotal, 20, alignLeft, false)
                ln++
            }

            printLine("--------------------------------", 20, alignCenter, false)
            printTwoCols("REFUNDED VIA:", paymentMethod, 22, true)
            printTwoCols("TOTAL REFUNDED:", refundAmount, 26, true)
            printLine("--------------------------------", 20, alignCenter, false)

            printLine("", 16, alignLeft, false)
            printLine("CASHIER SIGN: _____________", 20, alignLeft, false)
            printLine("", 16, alignLeft, false)
            printLine("CUSTOMER SIGN: ____________", 20, alignLeft, false)
            printLine("--------------------------------", 20, alignCenter, false)

            try {
                pClass.getMethod("feedPaper", Int::class.javaPrimitiveType).invoke(p, 4)
            } catch (_: Exception) {}

            if (onPrintListenerClass != null) {
                val listenerProxy = Proxy.newProxyInstance(
                    onPrintListenerClass!!.classLoader,
                    arrayOf(onPrintListenerClass)
                ) { _, method, args ->
                    if (method.name == "onPrintResult") {
                        val resultCode = args?.getOrNull(0) as? Int ?: 0
                        if (resultCode == 0) onComplete(true, null)
                        else onComplete(false, "Print failed: $resultCode")
                    }
                    null
                }
                pClass.getMethod("startPrint", Boolean::class.javaPrimitiveType, onPrintListenerClass)
                    .invoke(p, true, listenerProxy)
            } else {
                pClass.getMethod("startPrint", Boolean::class.javaPrimitiveType, onPrintListenerClass)
                    .invoke(p, false, null)
                onComplete(true, null)
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Error printing return receipt: ${e.message}", e)
            onComplete(false, e.message ?: "Unknown printer error")
        }
    }

    fun printItemWiseSalesReport(
        reportData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        if (!isPrinterReady()) {
            onComplete(false, "NEXGO thermal printer not initialized")
            return
        }

        try {
            val p = printer ?: return onComplete(false, "Printer instance null")
            val pClass = p.javaClass

            pClass.getMethod("initPrinter").invoke(p)
            try {
                pClass.getMethod("setLetterSpacing", Int::class.javaPrimitiveType).invoke(p, 0)
            } catch (_: Exception) {}

            val alignLeft = getAlignEnum("LEFT")
            val alignCenter = getAlignEnum("CENTER")

            val appendTextMethod = pClass.getMethod(
                "appendPrnStr",
                String::class.java,
                Int::class.javaPrimitiveType,
                alignEnumClass,
                Boolean::class.javaPrimitiveType
            )

            val appendTwoColsMethod = try {
                pClass.getMethod(
                    "appendPrnStr",
                    String::class.java,
                    String::class.java,
                    Int::class.javaPrimitiveType,
                    Boolean::class.javaPrimitiveType
                )
            } catch (_: Exception) {
                null
            }

            fun printLine(text: String, size: Int = 22, align: Any? = alignLeft, bold: Boolean = false) {
                if (text == "--------------------------------" || text == "-".repeat(32)) {
                    this@NexgoPrinterManager.printDivider(p, pClass, false, alignCenter) { t: String, s: Int, a: Any?, b: Boolean ->
                        appendTextMethod.invoke(p, t, s, a ?: alignLeft, b)
                    }
                    return
                } else if (text == "================================" || text == "=".repeat(32)) {
                    this@NexgoPrinterManager.printDivider(p, pClass, true, alignCenter) { t: String, s: Int, a: Any?, b: Boolean ->
                        appendTextMethod.invoke(p, t, s, a ?: alignLeft, b)
                    }
                    return
                }
                appendTextMethod.invoke(p, text, size, align ?: alignLeft, bold)
            }

            fun printTwoCols(left: String, right: String, size: Int = 22, bold: Boolean = false) {
                if (appendTwoColsMethod != null) {
                    appendTwoColsMethod.invoke(p, left, right, size, bold)
                } else {
                    val totalWidth = 32
                    val pad = (totalWidth - left.length - right.length).coerceAtLeast(1)
                    val line = left + " ".repeat(pad) + right
                    printLine(line, size, alignLeft, bold)
                }
            }

            val appName = (reportData["appName"] as? String ?: "ONIMTA POS").uppercase()
            val title = (reportData["title"] as? String ?: "ITEM WISE SALES").uppercase()
            val period = (reportData["period"] as? String ?: "TODAY").uppercase()
            val cashier = (reportData["cashierName"] as? String ?: "Admin").uppercase()
            val dateTime = reportData["dateTime"] as? String ?: ""
            val totalQty = reportData["totalQuantity"] as? String ?: "0"
            val totalRevenue = reportData["totalRevenue"] as? String ?: "LKR 0.00"
            val items = reportData["items"] as? List<Map<String, Any?>> ?: emptyList()

            printReceiptHeader(reportData, title, ::printLine, alignCenter)

            printTwoCols("PERIOD:", period, 20, false)
            printTwoCols("CASHIER:", cashier, 20, false)
            if (dateTime.isNotEmpty()) {
                printTwoCols("DATE:", dateTime, 20, false)
            }
            printLine("--------------------------------", 20, alignCenter, false)

            printLine("ITEM DESCRIPTION", 20, alignLeft, true)
            printTwoCols("  SOLD QTY", "TOTAL AMOUNT", 20, true)
            printLine("--------------------------------", 20, alignCenter, false)

            var rank = 1
            for (item in items) {
                val desc = (item["description"] as? String ?: "").uppercase()
                val qty = item["qty"] as? String ?: "0"
                val total = item["total"] as? String ?: "LKR 0.00"
                printLine("$rank. $desc", 22, alignLeft, true)
                printTwoCols("   QTY: $qty", total, 20, false)
                rank++
            }

            printLine("--------------------------------", 20, alignCenter, false)
            printTwoCols("TOTAL ITEMS SOLD:", totalQty, 22, true)
            printTwoCols("TOTAL REVENUE:", totalRevenue, 26, true)
            printLine("--------------------------------", 20, alignCenter, false)

            try {
                pClass.getMethod("feedPaper", Int::class.javaPrimitiveType).invoke(p, 4)
            } catch (_: Exception) {}

            if (onPrintListenerClass != null) {
                val listenerProxy = Proxy.newProxyInstance(
                    onPrintListenerClass!!.classLoader,
                    arrayOf(onPrintListenerClass)
                ) { _, method, args ->
                    if (method.name == "onPrintResult") {
                        val resultCode = args?.getOrNull(0) as? Int ?: 0
                        if (resultCode == 0) onComplete(true, null)
                        else onComplete(false, "Print failed: $resultCode")
                    }
                    null
                }
                pClass.getMethod("startPrint", Boolean::class.javaPrimitiveType, onPrintListenerClass)
                    .invoke(p, true, listenerProxy)
            } else {
                pClass.getMethod("startPrint", Boolean::class.javaPrimitiveType, onPrintListenerClass)
                    .invoke(p, false, null)
                onComplete(true, null)
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Error printing item wise sales report: ${e.message}", e)
            onComplete(false, e.message ?: "Unknown printer error")
        }
    }

    fun printTotalSalesReport(
        reportData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        if (!isPrinterReady()) {
            onComplete(false, "NEXGO thermal printer not initialized")
            return
        }

        try {
            val p = printer ?: return onComplete(false, "Printer instance null")
            val pClass = p.javaClass

            pClass.getMethod("initPrinter").invoke(p)
            try {
                pClass.getMethod("setLetterSpacing", Int::class.javaPrimitiveType).invoke(p, 0)
            } catch (_: Exception) {}

            val alignLeft = getAlignEnum("LEFT")
            val alignCenter = getAlignEnum("CENTER")

            val appendTextMethod = pClass.getMethod(
                "appendPrnStr",
                String::class.java,
                Int::class.javaPrimitiveType,
                alignEnumClass,
                Boolean::class.javaPrimitiveType
            )

            val appendTwoColsMethod = try {
                pClass.getMethod(
                    "appendPrnStr",
                    String::class.java,
                    String::class.java,
                    Int::class.javaPrimitiveType,
                    Boolean::class.javaPrimitiveType
                )
            } catch (_: Exception) {
                null
            }

            fun printLine(text: String, size: Int = 22, align: Any? = alignLeft, bold: Boolean = false) {
                if (text == "--------------------------------" || text == "-".repeat(32)) {
                    this@NexgoPrinterManager.printDivider(p, pClass, false, alignCenter) { t: String, s: Int, a: Any?, b: Boolean ->
                        appendTextMethod.invoke(p, t, s, a ?: alignLeft, b)
                    }
                    return
                } else if (text == "================================" || text == "=".repeat(32)) {
                    this@NexgoPrinterManager.printDivider(p, pClass, true, alignCenter) { t: String, s: Int, a: Any?, b: Boolean ->
                        appendTextMethod.invoke(p, t, s, a ?: alignLeft, b)
                    }
                    return
                }
                appendTextMethod.invoke(p, text, size, align ?: alignLeft, bold)
            }

            fun printTwoCols(left: String, right: String, size: Int = 22, bold: Boolean = false) {
                if (appendTwoColsMethod != null) {
                    appendTwoColsMethod.invoke(p, left, right, size, bold)
                } else {
                    val totalWidth = 32
                    val pad = (totalWidth - left.length - right.length).coerceAtLeast(1)
                    val line = left + " ".repeat(pad) + right
                    printLine(line, size, alignLeft, bold)
                }
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

            printReceiptHeader(reportData, title, ::printLine, alignCenter)

            printTwoCols("PERIOD:", period, 20, false)
            printTwoCols("CASHIER:", cashier, 20, false)
            if (dateTime.isNotEmpty()) {
                printTwoCols("DATE:", dateTime, 20, false)
            }
            printLine("--------------------------------", 20, alignCenter, false)

            printLine("SALES SUMMARY", 20, alignLeft, true)
            printTwoCols("TOTAL INVOICES:", totalInvoices, 20, false)
            printTwoCols("GROSS SALES:", grossSales, 20, false)
            if (discount.isNotEmpty() && discount != "LKR 0.00") {
                printTwoCols("DISCOUNTS:", "-$discount", 20, false)
            }
            if (tax.isNotEmpty() && tax != "LKR 0.00") {
                printTwoCols("TAX:", tax, 20, false)
            }
            printTwoCols("NET SALES:", netSales, 22, true)
            if (returnsCount != "0") {
                printTwoCols("RETURNS ($returnsCount BILLS):", "-$returnsAmount", 20, false)
            }
            printLine("--------------------------------", 20, alignCenter, false)
            printTwoCols("TOTAL NET REVENUE:", totalNetRevenue, 26, true)
            printLine("--------------------------------", 20, alignCenter, false)

            printLine("PAYMENTS / TENDER BREAKDOWN", 20, alignLeft, true)
            printTwoCols("CASH SALES:", cashSales, 20, true)
            printTwoCols("NON-CASH SALES:", nonCashSales, 20, true)
            if (nonCashBreakdown.isNotEmpty()) {
                for ((method, amount) in nonCashBreakdown) {
                    printTwoCols("  • ${method.uppercase()}:", amount, 18, false)
                }
            } else {
                if (cardSales != "LKR 0.00" && cardSales.isNotEmpty()) {
                    printTwoCols("  • CARD SALES:", cardSales, 20, false)
                }
                if (qrSales != "LKR 0.00" && qrSales.isNotEmpty()) {
                    printTwoCols("  • QR / ONLINE:", qrSales, 20, false)
                }
                if (creditSales != "LKR 0.00" && creditSales.isNotEmpty()) {
                    printTwoCols("  • CREDIT SALES:", creditSales, 20, false)
                }
            }
            printLine("--------------------------------", 20, alignCenter, false)

            try {
                pClass.getMethod("feedPaper", Int::class.javaPrimitiveType).invoke(p, 4)
            } catch (_: Exception) {}

            if (onPrintListenerClass != null) {
                val listenerProxy = Proxy.newProxyInstance(
                    onPrintListenerClass!!.classLoader,
                    arrayOf(onPrintListenerClass)
                ) { _, method, args ->
                    if (method.name == "onPrintResult") {
                        val resultCode = args?.getOrNull(0) as? Int ?: 0
                        if (resultCode == 0) onComplete(true, null)
                        else onComplete(false, "Print failed: $resultCode")
                    }
                    null
                }
                pClass.getMethod("startPrint", Boolean::class.javaPrimitiveType, onPrintListenerClass)
                    .invoke(p, true, listenerProxy)
            } else {
                pClass.getMethod("startPrint", Boolean::class.javaPrimitiveType, onPrintListenerClass)
                    .invoke(p, false, null)
                onComplete(true, null)
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Error printing total sales report: ${e.message}", e)
            onComplete(false, e.message ?: "Unknown printer error")
        }
    }

    fun printHoldReceipt(
        holdData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        if (!isPrinterReady()) {
            onComplete(false, "NEXGO thermal printer not initialized")
            return
        }

        try {
            val p = printer ?: return onComplete(false, "Printer instance null")
            val pClass = p.javaClass

            pClass.getMethod("initPrinter").invoke(p)
            try {
                pClass.getMethod("setLetterSpacing", Int::class.javaPrimitiveType).invoke(p, 0)
            } catch (_: Exception) {}

            val alignLeft = getAlignEnum("LEFT")
            val alignCenter = getAlignEnum("CENTER")
            val alignRight = getAlignEnum("RIGHT")

            val appendTextMethod = pClass.getMethod(
                "appendPrnStr",
                String::class.java,
                Int::class.javaPrimitiveType,
                alignEnumClass,
                Boolean::class.javaPrimitiveType
            )

            val appendTwoColsMethod = try {
                pClass.getMethod(
                    "appendPrnStr",
                    String::class.java,
                    String::class.java,
                    Int::class.javaPrimitiveType,
                    Boolean::class.javaPrimitiveType
                )
            } catch (_: Exception) {
                null
            }

            fun printLine(text: String, size: Int = 22, align: Any? = alignLeft, bold: Boolean = false) {
                if (text == "--------------------------------" || text == "-".repeat(32)) {
                    this@NexgoPrinterManager.printDivider(p, pClass, false, alignCenter) { t: String, s: Int, a: Any?, b: Boolean ->
                        appendTextMethod.invoke(p, t, s, a ?: alignLeft, b)
                    }
                    return
                } else if (text == "================================" || text == "=".repeat(32)) {
                    this@NexgoPrinterManager.printDivider(p, pClass, true, alignCenter) { t: String, s: Int, a: Any?, b: Boolean ->
                        appendTextMethod.invoke(p, t, s, a ?: alignLeft, b)
                    }
                    return
                }
                appendTextMethod.invoke(p, text, size, align ?: alignLeft, bold)
            }

            fun printTwoCols(left: String, right: String, size: Int = 22, bold: Boolean = false) {
                if (appendTwoColsMethod != null) {
                    appendTwoColsMethod.invoke(p, left, right, size, bold)
                } else {
                    val totalWidth = 32
                    val pad = (totalWidth - left.length - right.length).coerceAtLeast(1)
                    val line = left + " ".repeat(pad) + right
                    printLine(line, size, alignLeft, bold)
                }
            }

            val holdNo = holdData["holdNo"] as? String ?: ""
            val totalAmount = holdData["totalAmount"] as? String ?: "LKR 0.00"
            val totalItems = (holdData["totalItems"] as? String ?: "0 items").uppercase()
            val customerName = (holdData["customerName"] as? String ?: "Walk-in Customer").uppercase()
            val cashierName = (holdData["cashierName"] as? String ?: "Admin").uppercase()
            val dateTime = holdData["dateTime"] as? String ?: ""

            printReceiptHeader(holdData, "*** HELD BILL RECEIPT ***", ::printLine, alignCenter)

            printTwoCols("HOLD BILL #:", holdNo, 24, true)
            printTwoCols("DATE:", dateTime, 20, false)
            printTwoCols("CASHIER:", cashierName, 20, false)
            if (customerName.isNotEmpty() && customerName != "WALK-IN CUSTOMER") {
                printTwoCols("CUSTOMER:", customerName, 20, false)
            }
            printLine("--------------------------------", 20, alignCenter, false)

            printTwoCols("TOTAL ITEMS:", totalItems, 22, true)
            printTwoCols("HELD AMOUNT:", totalAmount, 26, true)
            printLine("--------------------------------", 20, alignCenter, false)

            // 1. Razor-sharp 1D Code-128 Barcode Image
            val barcodeBmp = BarcodeBitmapHelper.createCrispCode128(holdNo, 384, 110)
            if (barcodeBmp != null) {
                try {
                    val appendImageMethod = pClass.methods.firstOrNull { it.name == "appendImage" }
                    if (appendImageMethod != null) {
                        val pTypes = appendImageMethod.parameterTypes
                        if (pTypes.size == 1 && pTypes[0] == Bitmap::class.java) {
                            appendImageMethod.invoke(p, barcodeBmp)
                        } else if (pTypes.size >= 2 && pTypes[0] == Bitmap::class.java) {
                            appendImageMethod.invoke(p, barcodeBmp, alignCenter)
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "appendImage barcode error: ${e.message}")
                }
            }

            printLine("* $holdNo *", 22, alignCenter, true)

            // 2. High-contrast QR Code for fast 2D / Camera Scanning
            val qrBmp = BarcodeBitmapHelper.createCrispQrCode(holdNo, 180)
            if (qrBmp != null) {
                try {
                    val appendImageMethod = pClass.methods.firstOrNull { it.name == "appendImage" }
                    if (appendImageMethod != null) {
                        val pTypes = appendImageMethod.parameterTypes
                        if (pTypes.size == 1 && pTypes[0] == Bitmap::class.java) {
                            appendImageMethod.invoke(p, qrBmp)
                        } else if (pTypes.size >= 2 && pTypes[0] == Bitmap::class.java) {
                            appendImageMethod.invoke(p, qrBmp, alignCenter)
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "appendImage QR error: ${e.message}")
                }
            }

            printLine("--------------------------------", 20, alignCenter, false)
            printLine("Scan barcode / QR code at POS to recall.", 18, alignCenter, false)
            printLine("Note: Active cart must be empty to recall.", 18, alignCenter, false)
            printLine("--------------------------------", 20, alignCenter, false)

            try {
                pClass.getMethod("feedPaper", Int::class.javaPrimitiveType).invoke(p, 4)
            } catch (_: Exception) {}

            if (onPrintListenerClass != null) {
                val listenerProxy = Proxy.newProxyInstance(
                    onPrintListenerClass!!.classLoader,
                    arrayOf(onPrintListenerClass)
                ) { _, method, args ->
                    if (method.name == "onPrintResult") {
                        val resultCode = args?.getOrNull(0) as? Int ?: 0
                        if (resultCode == 0) onComplete(true, null)
                        else onComplete(false, "Print failed: $resultCode")
                    }
                    null
                }
                pClass.getMethod("startPrint", Boolean::class.javaPrimitiveType, onPrintListenerClass)
                    .invoke(p, true, listenerProxy)
            } else {
                pClass.getMethod("startPrint", Boolean::class.javaPrimitiveType, onPrintListenerClass)
                    .invoke(p, false, null)
                onComplete(true, null)
            }
        } catch (e: Throwable) {
            Log.e(TAG, "Error printing hold receipt: ${e.message}", e)
            onComplete(false, e.message ?: "Unknown printer error")
        }
    }
}

