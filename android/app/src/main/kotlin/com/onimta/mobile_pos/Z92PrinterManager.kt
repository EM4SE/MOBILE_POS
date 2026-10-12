package com.onimta.mobile_pos

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.text.Layout
import android.util.Log
import com.google.zxing.BarcodeFormat
import com.zcs.sdk.DriverManager
import com.zcs.sdk.Printer
import com.zcs.sdk.SdkResult
import com.zcs.sdk.print.PrnSpeedTypeEnum
import com.zcs.sdk.print.PrnStrFormat
import com.zcs.sdk.print.PrnTextFont
import com.zcs.sdk.print.PrnTextStyle

/**
 * High-performance, razor-sharp native thermal printer manager for DBL Z92 (Shenzhen ZCS Z92 / Z90 / Z91)
 * Smart Android POS terminals.
 *
 * Formatted to mirror the Nexgo N5 layout and alignments with 100% precision:
 * 1. Forced 384-dot scanline width (58mm thermal paper roll) to prevent 80mm double-print wrapping.
 * 2. Pixel-perfect 2-column & 3-column right-aligned amounts matching Nexgo N5 layout.
 * 3. Continuous print spooling so printing is fast, smooth, and vibration-free.
 * 4. ~22mm bottom paper feed clearance past the manual tear bar.
 * 5. High-contrast thermal density configuration (setPrintGray).
 */
class Z92PrinterManager(private val context: Context) {
    private val TAG = "Z92PrinterManager"

    private var driverManager: DriverManager? = null
    private var printer: Printer? = null
    private var isInitialized = false

    init {
        initSdk()
    }

    @Synchronized
    fun initSdk(): Boolean {
        if (isInitialized && printer != null) return true
        return try {
            driverManager = DriverManager.getInstance()
            printer = driverManager?.printer
            isInitialized = (printer != null)
            if (isInitialized) {
                try {
                    // Force 384-dot width (58mm thermal paper roll)
                    val field = printer?.javaClass?.getDeclaredField("d")
                    field?.isAccessible = true
                    field?.setInt(printer, 384)
                } catch (_: Throwable) {}
                try {
                    // Maximum high-contrast thermal density (Level 5 is darkest black)
                    printer?.setPrintGray(5.toByte())
                    printer?.setPrintSpeed(PrnSpeedTypeEnum.MEDIUM_SPEED)
                } catch (_: Throwable) {}
            }
            Log.d(TAG, "DBL Z92 Printer initialized successfully: $printer")
            isInitialized
        } catch (e: Throwable) {
            Log.w(TAG, "DBL Z92 Printer init error (device might not be Z92): ${e.message}")
            isInitialized = false
            false
        }
    }

    fun isPrinterReady(): Boolean {
        if (!isInitialized || printer == null) {
            initSdk()
        }
        val p = printer ?: return false
        return try {
            val status = p.printerStatus
            Log.d(TAG, "DBL Z92 Printer status query: $status")
            status != SdkResult.SDK_PRN_STATUS_PAPEROUT && status != SdkResult.SDK_PRN_STATUS_FAULT
        } catch (e: Throwable) {
            Log.w(TAG, "DBL Z92 isPrinterReady exception: ${e.message}")
            false
        }
    }

    // =========================================================================
    // NATIVE THERMAL LINE PRINTING ENGINE (Mirrored from Nexgo N5 Layout)
    // =========================================================================

    private class NativePrinterSession(private val p: Printer, private val context: Context) {
        companion object {
            const val PAPER_WIDTH = 384 // 58mm thermal paper = 384 dots
        }

        init {
            try {
                // Force printer internal width to 384 dots (prevents 576-dot 80mm duplicate wrapping)
                val field = p.javaClass.getDeclaredField("d")
                field.isAccessible = true
                field.setInt(p, PAPER_WIDTH)
            } catch (_: Throwable) {}

            try {
                // Maximum thermal density (5) and steady print speed
                p.setPrintGray(5.toByte())
                p.setPrintSpeed(PrnSpeedTypeEnum.MEDIUM_SPEED)
            } catch (_: Throwable) {}
        }

        fun printText(
            text: String,
            size: Int = 20,
            bold: Boolean = false,
            align: Layout.Alignment = Layout.Alignment.ALIGN_NORMAL
        ) {
            if (text.isEmpty()) {
                printSpace(1)
                return
            }
            try {
                val format = PrnStrFormat().apply {
                    textSize = size
                    font = PrnTextFont.MONOSPACE
                    style = if (bold) PrnTextStyle.BOLD else PrnTextStyle.NORMAL
                    ali = align
                }
                p.setPrintAppendString(text, format, PAPER_WIDTH)
            } catch (e: Throwable) {
                Log.w("Z92Printer", "printText error: ${e.message}")
            }
        }

