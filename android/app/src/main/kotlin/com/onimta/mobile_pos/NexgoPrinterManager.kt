package com.onimta.mobile_pos

import android.content.Context
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
            val appName = receiptData["appName"] as? String ?: "ONIMTA POS"
            val invoiceNo = receiptData["invoiceNo"] as? String ?: ""
            val customerName = receiptData["customerName"] as? String ?: "Walk-in Customer"
            val cashierName = receiptData["cashierName"] as? String ?: "Admin"
            val dateStr = receiptData["dateTime"] as? String ?: ""

            printLine(appName, 28, alignCenter, true)
            printLine("TAX INVOICE RECEIPT", 20, alignCenter, false)
            printLine("--------------------------------", 20, alignCenter, false)

            printTwoCols("Invoice #:", invoiceNo, 22, true)
            if (dateStr.isNotEmpty()) {
                printTwoCols("Date:", dateStr, 20, false)
            }
            printTwoCols("Cashier:", cashierName, 20, false)
            printTwoCols("Customer:", customerName, 20, false)
            printLine("--------------------------------", 20, alignCenter, false)

            // Items List
            val items = receiptData["items"] as? List<Map<String, Any?>> ?: emptyList()
            printLine("ITEM DESCRIPTION", 20, alignLeft, true)
            printLine("--------------------------------", 20, alignCenter, false)

            for (item in items) {
                val desc = item["description"] as? String ?: ""
                val qty = item["qty"] as? String ?: "1"
                val price = item["price"] as? String ?: ""
                val total = item["total"] as? String ?: ""

                printLine(desc, 22, alignLeft, true)
                printTwoCols("  $qty x $price", total, 20, false)
            }
            printLine("--------------------------------", 20, alignCenter, false)

            // Summary Totals
            val subtotal = receiptData["subtotal"] as? String ?: ""
            val discount = receiptData["discount"] as? String ?: ""
            val tax = receiptData["tax"] as? String ?: ""
            val grandTotal = receiptData["grandTotal"] as? String ?: ""

            printTwoCols("Subtotal:", subtotal, 22, false)
            if (discount.isNotEmpty() && discount != "LKR 0.00") {
                printTwoCols("Discount:", "-$discount", 22, false)
            }
            if (tax.isNotEmpty() && tax != "LKR 0.00") {
                printTwoCols("Tax:", tax, 22, false)
            }
            printLine("--------------------------------", 20, alignCenter, false)
            printTwoCols("GRAND TOTAL:", grandTotal, 26, true)
            printLine("--------------------------------", 20, alignCenter, false)

            // Payments Breakdown
            val payments = receiptData["payments"] as? List<Map<String, Any?>> ?: emptyList()
            if (payments.isNotEmpty()) {
                printLine("PAYMENTS:", 20, alignLeft, true)
                for (pay in payments) {
                    val method = pay["method"] as? String ?: "Payment"
                    val amt = pay["amount"] as? String ?: ""
                    printTwoCols(method, amt, 22, false)
                }
            }

            val totalPaid = receiptData["paidAmount"] as? String ?: ""
            val change = receiptData["changeAmount"] as? String ?: ""

            if (totalPaid.isNotEmpty()) {
                printTwoCols("Total Paid:", totalPaid, 22, true)
            }
            if (change.isNotEmpty() && change != "LKR 0.00") {
                printTwoCols("Change Returned:", change, 24, true)
            }

            printLine("--------------------------------", 20, alignCenter, false)
            printLine("THANK YOU FOR SHOPPING WITH US!", 20, alignCenter, true)
            printLine("Please come again", 18, alignCenter, false)

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

            val appName = movementData["appName"] as? String ?: "ONIMTA POS"
            val type = movementData["type"] as? String ?: "PAID IN"
            val amount = movementData["amount"] as? String ?: "LKR 0.00"
            val reason = movementData["reason"] as? String ?: "Cash Movement"
            val cashier = movementData["cashier"] as? String ?: "Admin"
            val dateStr = movementData["dateTime"] as? String ?: ""

            printLine(appName, 28, alignCenter, true)
            printLine("*** $type RECEIPT ***", 22, alignCenter, true)
            printLine("--------------------------------", 20, alignCenter, false)

            if (dateStr.isNotEmpty()) {
                printTwoCols("Date:", dateStr, 20, false)
            }
            printTwoCols("Cashier:", cashier, 20, false)
            printTwoCols("Type:", type, 22, true)
            printLine("Reason / Remark:", 20, alignLeft, false)
            printLine("  $reason", 22, alignLeft, true)
            printLine("--------------------------------", 20, alignCenter, false)

            printTwoCols("TOTAL $type:", amount, 26, true)
            printLine("--------------------------------", 20, alignCenter, false)
            printLine("", 16, alignLeft, false)
            printLine("Cashier Signature: _____________", 20, alignLeft, false)
            printLine("", 16, alignLeft, false)
            printLine("Approved By:       _____________", 20, alignLeft, false)
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
}