        fun printTwoCols(
            left: String,
            right: String,
            size: Int = 22,
            bold: Boolean = false
        ) {
            try {
                val paint = Paint().apply {
                    textSize = size.toFloat()
                    typeface = Typeface.create(Typeface.MONOSPACE, if (bold) Typeface.BOLD else Typeface.NORMAL)
                    color = Color.BLACK
                    isAntiAlias = false
                    if (bold) {
                        isFakeBoldText = true
                    }
                }
                val fm = paint.fontMetrics
                val textHeight = (fm.descent - fm.ascent).toInt()
                val baseline = -fm.ascent
                val paddingY = 2
                val leftWidth = paint.measureText(left)
                val rightWidth = paint.measureText(right)
                val leftX = 4f
                val rightX = (PAPER_WIDTH - 6).toFloat()

                if (leftWidth + rightWidth + 12f <= (PAPER_WIDTH - 8)) {
                    val h = textHeight + (paddingY * 2)
                    val bmp = Bitmap.createBitmap(PAPER_WIDTH, h, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bmp)
                    canvas.drawColor(Color.WHITE)

                    paint.textAlign = Paint.Align.LEFT
                    canvas.drawText(left, leftX, baseline + paddingY, paint)

                    paint.textAlign = Paint.Align.RIGHT
                    canvas.drawText(right, rightX, baseline + paddingY, paint)

                    p.setPrintAppendBitmap(bmp, Layout.Alignment.ALIGN_NORMAL, PAPER_WIDTH)
                } else {
                    // Two lines if combined text is too wide: left on line 1, right right-aligned on line 2
                    val h = (textHeight * 2) + (paddingY * 4)
                    val bmp = Bitmap.createBitmap(PAPER_WIDTH, h, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bmp)
                    canvas.drawColor(Color.WHITE)

                    paint.textAlign = Paint.Align.LEFT
                    canvas.drawText(left, leftX, baseline + paddingY, paint)

                    paint.textAlign = Paint.Align.RIGHT
                    canvas.drawText(right, rightX, baseline + paddingY + textHeight + (paddingY * 2), paint)

                    p.setPrintAppendBitmap(bmp, Layout.Alignment.ALIGN_NORMAL, PAPER_WIDTH)
                }
            } catch (e: Throwable) {
                Log.w("Z92Printer", "printTwoCols error: ${e.message}")
            }
        }

        fun printThreeCols(
            left: String,
            middle: String,
            right: String,
            leftWidth: Int = 16,
            middleWidth: Int = 6,
            rightWidth: Int = 10,
            size: Int = 18,
            bold: Boolean = false
        ) {
            try {
                val paint = Paint().apply {
                    textSize = size.toFloat()
                    typeface = Typeface.create(Typeface.MONOSPACE, if (bold) Typeface.BOLD else Typeface.NORMAL)
                    color = Color.BLACK
                    isAntiAlias = false
                    if (bold) {
                        isFakeBoldText = true
                    }
                }
                val fm = paint.fontMetrics
                val textHeight = (fm.descent - fm.ascent).toInt()
                val baseline = -fm.ascent
                val paddingY = 2
                val h = textHeight + (paddingY * 2)

                val bmp = Bitmap.createBitmap(PAPER_WIDTH, h, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bmp)
                canvas.drawColor(Color.WHITE)

                paint.textAlign = Paint.Align.LEFT
                canvas.drawText(left, 4f, baseline + paddingY, paint)

                paint.textAlign = Paint.Align.CENTER
                canvas.drawText(middle, 220f, baseline + paddingY, paint)

                paint.textAlign = Paint.Align.RIGHT
                canvas.drawText(right, (PAPER_WIDTH - 6).toFloat(), baseline + paddingY, paint)

                p.setPrintAppendBitmap(bmp, Layout.Alignment.ALIGN_NORMAL, PAPER_WIDTH)
            } catch (e: Throwable) {
                Log.w("Z92Printer", "printThreeCols error: ${e.message}")
            }
        }

        fun printDivider(lineChar: String = "-", totalChars: Int = 32) {
            val line = lineChar.repeat(totalChars / lineChar.length)
            printText(line, 20, false, Layout.Alignment.ALIGN_CENTER)
        }

        fun printSpace(lines: Int = 1) {
            try {
                val h = (24 * lines).coerceAtLeast(10)
                val bmp = Bitmap.createBitmap(PAPER_WIDTH, h, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bmp)
                canvas.drawColor(Color.WHITE)
                p.setPrintAppendBitmap(bmp, Layout.Alignment.ALIGN_NORMAL, PAPER_WIDTH)
            } catch (e: Throwable) {
                Log.w("Z92Printer", "printSpace error: ${e.message}")
            }
        }

        fun printBarCode(code: String, height: Int = 110, width: Int = 384) {
            try {
                val bmp = BarcodeBitmapHelper.createCrispCode128(code, width, height)
                if (bmp != null) {
                    p.setPrintAppendBitmap(bmp, Layout.Alignment.ALIGN_CENTER, PAPER_WIDTH)
                } else {
                    p.setPrintAppendBarCode(
                        context,
                        code,
                        height,
                        width,
                        true,
                        Layout.Alignment.ALIGN_CENTER,
                        BarcodeFormat.CODE_128,
                        PAPER_WIDTH
                    )
                }
            } catch (e: Throwable) {
                Log.w("Z92Printer", "printBarCode error: ${e.message}")
            }
        }

        fun printQrCode(code: String, size: Int = 180) {
            try {
                val bmp = BarcodeBitmapHelper.createCrispQrCode(code, size)
                if (bmp != null) {
                    p.setPrintAppendBitmap(bmp, Layout.Alignment.ALIGN_CENTER, PAPER_WIDTH)
                } else {
                    p.setPrintAppendQRCode(code, size, size, Layout.Alignment.ALIGN_CENTER, PAPER_WIDTH)
                }
            } catch (e: Throwable) {
                Log.w("Z92Printer", "printQrCode error: ${e.message}")
            }
        }

        /**
         * Feeds paper past the tear bar so the receipt can be torn off cleanly without cutting text,
         * and triggers the native printer spool in ONE smooth continuous feed.
         */
        fun feedAndCut(feedBlankDots: Int = 180): Boolean {
            try {
                // If caller passed a line count like 4 or 5, convert to dots
                val actualDots = if (feedBlankDots <= 10) feedBlankDots * 36 else feedBlankDots

                // 1. Add white blank trailer (~22mm) to push content past the tear cutter bar
                val blankBmp = Bitmap.createBitmap(PAPER_WIDTH, actualDots, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(blankBmp)
                canvas.drawColor(Color.WHITE)
                p.setPrintAppendBitmap(blankBmp, Layout.Alignment.ALIGN_NORMAL, PAPER_WIDTH)
                try {
                    p.setPrintGray(5.toByte())
                    p.setPrintSpeed(PrnSpeedTypeEnum.MEDIUM_SPEED)
                } catch (_: Throwable) {}

                // 2. Execute printing of the entire spool in ONE single smooth, continuous operation
                val result = p.setPrintStart(PAPER_WIDTH)
                Log.d("Z92Printer", "Native spool print completed with result code: $result")

                // 3. Fallback paper feed command if firmware supports it
                try {
                    p.setPrintLine(2)
                } catch (_: Throwable) {}

                return result == SdkResult.SDK_OK || result == 0
            } catch (e: Throwable) {
                Log.w("Z92Printer", "feedAndCut error: ${e.message}")
                return false
            }
        }
    }

    // ==========================================
    // 1. SALE RECEIPT
    // ==========================================
    fun printReceipt(
        receiptData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!isPrinterReady()) {
                    onComplete(false, "DBL Z92 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z92 printer instance is null")
                val s = NativePrinterSession(p, context)

                val appName = receiptData["appName"] as? String ?: "ONIMTA POS"
                val invoiceNo = receiptData["invoiceNo"] as? String ?: ""
                val customerName = receiptData["customerName"] as? String ?: "Walk-in Customer"
                val cashierName = receiptData["cashierName"] as? String ?: "Admin"
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

                // 1. Header (identical to Nexgo N5)
                s.printText(appName, size = 28, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("ORDER INVOICE", size = 22, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 32)

                // 2. Invoice Info
                s.printTwoCols("Invoice #:", invoiceNo, size = 22, bold = true)
                if (dateStr.isNotEmpty()) s.printTwoCols("Date:", dateStr, size = 20, bold = false)
                s.printTwoCols("Cashier:", cashierName, size = 20, bold = false)
                s.printTwoCols("Customer:", customerName, size = 20, bold = false)
                s.printDivider("-", 32)

                // 3. Items List
                s.printText("ITEM DESCRIPTION", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                s.printDivider("-", 32)

                for (item in items) {
                    val desc = item["description"] as? String ?: ""
                    val qty = item["qty"] as? String ?: "1"
                    val price = item["price"] as? String ?: ""
                    val itemDisc = item["discount"] as? String ?: ""
                    val total = item["total"] as? String ?: ""

                    s.printText(desc, size = 22, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                    s.printTwoCols("  $qty x $price", total, size = 20, bold = false)
                    if (itemDisc.isNotEmpty() && itemDisc != "LKR 0.00" && itemDisc != "0.00") {
                        s.printTwoCols("    Item Disc:", "-$itemDisc", size = 18, bold = false)
                    }
                }
                s.printDivider("-", 32)

                // 4. Financial Summary
                s.printTwoCols("Subtotal:", subtotal, size = 22, bold = false)
                if (discount.isNotEmpty() && discount != "LKR 0.00" && discount != "0.00") {
                    s.printTwoCols("Discount:", "-$discount", size = 22, bold = false)
                }
                if (exchangeCredit.isNotEmpty() && exchangeCredit != "LKR 0.00" && exchangeCredit != "0.00") {
                    s.printTwoCols("Exchange Credit:", "-$exchangeCredit", size = 22, bold = false)
                }
                if (tax.isNotEmpty() && tax != "LKR 0.00" && tax != "0.00") {
                    s.printTwoCols("Tax:", tax, size = 22, bold = false)
                }
                s.printDivider("-", 32)
                s.printTwoCols("GRAND TOTAL:", grandTotal, size = 26, bold = true)
                s.printDivider("-", 32)

                // 5. Payments Breakdown
                if (payments.isNotEmpty()) {
                    s.printText("PAYMENTS:", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                    for (pay in payments) {
                        val method = pay["method"] as? String ?: "Payment"
                        val amt = pay["amount"] as? String ?: ""
                        s.printTwoCols(method, amt, size = 22, bold = false)
                    }
                }
                if (totalPaid.isNotEmpty()) s.printTwoCols("Total Paid:", totalPaid, size = 22, bold = true)
                if (change.isNotEmpty() && change != "LKR 0.00" && change != "0.00") {
                    s.printTwoCols("Change Returned:", change, size = 22, bold = true)
                }
                s.printDivider("-", 32)

                // 6. Footer & Clear paper feed
                s.printText("THANK YOU FOR SHOPPING WITH US!", size = 20, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("Please come again", size = 18, bold = false, align = Layout.Alignment.ALIGN_CENTER)

                s.feedAndCut(5)
                Log.d(TAG, "DBL Z92 sale receipt printed cleanly")
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing receipt on DBL Z92: ${e.message}", e)
                onComplete(false, "DBL Z92 print error: ${e.message}")
            }
        }.start()
    }

    // ==========================================
    // 2. CASH MOVEMENT (PAID IN / PAID OUT)
    // ==========================================
    fun printCashMovement(
        movementData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!isPrinterReady()) {
                    onComplete(false, "DBL Z92 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z92 printer instance is null")
                val s = NativePrinterSession(p, context)

                val appName = movementData["appName"] as? String ?: "ONIMTA POS"
                val type = movementData["type"] as? String ?: "PAID IN"
                val amount = movementData["amount"] as? String ?: "LKR 0.00"
                val reason = movementData["reason"] as? String ?: "Cash Movement"
                val cashier = movementData["cashier"] as? String ?: "Admin"
                val dateStr = movementData["dateTime"] as? String ?: ""

                s.printText(appName, size = 28, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("*** $type RECEIPT ***", size = 22, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 32)

                if (dateStr.isNotEmpty()) s.printTwoCols("Date:", dateStr, size = 20, bold = false)
                s.printTwoCols("Cashier:", cashier, size = 20, bold = false)
                s.printTwoCols("Type:", type, size = 22, bold = true)
                s.printText("Reason / Remark:", size = 20, bold = false, align = Layout.Alignment.ALIGN_NORMAL)
                s.printText("  $reason", size = 22, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                s.printDivider("-", 32)

                s.printTwoCols("TOTAL $type:", amount, size = 24, bold = true)
                s.printDivider("-", 32)
                s.printSpace(1)
                s.printText("Cashier Signature: _____________", size = 20, bold = false, align = Layout.Alignment.ALIGN_NORMAL)
                s.printSpace(1)
                s.printText("Approved By:       _____________", size = 20, bold = false, align = Layout.Alignment.ALIGN_NORMAL)
                s.printDivider("-", 32)

                s.feedAndCut(5)
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing cash movement on DBL Z92: ${e.message}", e)
                onComplete(false, "DBL Z92 print error: ${e.message}")
            }
        }.start()
    }

    // ==========================================
    // 3. SHIFT REPORT (X / Z READING)
    // ==========================================
    fun printShiftReport(
        reportData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!isPrinterReady()) {
                    onComplete(false, "DBL Z92 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z92 printer instance is null")
                val s = NativePrinterSession(p, context)

                val appName = reportData["appName"] as? String ?: "ONIMTA POS"
                val title = reportData["title"] as? String ?: "SHIFT REPORT"
                val dayNumber = reportData["dayNumber"] as? String ?: "1"
                val shiftNumber = reportData["shiftNumber"] as? String ?: "1"
                val cashier = reportData["cashier"] as? String ?: "Admin"
                val dateTime = reportData["dateTime"] as? String ?: ""
                val openedAt = reportData["openedAt"] as? String ?: ""
                val isEndReport = reportData["isEndReport"] as? Boolean ?: false

                s.printText(appName, size = 28, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText(title, size = 22, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 32)

                s.printTwoCols("Day #:", dayNumber, size = 20, bold = false)
                s.printTwoCols("Shift #:", shiftNumber, size = 20, bold = false)
                s.printTwoCols("Cashier:", cashier, size = 20, bold = false)
                if (dateTime.isNotEmpty()) s.printTwoCols("Date / Time:", dateTime, size = 20, bold = false)
                if (openedAt.isNotEmpty()) s.printTwoCols("Opened At:", openedAt, size = 20, bold = false)
                s.printDivider("-", 32)

                if (!isEndReport) {
                    val openingBalance = reportData["openingBalance"] as? String ?: "LKR 0.00"
                    s.printTwoCols("OPENING FLOAT:", openingBalance, size = 22, bold = true)
                } else {
                    val totalInvoices = reportData["totalInvoices"] as? String ?: "0"
                    val grossSales = reportData["grossSales"] as? String ?: "LKR 0.00"
                    val discount = reportData["discount"] as? String ?: "LKR 0.00"
                    val tax = reportData["tax"] as? String ?: "LKR 0.00"
                    val netSales = reportData["netSales"] as? String ?: "LKR 0.00"

                    val cashSales = reportData["cashSales"] as? String ?: "LKR 0.00"
                    val cardSales = reportData["cardSales"] as? String ?: "LKR 0.00"
                    val otherSales = reportData["otherSales"] as? String ?: "LKR 0.00"

                    val openingBalance = reportData["openingBalance"] as? String ?: "LKR 0.00"
                    val paidIn = reportData["paidIn"] as? String ?: "LKR 0.00"
                    val paidOut = reportData["paidOut"] as? String ?: "LKR 0.00"
                    val expectedCash = reportData["expectedCash"] as? String ?: "LKR 0.00"
                    val actualCash = reportData["actualCash"] as? String ?: "LKR 0.00"
                    val cashDiff = reportData["cashDiff"] as? String ?: "LKR 0.00"

                    s.printText("SALES SUMMARY", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                    s.printTwoCols("Total Invoices:", totalInvoices, size = 20, bold = false)
                    s.printTwoCols("Gross Sales:", grossSales, size = 20, bold = false)
                    if (discount.isNotEmpty() && discount != "LKR 0.00") {
                        s.printTwoCols("Discounts:", "-$discount", size = 20, bold = false)
                    }
                    if (tax.isNotEmpty() && tax != "LKR 0.00") {
                        s.printTwoCols("Tax:", tax, size = 20, bold = false)
                    }
                    s.printTwoCols("NET SALES:", netSales, size = 22, bold = true)
                    s.printDivider("-", 32)

                    s.printText("PAYMENTS BREAKDOWN", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                    s.printTwoCols("Cash Sales:", cashSales, size = 20, bold = false)
                    s.printTwoCols("Card Sales:", cardSales, size = 20, bold = false)
                    if (otherSales != "LKR 0.00" && otherSales.isNotEmpty()) {
                        s.printTwoCols("Other / Credit:", otherSales, size = 20, bold = false)
                    }
                    s.printDivider("-", 32)

                    s.printText("DRAWER RECONCILIATION", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                    s.printTwoCols("Opening Balance:", openingBalance, size = 20, bold = false)
                    s.printTwoCols("+ Cash Sales:", cashSales, size = 20, bold = false)
                    if (paidIn != "LKR 0.00" && paidIn.isNotEmpty()) {
                        s.printTwoCols("+ Paid In (Entry):", paidIn, size = 20, bold = false)
                    }
                    if (paidOut != "LKR 0.00" && paidOut.isNotEmpty()) {
                        s.printTwoCols("- Paid Out (Expense):", "-$paidOut", size = 20, bold = false)
                    }
                    s.printDivider("-", 32)
                    s.printTwoCols("Expected Cash:", expectedCash, size = 22, bold = true)
                    s.printTwoCols("Actual Cash in Hand:", actualCash, size = 22, bold = true)
                    s.printTwoCols("OVER / SHORT:", cashDiff, 22, bold = true)
                }

                s.printDivider("-", 32)
                s.printSpace(1)
                s.printText("Cashier Signature: _____________", size = 20, bold = false, align = Layout.Alignment.ALIGN_NORMAL)
                s.printSpace(1)
                s.printText("Manager Signature: _____________", size = 20, bold = false, align = Layout.Alignment.ALIGN_NORMAL)
                s.printDivider("-", 32)

                s.feedAndCut(5)
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing shift report on DBL Z92: ${e.message}", e)
                onComplete(false, "DBL Z92 print error: ${e.message}")
            }
        }.start()
    }

    // ==========================================
    // 4. EXCHANGE VOUCHER RECEIPT
    // ==========================================
    fun printExchangeReceipt(
        exchangeData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!isPrinterReady()) {
                    onComplete(false, "DBL Z92 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z92 printer instance is null")
                val s = NativePrinterSession(p, context)

                val appName = exchangeData["appName"] as? String ?: "ONIMTA POS"
                val voucherCode = exchangeData["voucherCode"] as? String ?: ""
                val totalAmount = exchangeData["totalAmount"] as? String ?: "LKR 0.00"
                val customerName = exchangeData["customerName"] as? String ?: "Walk-in Customer"
                val cashierName = exchangeData["cashierName"] as? String ?: "Admin"
                val dateTime = exchangeData["dateTime"] as? String ?: ""
                val items = exchangeData["items"] as? List<Map<String, Any?>> ?: emptyList()

                s.printText(appName, size = 28, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("EXCHANGE VOUCHER / SLIP", size = 22, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 32)

                s.printTwoCols("Voucher #:", voucherCode, size = 24, bold = true)
                s.printTwoCols("Date:", dateTime, size = 20, bold = false)
                s.printTwoCols("Cashier:", cashierName, size = 20, bold = false)
                if (customerName.isNotEmpty() && customerName != "Walk-in Customer") {
                    s.printTwoCols("Customer:", customerName, size = 20, bold = false)
                }
                s.printDivider("-", 32)

                s.printText("EXCHANGED ITEMS RETURNED:", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                for (item in items) {
                    val desc = item["description"] as? String ?: ""
                    val qty = item["qty"] as? String ?: "1"
                    val price = item["price"] as? String ?: ""
                    val total = item["total"] as? String ?: ""
                    s.printText(desc, size = 22, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                    s.printTwoCols("  $qty x $price", total, size = 20, bold = false)
                }
                s.printDivider("-", 32)

                s.printTwoCols("TOTAL CREDIT VALUE:", totalAmount, size = 24, bold = true)
                s.printDivider("-", 32)

                if (voucherCode.isNotEmpty()) {
                    s.printBarCode(voucherCode, height = 70, width = 300)
                    s.printText("* $voucherCode *", size = 22, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                    s.printQrCode(voucherCode, size = 180)
                }

                s.printDivider("-", 32)
                s.printText("Scan barcode or QR code to redeem", size = 18, bold = false, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("exchange credit on your next bill.", size = 18, bold = false, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 32)

                s.feedAndCut(5)
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing exchange receipt on DBL Z92: ${e.message}", e)
                onComplete(false, "DBL Z92 print error: ${e.message}")
            }
        }.start()
    }

    // ==========================================
    // 5. SALES RETURN RECEIPT
    // ==========================================
    fun printReturnReceipt(
        returnData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!isPrinterReady()) {
                    onComplete(false, "DBL Z92 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z92 printer instance is null")
                val s = NativePrinterSession(p, context)

                val appName = returnData["appName"] as? String ?: "ONIMTA POS"
                val returnNo = returnData["returnNo"] as? String ?: ""
                val refundAmount = returnData["refundAmount"] as? String ?: "LKR 0.00"
                val paymentMethod = returnData["paymentMethod"] as? String ?: "Cash"
                val reason = returnData["reason"] as? String ?: "Customer Return"
                val customerName = returnData["customerName"] as? String ?: "Walk-in Customer"
                val cashierName = returnData["cashierName"] as? String ?: "Admin"
                val dateTime = returnData["dateTime"] as? String ?: ""
                val items = returnData["items"] as? List<Map<String, Any?>> ?: emptyList()

                s.printText(appName, size = 28, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("RETURN / REFUND RECEIPT", size = 22, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 32)

                s.printTwoCols("Return Ref #:", returnNo, size = 22, bold = true)
                s.printTwoCols("Date:", dateTime, size = 20, bold = false)
                s.printTwoCols("Cashier:", cashierName, size = 20, bold = false)
                if (customerName.isNotEmpty() && customerName != "Walk-in Customer") {
                    s.printTwoCols("Customer:", customerName, size = 20, bold = false)
                }
                s.printTwoCols("Reason:", reason, size = 20, bold = false)
                s.printDivider("-", 32)

                s.printText("RETURNED ITEMS:", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                for (item in items) {
                    val desc = item["description"] as? String ?: ""
                    val qty = item["qty"] as? String ?: "1"
                    val price = item["price"] as? String ?: ""
                    val total = item["total"] as? String ?: ""
                    s.printText(desc, size = 22, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                    s.printTwoCols("  $qty x $price", total, size = 20, bold = false)
                }
                s.printDivider("-", 32)

                s.printTwoCols("REFUNDED VIA:", paymentMethod, size = 22, bold = true)
                s.printTwoCols("TOTAL REFUNDED:", refundAmount, size = 24, bold = true)
                s.printDivider("-", 32)

                s.printSpace(1)
                s.printText("Cashier Sign: _____________", size = 20, bold = false, align = Layout.Alignment.ALIGN_NORMAL)
                s.printSpace(1)
                s.printText("Customer Sign: ____________", size = 20, bold = false, align = Layout.Alignment.ALIGN_NORMAL)
                s.printDivider("-", 32)

                s.feedAndCut(5)
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing return receipt on DBL Z92: ${e.message}", e)
                onComplete(false, "DBL Z92 print error: ${e.message}")
            }
        }.start()
    }

    // ==========================================
    // 6. HOLD RECEIPT (SUSPENDED SALE)
    // ==========================================
    fun printHoldReceipt(
        holdData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!isPrinterReady()) {
                    onComplete(false, "DBL Z92 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z92 printer instance is null")
                val s = NativePrinterSession(p, context)

                val appName = holdData["appName"] as? String ?: "ONIMTA POS"
                val holdNo = holdData["holdNo"] as? String ?: ""
                val totalAmount = holdData["totalAmount"] as? String ?: "LKR 0.00"
                val totalItems = (holdData["totalItems"] as? String) ?: ""
                val customerName = (holdData["customerName"] as? String) ?: (holdData["customer"] as? String) ?: "Walk-in Customer"
                val cashierName = (holdData["cashierName"] as? String) ?: (holdData["cashier"] as? String) ?: "Admin"
                val dateTime = holdData["dateTime"] as? String ?: ""
                val items = holdData["items"] as? List<Map<String, Any?>> ?: emptyList()

                s.printText(appName, size = 28, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("*** HELD BILL RECEIPT ***", size = 24, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 32)

                s.printTwoCols("Hold Bill #:", holdNo, size = 24, bold = true)
                if (dateTime.isNotEmpty()) s.printTwoCols("Date:", dateTime, size = 20, bold = false)
                s.printTwoCols("Cashier:", cashierName, size = 20, bold = false)
                if (customerName.isNotEmpty() && customerName != "Walk-in Customer") {
                    s.printTwoCols("Customer:", customerName, size = 20, bold = false)
                }
                s.printDivider("-", 32)

                if (items.isNotEmpty()) {
                    s.printText("HELD ITEMS", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                    for (item in items) {
                        val desc = item["description"] as? String ?: ""
                        val qty = item["qty"] as? String ?: "1"
                        val price = item["price"] as? String ?: ""
                        val total = item["total"] as? String ?: ""
                        s.printText(desc, size = 22, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                        s.printTwoCols("  $qty x $price", total, size = 20, bold = false)
                    }
                    s.printDivider("-", 32)
                }

                if (totalItems.isNotEmpty()) {
                    s.printTwoCols("Total Items:", totalItems, size = 22, bold = true)
                }
                s.printTwoCols("HELD AMOUNT:", totalAmount, size = 26, bold = true)
                s.printDivider("-", 32)

                if (holdNo.isNotEmpty()) {
                    s.printBarCode(holdNo, height = 110, width = 384)
                    s.printText("* $holdNo *", size = 22, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                    s.printQrCode(holdNo, size = 180)
                    s.printDivider("-", 32)
                    s.printText("Scan barcode or QR code to recall", size = 18, bold = false, align = Layout.Alignment.ALIGN_CENTER)
                    s.printText("held bill to current cart.", size = 18, bold = false, align = Layout.Alignment.ALIGN_CENTER)
                    s.printDivider("-", 32)
                }

                s.feedAndCut(5)
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing hold receipt on DBL Z92: ${e.message}", e)
                onComplete(false, "DBL Z92 print error: ${e.message}")
            }
        }.start()
    }

    // ==========================================
    // 7. ITEM-WISE SALES REPORT
    // ==========================================
    fun printItemWiseSalesReport(
        reportData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!isPrinterReady()) {
                    onComplete(false, "DBL Z92 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z92 printer instance is null")
                val s = NativePrinterSession(p, context)

                val appName = reportData["appName"] as? String ?: "ONIMTA POS"
                val title = reportData["title"] as? String ?: "ITEM WISE SALES"
                val period = reportData["period"] as? String ?: "Today"
                val cashier = (reportData["cashierName"] as? String) ?: (reportData["cashier"] as? String) ?: "Admin"
                val dateTime = reportData["dateTime"] as? String ?: ""
                val totalQty = (reportData["totalQuantity"] as? String) ?: (reportData["totalQty"] as? String) ?: "0"
                val totalRevenue = reportData["totalRevenue"] as? String ?: "LKR 0.00"
                val items = reportData["items"] as? List<Map<String, Any?>> ?: emptyList()

                s.printText(appName, size = 28, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText(title, size = 22, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 32)

                s.printTwoCols("Period:", period, size = 20, bold = false)
                s.printTwoCols("Cashier:", cashier, size = 20, bold = false)
                if (dateTime.isNotEmpty()) {
                    s.printTwoCols("Date:", dateTime, size = 20, bold = false)
                }
                s.printDivider("-", 32)

                s.printText("ITEM DESCRIPTION", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                s.printTwoCols("  SOLD QTY", "TOTAL AMOUNT", size = 20, bold = true)
                s.printDivider("-", 32)

                var rank = 1
                for (item in items) {
                    val desc = item["description"] as? String ?: ""
                    val qty = (item["qty"] as? String) ?: (item["quantity"] as? String) ?: "0"
                    val total = (item["total"] as? String) ?: (item["amount"] as? String) ?: "LKR 0.00"
                    s.printText("$rank. $desc", size = 22, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                    s.printTwoCols("   Qty: $qty", total, size = 20, bold = false)
                    rank++
                }

                s.printDivider("-", 32)
                s.printTwoCols("TOTAL ITEMS SOLD:", totalQty, size = 22, bold = true)
                s.printTwoCols("TOTAL REVENUE:", totalRevenue, size = 26, bold = true)
                s.printDivider("-", 32)

                s.feedAndCut(5)
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing item-wise report on DBL Z92: ${e.message}", e)
                onComplete(false, "DBL Z92 print error: ${e.message}")
            }
        }.start()
    }

    // ==========================================
    // 8. TOTAL SALES REPORT
    // ==========================================
    fun printTotalSalesReport(
        reportData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!isPrinterReady()) {
                    onComplete(false, "DBL Z92 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z92 printer instance is null")
                val s = NativePrinterSession(p, context)

                val appName = reportData["appName"] as? String ?: "ONIMTA POS"
                val title = reportData["title"] as? String ?: "TOTAL SALES REPORT"
                val period = reportData["period"] as? String ?: "Today"
                val cashier = (reportData["cashierName"] as? String) ?: (reportData["cashier"] as? String) ?: "Admin"
                val dateTime = reportData["dateTime"] as? String ?: ""

                val totalInvoices = reportData["totalInvoices"] as? String ?: "0"
                val grossSales = reportData["grossSales"] as? String ?: "LKR 0.00"
                val discount = (reportData["discount"] as? String) ?: (reportData["totalDiscount"] as? String) ?: "LKR 0.00"
                val tax = (reportData["tax"] as? String) ?: (reportData["totalTax"] as? String) ?: "LKR 0.00"
                val netSales = reportData["netSales"] as? String ?: "LKR 0.00"

                val returnsCount = reportData["returnsCount"] as? String ?: "0"
                val returnsAmount = reportData["returnsAmount"] as? String ?: "LKR 0.00"
                val totalNetRevenue = (reportData["totalNetRevenue"] as? String) ?: netSales

                val cashSales = reportData["cashSales"] as? String ?: "LKR 0.00"
                val cardSales = reportData["cardSales"] as? String ?: "LKR 0.00"
                val qrSales = reportData["qrSales"] as? String ?: "LKR 0.00"
                val creditSales = reportData["creditSales"] as? String ?: "LKR 0.00"

                s.printText(appName, size = 28, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText(title, size = 22, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 32)

                s.printTwoCols("Period:", period, size = 20, bold = false)
                s.printTwoCols("Cashier:", cashier, size = 20, bold = false)
                if (dateTime.isNotEmpty()) {
                    s.printTwoCols("Date:", dateTime, size = 20, bold = false)
                }
                s.printDivider("-", 32)

                s.printText("SALES SUMMARY", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                s.printTwoCols("Total Invoices:", totalInvoices, size = 20, bold = false)
                s.printTwoCols("Gross Sales:", grossSales, size = 20, bold = false)
                if (discount.isNotEmpty() && discount != "LKR 0.00" && discount != "0.00") {
                    s.printTwoCols("Discounts:", "-$discount", size = 20, bold = false)
                }
                if (tax.isNotEmpty() && tax != "LKR 0.00" && tax != "0.00") {
                    s.printTwoCols("Tax:", tax, size = 20, bold = false)
                }
                s.printTwoCols("Net Sales:", netSales, size = 22, bold = true)
                if (returnsCount != "0" && returnsCount.isNotEmpty()) {
                    s.printTwoCols("Returns ($returnsCount bills):", "-$returnsAmount", size = 20, bold = false)
                }
                s.printDivider("-", 32)
                s.printTwoCols("TOTAL NET REVENUE:", totalNetRevenue, size = 26, bold = true)
                s.printDivider("-", 32)

                s.printText("PAYMENTS / TENDER BREAKDOWN", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                s.printTwoCols("Cash Sales:", cashSales, size = 20, bold = false)
                s.printTwoCols("Card Sales:", cardSales, size = 20, bold = false)
                if (qrSales != "LKR 0.00" && qrSales.isNotEmpty()) {
                    s.printTwoCols("QR / Online:", qrSales, size = 20, bold = false)
                }
                if (creditSales != "LKR 0.00" && creditSales.isNotEmpty()) {
                    s.printTwoCols("Credit Sales:", creditSales, size = 20, bold = false)
                }
                s.printDivider("-", 32)

                s.feedAndCut(5)
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing total sales report on DBL Z92: ${e.message}", e)
                onComplete(false, "DBL Z92 print error: ${e.message}")
            }
        }.start()
    }
}
