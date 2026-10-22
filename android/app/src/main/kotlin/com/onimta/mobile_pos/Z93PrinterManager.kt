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
 * Native thermal printer manager for DBL Z93 (Shenzhen ZCS Z93 Smart POS)
 * with integrated 80mm thermal receipt printer (576-dot scanline width).
 *
 * Features:
 * 1. Native 80mm scanline width (576 dots / 48 monospace characters per line).
 * 2. Razor-sharp continuous spool printing with zero motor stepping pauses.
 * 3. High-precision 2-column & 3-column raster layout with exact right alignment.
 * 4. Crisp 1D Code-128 & QR code generation via BarcodeBitmapHelper.
 * 5. Full support for auto-cutter / tear bar paper advance.
 */
class Z93PrinterManager(private val context: Context) {
    companion object {
        const val PAPER_WIDTH = 576 // 80mm thermal paper = 576 dots
    }

    private val TAG = "Z93PrinterManager"

    private var driverManager: DriverManager? = null
    private var printer: Printer? = null
    private var isInitialized = false

    var activeFont: String = "MONOSPACE"

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
                    // Set 80mm thermal width (576 dots)
                    val field = printer?.javaClass?.getDeclaredField("d")
                    field?.isAccessible = true
                    field?.setInt(printer, 576)
                } catch (_: Throwable) {}
                try {
                    // Maximum high-contrast thermal density (Level 5 is darkest black)
                    printer?.setPrintGray(5.toByte())
                    printer?.setPrintSpeed(PrnSpeedTypeEnum.MEDIUM_SPEED)
                } catch (_: Throwable) {}
            }
            Log.d(TAG, "DBL Z93 80mm Printer initialized successfully: $printer")
            isInitialized
        } catch (e: Throwable) {
            Log.w(TAG, "DBL Z93 Printer init error (device might not be Z93): ${e.message}")
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
            Log.d(TAG, "DBL Z93 Printer status query: $status")
            status != SdkResult.SDK_PRN_STATUS_PAPEROUT && status != SdkResult.SDK_PRN_STATUS_FAULT
        } catch (e: Throwable) {
            Log.w(TAG, "DBL Z93 isPrinterReady exception: ${e.message}")
            false
        }
    }

    // =========================================================================
    // NATIVE 80MM (576-DOT) THERMAL PRINTING ENGINE
    // =========================================================================

    private inner class NativePrinterSession(
        private val p: Printer,
        private val context: Context,
        private val fontType: String = activeFont
    ) {


        private fun getPrnFont(): PrnTextFont {
            return when (fontType.uppercase()) {
                "SANS_SERIF" -> PrnTextFont.SANS_SERIF
                "SERIF" -> PrnTextFont.SERIF
                "DEFAULT_BOLD" -> PrnTextFont.DEFAULT_BOLD
                "DEFAULT" -> PrnTextFont.DEFAULT
                else -> PrnTextFont.MONOSPACE
            }
        }

        private fun getTypeface(bold: Boolean): Typeface {
            val base = when (fontType.uppercase()) {
                "SANS_SERIF" -> Typeface.SANS_SERIF
                "SERIF" -> Typeface.SERIF
                "DEFAULT_BOLD" -> Typeface.DEFAULT_BOLD
                "DEFAULT" -> Typeface.DEFAULT
                else -> Typeface.MONOSPACE
            }
            return Typeface.create(base, if (bold) Typeface.BOLD else Typeface.NORMAL)
        }

        init {
            try {
                // Ensure 576-dot width is active
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
            size: Int = 22,
            bold: Boolean = false,
            align: Layout.Alignment = Layout.Alignment.ALIGN_NORMAL
        ) {
            if (text.isEmpty()) {
                printSpace(1)
                return
            }
            try {
                val paint = Paint().apply {
                    textSize = size.toFloat()
                    typeface = getTypeface(bold)
                    color = Color.BLACK
                    isAntiAlias = false
                    if (bold) isFakeBoldText = true
                }
                val fm = paint.fontMetrics
                val lineHeight = (fm.descent - fm.ascent).toInt()
                val baseline = -fm.ascent
                val paddingY = 2
                val h = lineHeight + (paddingY * 2)

                val bmp = Bitmap.createBitmap(PAPER_WIDTH, h, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bmp)
                canvas.drawColor(Color.WHITE)

                val leftX = 8f
                val rightX = (PAPER_WIDTH - 8).toFloat()

                val x = when (align) {
                    Layout.Alignment.ALIGN_CENTER -> PAPER_WIDTH / 2f
                    Layout.Alignment.ALIGN_OPPOSITE -> rightX
                    else -> leftX
                }
                paint.textAlign = when (align) {
                    Layout.Alignment.ALIGN_CENTER -> Paint.Align.CENTER
                    Layout.Alignment.ALIGN_OPPOSITE -> Paint.Align.RIGHT
                    else -> Paint.Align.LEFT
                }
                canvas.drawText(text, x, baseline + paddingY, paint)
                p.setPrintAppendBitmap(bmp, Layout.Alignment.ALIGN_NORMAL, PAPER_WIDTH)
            } catch (e: Throwable) {
                Log.w("Z93Printer", "printText error: ${e.message}")
            }
        }

        fun printTwoCols(
            left: String,
            right: String,
            size: Int = 23,
            bold: Boolean = false,
            indent: Float = 8f
        ) {
            try {
                val paint = Paint().apply {
                    textSize = size.toFloat()
                    typeface = getTypeface(bold)
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
                val leftX = indent
                val rightX = (PAPER_WIDTH - 8).toFloat()

                if (leftWidth + rightWidth + 16f <= (PAPER_WIDTH - (indent + 8f))) {
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
                Log.w("Z93Printer", "printTwoCols error: ${e.message}")
            }
        }

        fun printThreeCols(
            left: String,
            middle: String,
            right: String,
            leftWidth: Int = 24,
            middleWidth: Int = 10,
            rightWidth: Int = 14,
            size: Int = 20,
            bold: Boolean = false
        ) {
            try {
                val paint = Paint().apply {
                    textSize = size.toFloat()
                    typeface = getTypeface(bold)
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
                canvas.drawText(left, 6f, baseline + paddingY, paint)

                paint.textAlign = Paint.Align.CENTER
                canvas.drawText(middle, 320f, baseline + paddingY, paint)

                paint.textAlign = Paint.Align.RIGHT
                canvas.drawText(right, (PAPER_WIDTH - 8).toFloat(), baseline + paddingY, paint)

                p.setPrintAppendBitmap(bmp, Layout.Alignment.ALIGN_NORMAL, PAPER_WIDTH)
            } catch (e: Throwable) {
                Log.w("Z93Printer", "printThreeCols error: ${e.message}")
            }
        }

        private fun wrapText(text: String, maxWidth: Float, paint: Paint): List<String> {
            val words = text.split(" ")
            val lines = mutableListOf<String>()
            var currentLine = StringBuilder()

            for (word in words) {
                if (word.isEmpty()) continue
                val testLine = if (currentLine.isEmpty()) word else "$currentLine $word"
                if (paint.measureText(testLine) <= maxWidth) {
                    currentLine = StringBuilder(testLine)
                } else {
                    if (currentLine.isNotEmpty()) {
                        lines.add(currentLine.toString())
                        currentLine = StringBuilder(word)
                    } else {
                        var remaining = word
                        while (remaining.isNotEmpty()) {
                            var count = remaining.length
                            while (count > 0 && paint.measureText(remaining.substring(0, count)) > maxWidth) {
                                count--
                            }
                            if (count == 0) count = 1
                            lines.add(remaining.substring(0, count))
                            remaining = remaining.substring(count)
                        }
                    }
                }
            }
            if (currentLine.isNotEmpty()) {
                lines.add(currentLine.toString())
            }
            return lines
        }

        fun printTableHeader(
            size: Int = 23,
            bold: Boolean = true
        ) {
            try {
                val paint = Paint().apply {
                    textSize = size.toFloat()
                    typeface = getTypeface(bold)
                    color = Color.BLACK
                    isAntiAlias = false
                    if (bold) isFakeBoldText = true
                }
                val fm = paint.fontMetrics
                val textHeight = (fm.descent - fm.ascent).toInt()
                val baseline = -fm.ascent
                val paddingY = 2
                val h = textHeight + (paddingY * 2)

                val bmp = Bitmap.createBitmap(PAPER_WIDTH, h, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bmp)
                canvas.drawColor(Color.WHITE)

                val leftX = 8f
                val productX = 58f
                val priceX = 330f
                val qtyCenterX = 415f
                val totalX = (PAPER_WIDTH - 8).toFloat()

                // LN
                paint.textAlign = Paint.Align.LEFT
                canvas.drawText("LN", leftX, baseline + paddingY, paint)

                // PRODUCT
                canvas.drawText("PRODUCT", productX, baseline + paddingY, paint)

                // PRICE
                paint.textAlign = Paint.Align.RIGHT
                canvas.drawText("PRICE", priceX, baseline + paddingY, paint)

                // QTY
                paint.textAlign = Paint.Align.CENTER
                canvas.drawText("QTY", qtyCenterX, baseline + paddingY, paint)

                // TOTAL
                paint.textAlign = Paint.Align.RIGHT
                canvas.drawText("TOTAL", totalX, baseline + paddingY, paint)

                p.setPrintAppendBitmap(bmp, Layout.Alignment.ALIGN_NORMAL, PAPER_WIDTH)
            } catch (e: Throwable) {
                Log.w("Z93Printer", "printTableHeader error: ${e.message}")
            }
        }

        fun printProductRow(
            ln: Int,
            desc: String,
            size: Int = 23,
            bold: Boolean = true
        ) {
            try {
                val paint = Paint().apply {
                    textSize = size.toFloat()
                    typeface = getTypeface(bold)
                    color = Color.BLACK
                    isAntiAlias = false
                    if (bold) isFakeBoldText = true
                }
                val fm = paint.fontMetrics
                val lineHeight = (fm.descent - fm.ascent).toInt()
                val baseline = -fm.ascent
                val paddingY = 2

                val leftX = 8f
                val productX = 58f
                val maxTextWidth = (PAPER_WIDTH - 8) - productX

                val descLines = wrapText(desc, maxTextWidth, paint)
                if (descLines.isEmpty()) {
                    return
                }

                val totalHeight = (descLines.size * lineHeight) + (paddingY * 2)
                val bmp = Bitmap.createBitmap(PAPER_WIDTH, totalHeight, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bmp)
                canvas.drawColor(Color.WHITE)

                paint.textAlign = Paint.Align.LEFT
                // Line number only on line 1, perfectly matching "LN" header at leftX
                canvas.drawText(String.format("%2d.", ln), leftX, baseline + paddingY, paint)

                // Every line of description starts strictly at productX under "PRODUCT" column
                for (i in descLines.indices) {
                    val y = baseline + paddingY + (i * lineHeight)
                    canvas.drawText(descLines[i], productX, y, paint)
                }

                p.setPrintAppendBitmap(bmp, Layout.Alignment.ALIGN_NORMAL, PAPER_WIDTH)
            } catch (e: Throwable) {
                Log.w("Z93Printer", "printProductRow error: ${e.message}")
            }
        }

        fun printItemValues(
            price: String,
            qty: String,
            total: String,
            size: Int = 23,
            bold: Boolean = true
        ) {
            try {
                val paint = Paint().apply {
                    textSize = size.toFloat()
                    typeface = getTypeface(bold)
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

                val priceX = 330f
                val qtyCenterX = 415f
                val totalX = (PAPER_WIDTH - 8).toFloat()

                // Price (aligned right with "PRICE" header)
                paint.textAlign = Paint.Align.RIGHT
                canvas.drawText(cleanAmount(price), priceX, baseline + paddingY, paint)

                // Qty (aligned center with "QTY" header)
                paint.textAlign = Paint.Align.CENTER
                canvas.drawText(qty, qtyCenterX, baseline + paddingY, paint)

                // Total (aligned right with "TOTAL" header and financial totals)
                paint.textAlign = Paint.Align.RIGHT
                canvas.drawText(cleanAmount(total), totalX, baseline + paddingY, paint)

                p.setPrintAppendBitmap(bmp, Layout.Alignment.ALIGN_NORMAL, PAPER_WIDTH)
            } catch (e: Throwable) {
                Log.w("Z93Printer", "printItemValues error: ${e.message}")
            }
        }

        fun printItemCols(
            col1: String,
            col2: String,
            col3: String,
            col4: String,
            size: Int = 23,
            bold: Boolean = true
        ) {
            if (col1.contains("PRODUCT", ignoreCase = true) || col1.contains("LN", ignoreCase = true)) {
                printTableHeader(size, bold)
            } else if (col1.isEmpty()) {
                printItemValues(col2, col3, col4, size, bold)
            } else {
                try {
                    val paint = Paint().apply {
                        textSize = size.toFloat()
                        typeface = getTypeface(bold)
                        color = Color.BLACK
                        isAntiAlias = false
                        if (bold) isFakeBoldText = true
                    }
                    val fm = paint.fontMetrics
                    val textHeight = (fm.descent - fm.ascent).toInt()
                    val baseline = -fm.ascent
                    val paddingY = 2
                    val h = textHeight + (paddingY * 2)

                    val bmp = Bitmap.createBitmap(PAPER_WIDTH, h, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bmp)
                    canvas.drawColor(Color.WHITE)

                    val leftX = 8f
                    val priceX = 330f
                    val qtyCenterX = 415f
                    val totalX = (PAPER_WIDTH - 8).toFloat()

                    paint.textAlign = Paint.Align.LEFT
                    canvas.drawText(col1, leftX, baseline + paddingY, paint)

                    paint.textAlign = Paint.Align.RIGHT
                    if (col2.isNotEmpty()) canvas.drawText(col2, priceX, baseline + paddingY, paint)

                    paint.textAlign = Paint.Align.CENTER
                    if (col3.isNotEmpty()) canvas.drawText(col3, qtyCenterX, baseline + paddingY, paint)

                    paint.textAlign = Paint.Align.RIGHT
                    if (col4.isNotEmpty()) canvas.drawText(col4, totalX, baseline + paddingY, paint)

                    p.setPrintAppendBitmap(bmp, Layout.Alignment.ALIGN_NORMAL, PAPER_WIDTH)
                } catch (e: Throwable) {
                    Log.w("Z93Printer", "printItemCols error: ${e.message}")
                }
            }
        }

        fun cleanAmount(amountStr: String): String {
            return amountStr.replace("Rs.", "", ignoreCase = true)
                .replace("Rs", "", ignoreCase = true)
                .replace("LKR", "", ignoreCase = true)
                .trim()
        }

        fun cleanPrice(priceStr: String) = cleanAmount(priceStr)

        fun printDivider(lineChar: String = "-", totalChars: Int = 48) {
            try {
                val h = 14
                val bmp = Bitmap.createBitmap(PAPER_WIDTH, h, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bmp)
                canvas.drawColor(Color.WHITE)
                val paint = Paint().apply {
                    color = Color.BLACK
                    strokeWidth = if (lineChar == "=") 2.5f else 1.5f
                    isAntiAlias = false
                }
                val leftX = 8f
                val rightX = (PAPER_WIDTH - 8).toFloat()
                val y = h / 2f
                if (lineChar == "=") {
                    canvas.drawLine(leftX, y - 2.5f, rightX, y - 2.5f, paint)
                    canvas.drawLine(leftX, y + 2.5f, rightX, y + 2.5f, paint)
                } else {
                    canvas.drawLine(leftX, y, rightX, y, paint)
                }
                p.setPrintAppendBitmap(bmp, Layout.Alignment.ALIGN_NORMAL, PAPER_WIDTH)
            } catch (e: Throwable) {
                Log.w("Z93Printer", "printDivider error: ${e.message}")
            }
        }

        fun printSpace(lines: Int = 1) {
            try {
                val h = (26 * lines).coerceAtLeast(10)
                val bmp = Bitmap.createBitmap(PAPER_WIDTH, h, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bmp)
                canvas.drawColor(Color.WHITE)
                p.setPrintAppendBitmap(bmp, Layout.Alignment.ALIGN_NORMAL, PAPER_WIDTH)
            } catch (e: Throwable) {
                Log.w("Z93Printer", "printSpace error: ${e.message}")
            }
        }

        fun printBarCode(code: String, height: Int = 120, width: Int = 576) {
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
                Log.w("Z93Printer", "printBarCode error: ${e.message}")
            }
        }

        fun printQrCode(code: String, size: Int = 200) {
            try {
                val bmp = BarcodeBitmapHelper.createCrispQrCode(code, size)
                if (bmp != null) {
                    p.setPrintAppendBitmap(bmp, Layout.Alignment.ALIGN_CENTER, PAPER_WIDTH)
                } else {
                    p.setPrintAppendQRCode(code, size, size, Layout.Alignment.ALIGN_CENTER, PAPER_WIDTH)
                }
            } catch (e: Throwable) {
                Log.w("Z93Printer", "printQrCode error: ${e.message}")
            }
        }

        fun feedAndCut(feedBlankDots: Int = 200): Boolean {
            try {
                val actualDots = if (feedBlankDots <= 10) feedBlankDots * 40 else feedBlankDots

                val blankBmp = Bitmap.createBitmap(PAPER_WIDTH, actualDots, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(blankBmp)
                canvas.drawColor(Color.WHITE)
                p.setPrintAppendBitmap(blankBmp, Layout.Alignment.ALIGN_NORMAL, PAPER_WIDTH)
                try {
                    p.setPrintGray(5.toByte())
                    p.setPrintSpeed(PrnSpeedTypeEnum.MEDIUM_SPEED)
                } catch (_: Throwable) {}

                val result = p.setPrintStart(PAPER_WIDTH)
                Log.d("Z93Printer", "Native 80mm spool print finished with result code: $result")

                // Attempt hardware auto-cutter if supported on 80mm model
                try {
                    p.openPrnCutter(0.toByte())
                } catch (_: Throwable) {
                    try {
                        p.setPrintLine(2)
                    } catch (_: Throwable) {}
                }

                return result == SdkResult.SDK_OK || result == 0
            } catch (e: Throwable) {
                Log.w("Z93Printer", "feedAndCut error: ${e.message}")
                return false
            }
        }
    }

    // ==========================================
    // 1. SALE RECEIPT (80mm)
    // ==========================================
    fun printReceipt(
        receiptData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!isPrinterReady()) {
                    onComplete(false, "DBL Z93 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z93 printer instance is null")
                val s = NativePrinterSession(p, context)

                val appName = (receiptData["appName"] as? String ?: "ONIMTA POS").uppercase()
                val invoiceNo = (receiptData["invoiceNo"] as? String ?: "").uppercase()
                val customerName = (receiptData["customerName"] as? String ?: "WALK-IN CUSTOMER").uppercase()
                val cashierName = (receiptData["cashierName"] as? String ?: "ADMIN").uppercase()
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

                // 1. Header (80mm Spacious Layout)
                s.printText(appName, size = 30, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("ORDER INVOICE", size = 24, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 48)

                // 2. Invoice Info
                s.printTwoCols("INVOICE #:", invoiceNo, size = 24, bold = true)
                if (dateStr.isNotEmpty()) s.printTwoCols("DATE:", dateStr, size = 22, bold = false)
                s.printTwoCols("CASHIER:", cashierName, size = 22, bold = false)
                s.printTwoCols("CUSTOMER:", customerName, size = 22, bold = false)
                s.printDivider("-", 48)

                // 3. Items List
                s.printTableHeader(size = 23, bold = true)
                s.printDivider("-", 48)

                var ln = 1
                for (item in items) {
                    val desc = (item["description"] as? String ?: "").uppercase()
                    val qty = item["qty"] as? String ?: "1"
                    val price = item["price"] as? String ?: ""
                    val itemDisc = item["discount"] as? String ?: ""
                    val total = item["total"] as? String ?: ""

                    s.printProductRow(ln, desc, size = 23, bold = true)
                    s.printItemValues(price, qty, total, size = 23, bold = true)
                    if (itemDisc.isNotEmpty() && itemDisc != "LKR 0.00" && itemDisc != "0.00") {
                        val cleanDisc = s.cleanAmount(itemDisc)
                        s.printTwoCols("    ITEM DISC:", "-$cleanDisc", size = 20, bold = false)
                    }
                    ln++
                }
                s.printDivider("-", 48)

                // 4. Financial Summary
                s.printTwoCols("SUBTOTAL:", s.cleanAmount(subtotal), size = 23, bold = false)
                if (discount.isNotEmpty() && discount != "LKR 0.00" && discount != "0.00") {
                    s.printTwoCols("DISCOUNT:", "-${s.cleanAmount(discount)}", size = 23, bold = false)
                }
                if (exchangeCredit.isNotEmpty() && exchangeCredit != "LKR 0.00" && exchangeCredit != "0.00") {
                    s.printTwoCols("EXCHANGE CREDIT:", "-${s.cleanAmount(exchangeCredit)}", size = 23, bold = false)
                }
                if (tax.isNotEmpty() && tax != "LKR 0.00" && tax != "0.00") {
                    s.printTwoCols("TAX:", s.cleanAmount(tax), size = 23, bold = false)
                }
                s.printDivider("=", 48)
                s.printTwoCols("GRAND TOTAL (LKR):", s.cleanAmount(grandTotal), size = 32, bold = true)
                s.printDivider("=", 48)

                // 5. Payments Breakdown
                if (payments.isNotEmpty()) {
                    s.printTwoCols("PAYMENTS:", "", size = 23, bold = true)
                    for (pay in payments) {
                        val method = (pay["method"] as? String ?: "PAYMENT").uppercase()
                        val amt = pay["amount"] as? String ?: ""
                        s.printTwoCols("  $method", s.cleanAmount(amt), size = 22, bold = false, indent = 24f)
                    }
                }
                if (totalPaid.isNotEmpty()) s.printTwoCols("TOTAL PAID:", s.cleanAmount(totalPaid), size = 23, bold = true)
                if (change.isNotEmpty() && change != "LKR 0.00" && change != "0.00") {
                    s.printTwoCols("CHANGE RETURNED:", s.cleanAmount(change), size = 23, bold = true)
                }
                s.printDivider("-", 48)

                // 6. Footer & Clear paper feed
                s.printText("THANK YOU FOR SHOPPING WITH US!", size = 22, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("PLEASE COME AGAIN", size = 20, bold = false, align = Layout.Alignment.ALIGN_CENTER)

                s.feedAndCut(5)
                Log.d(TAG, "DBL Z93 80mm sale receipt printed cleanly")
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing receipt on DBL Z93: ${e.message}", e)
                onComplete(false, "DBL Z93 print error: ${e.message}")
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
                    onComplete(false, "DBL Z93 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z93 printer instance is null")
                val s = NativePrinterSession(p, context)

                val appName = (movementData["appName"] as? String ?: "ONIMTA POS").uppercase()
                val type = (movementData["type"] as? String ?: "PAID IN").uppercase()
                val amount = movementData["amount"] as? String ?: "LKR 0.00"
                val reason = (movementData["reason"] as? String ?: "CASH MOVEMENT").uppercase()
                val cashier = (movementData["cashier"] as? String ?: "ADMIN").uppercase()
                val dateStr = movementData["dateTime"] as? String ?: ""

                s.printText(appName, size = 30, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("CASH MOVEMENT / VOUCHER", size = 24, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 48)

                s.printTwoCols("TRANSACTION:", type, size = 24, bold = true)
                s.printTwoCols("AMOUNT:", amount, size = 26, bold = true)
                s.printDivider("-", 48)

                s.printTwoCols("REASON:", reason, size = 22, bold = false)
                s.printTwoCols("CASHIER:", cashier, size = 22, bold = false)
                s.printTwoCols("DATE & TIME:", dateStr, size = 22, bold = false)
                s.printDivider("-", 48)

                s.printSpace(1)
                s.printText("AUTHORIZED BY: ....................", size = 20, bold = false, align = Layout.Alignment.ALIGN_NORMAL)
                s.printSpace(1)
                s.printText("RECEIVED BY:   ....................", size = 20, bold = false, align = Layout.Alignment.ALIGN_NORMAL)
                s.printDivider("-", 48)

                s.feedAndCut(5)
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing cash movement on DBL Z93: ${e.message}", e)
                onComplete(false, "DBL Z93 print error: ${e.message}")
            }
        }.start()
    }

    // ==========================================
    // 3. SHIFT SUMMARY REPORT
    // ==========================================
    fun printShiftReport(
        shiftData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!isPrinterReady()) {
                    onComplete(false, "DBL Z93 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z93 printer instance is null")
                val s = NativePrinterSession(p, context)

                val appName = (shiftData["appName"] as? String ?: "ONIMTA POS").uppercase()
                val title = ((shiftData["title"] as? String)?.takeIf { it.isNotEmpty() } ?: "SHIFT REPORT").uppercase()
                val dayNumber = (shiftData["dayNumber"] as? String)?.takeIf { it.isNotEmpty() } ?: ""
                val shiftNo = (shiftData["shiftNumber"] as? String)?.takeIf { it.isNotEmpty() }
                    ?: (shiftData["shiftNo"] as? String)?.takeIf { it.isNotEmpty() } ?: ""
                val cashier = ((shiftData["cashier"] as? String)?.takeIf { it.isNotEmpty() } ?: "ADMIN").uppercase()
                val dateTime = (shiftData["dateTime"] as? String)?.takeIf { it.isNotEmpty() }
                    ?: (shiftData["startTime"] as? String) ?: ""
                val openedAt = (shiftData["openedAt"] as? String)?.takeIf { it.isNotEmpty() } ?: ""
                val isEndReport = shiftData["isEndReport"] as? Boolean ?: false

                val openingFloat = (shiftData["openingBalance"] as? String)?.takeIf { it.isNotEmpty() }
                    ?: (shiftData["openingCash"] as? String)?.takeIf { it.isNotEmpty() }
                    ?: "LKR 0.00"

                s.printText(appName, size = 30, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText(title, size = 24, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 48)

                if (dayNumber.isNotEmpty()) s.printTwoCols("DAY #:", dayNumber, size = 22, bold = true)
                if (shiftNo.isNotEmpty()) s.printTwoCols("SHIFT #:", shiftNo, size = 22, bold = true)
                s.printTwoCols("CASHIER:", cashier, size = 22, bold = true)
                if (dateTime.isNotEmpty()) s.printTwoCols("DATE / TIME:", dateTime, size = 22, bold = true)
                if (openedAt.isNotEmpty()) s.printTwoCols("OPENED AT:", openedAt, size = 22, bold = true)
                s.printDivider("-", 48)

                if (!isEndReport) {
                    // START OF DAY OR START OF SHIFT
                    s.printTwoCols("STARTING FLOAT:", openingFloat, size = 26, bold = true)
                    s.printDivider("-", 48)
                } else {
                    // END OF SHIFT (Z-REPORT) OR END OF DAY
                    val totalInvoices = shiftData["totalInvoices"] as? String ?: "0"
                    val grossSales = shiftData["grossSales"] as? String ?: "LKR 0.00"
                    val discount = shiftData["discount"] as? String ?: "LKR 0.00"
                    val tax = shiftData["tax"] as? String ?: "LKR 0.00"
                    val netSales = shiftData["netSales"] as? String ?: "LKR 0.00"

                    val cashSales = shiftData["cashSales"] as? String ?: "LKR 0.00"
                    val nonCashSales = shiftData["nonCashSales"] as? String ?: "LKR 0.00"
                    val nonCashBreakdown = (shiftData["nonCashBreakdown"] as? Map<*, *>)?.mapNotNull { (k, v) ->
                        if (k != null && v != null) k.toString().uppercase() to v.toString() else null
                    }?.toMap() ?: emptyMap()
                    val cardSales = shiftData["cardSales"] as? String ?: "LKR 0.00"
                    val otherSales = shiftData["otherSales"] as? String ?: "LKR 0.00"

                    val paidIn = shiftData["paidIn"] as? String ?: "LKR 0.00"
                    val paidOut = shiftData["paidOut"] as? String ?: "LKR 0.00"
                    val expectedCash = shiftData["expectedCash"] as? String ?: "LKR 0.00"
                    val actualCash = shiftData["actualCash"] as? String ?: "LKR 0.00"
                    val difference = (shiftData["cashDiff"] as? String)?.takeIf { it.isNotEmpty() }
                        ?: (shiftData["difference"] as? String) ?: "LKR 0.00"

                    s.printTwoCols("OPENING FLOAT:", openingFloat, size = 22, bold = true)
                    s.printTwoCols("TOTAL INVOICES:", totalInvoices, size = 22, bold = true)
                    s.printTwoCols("GROSS SALES:", grossSales, size = 22, bold = true)
                    if (discount.isNotEmpty() && discount != "LKR 0.00" && discount != "0.00") {
                        s.printTwoCols("DISCOUNTS:", "-$discount", size = 22, bold = true)
                    }
                    if (tax.isNotEmpty() && tax != "LKR 0.00" && tax != "0.00") {
                        s.printTwoCols("TAX:", tax, size = 22, bold = true)
                    }
                    s.printTwoCols("NET SALES:", netSales, size = 25, bold = true)
                    s.printDivider("-", 48)

                    s.printTwoCols("CASH SALES:", cashSales, size = 22, bold = true)
                    s.printTwoCols("NON-CASH SALES:", nonCashSales, size = 22, bold = true)
                    if (nonCashBreakdown.isNotEmpty()) {
                        for ((method, amount) in nonCashBreakdown) {
                            s.printTwoCols("  • ${method.uppercase()}:", amount, size = 20, bold = true)
                        }
                    } else if (cardSales.isNotEmpty() && cardSales != "LKR 0.00" && cardSales != "0.00") {
                        s.printTwoCols("  • CARD SALES:", cardSales, size = 20, bold = true)
                    }
                    if (paidIn.isNotEmpty() && paidIn != "LKR 0.00" && paidIn != "0.00") {
                        s.printTwoCols("PAID IN (+):", paidIn, size = 22, bold = true)
                    }
                    if (paidOut.isNotEmpty() && paidOut != "LKR 0.00" && paidOut != "0.00") {
                        s.printTwoCols("PAID OUT (-):", paidOut, size = 22, bold = true)
                    }
                    s.printDivider("-", 48)

                    s.printTwoCols("EXPECTED CASH:", expectedCash, size = 24, bold = true)
                    s.printTwoCols("ACTUAL CASH COUNT:", actualCash, size = 24, bold = true)
                    s.printTwoCols("DIFFERENCE / VARIANCE:", difference, size = 24, bold = true)
                    s.printDivider("-", 48)
                }

                s.feedAndCut(5)
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing shift report on DBL Z93: ${e.message}", e)
                onComplete(false, "DBL Z93 print error: ${e.message}")
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
                    onComplete(false, "DBL Z93 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z93 printer instance is null")
                val s = NativePrinterSession(p, context)

                val appName = (exchangeData["appName"] as? String ?: "ONIMTA POS").uppercase()
                val voucherCode = (exchangeData["voucherCode"] as? String ?: "").uppercase()
                val totalAmount = exchangeData["totalAmount"] as? String ?: "LKR 0.00"
                val customerName = (exchangeData["customerName"] as? String ?: "WALK-IN CUSTOMER").uppercase()
                val cashierName = (exchangeData["cashierName"] as? String ?: "ADMIN").uppercase()
                val dateTime = exchangeData["dateTime"] as? String ?: ""
                val items = exchangeData["items"] as? List<Map<String, Any?>> ?: emptyList()

                s.printText(appName, size = 30, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("EXCHANGE VOUCHER / SLIP", size = 24, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 48)

                s.printTwoCols("VOUCHER #:", voucherCode, size = 24, bold = true)
                s.printTwoCols("DATE:", dateTime, size = 22, bold = false)
                s.printTwoCols("CASHIER:", cashierName, size = 22, bold = false)
                if (customerName.isNotEmpty() && customerName != "WALK-IN CUSTOMER") {
                    s.printTwoCols("CUSTOMER:", customerName, size = 22, bold = false)
                }
                s.printDivider("-", 48)

                s.printTwoCols("LN  PRODUCT", "PRICE  QTY   TOTAL", size = 22, bold = true)
                s.printDivider("-", 48)

                var ln = 1
                for (item in items) {
                    val desc = (item["description"] as? String ?: "").uppercase()
                    val qty = item["qty"] as? String ?: "1"
                    val price = item["price"] as? String ?: ""
                    val total = item["total"] as? String ?: ""
                    s.printText(String.format("%2d. %s", ln, desc), size = 23, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                    val priceQtyTotal = String.format("%10s %5s %12s", price, qty, total)
                    s.printText(priceQtyTotal, size = 22, bold = false, align = Layout.Alignment.ALIGN_OPPOSITE)
                    ln++
                }
                s.printDivider("-", 48)

                s.printTwoCols("TOTAL CREDIT VALUE:", totalAmount, size = 26, bold = true)
                s.printDivider("-", 48)

                if (voucherCode.isNotEmpty()) {
                    s.printBarCode(voucherCode, height = 120, width = 576)
                    s.printText("* $voucherCode *", size = 24, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                    s.printQrCode(voucherCode, size = 200)
                }

                s.printDivider("-", 48)
                s.printText("SCAN BARCODE OR QR CODE TO REDEEM", size = 20, bold = false, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("EXCHANGE CREDIT ON YOUR NEXT BILL.", size = 20, bold = false, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 48)

                s.feedAndCut(5)
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing exchange receipt on DBL Z93: ${e.message}", e)
                onComplete(false, "DBL Z93 print error: ${e.message}")
            }
        }.start()
    }

    // ==========================================
    // 5. RETURN NOTE / REFUND SLIP
    // ==========================================
    fun printReturnReceipt(
        returnData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!isPrinterReady()) {
                    onComplete(false, "DBL Z93 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z93 printer instance is null")
                val s = NativePrinterSession(p, context)

                val appName = (returnData["appName"] as? String ?: "ONIMTA POS").uppercase()
                val returnNo = (returnData["returnNo"] as? String ?: "").uppercase()
                val originalInvoice = (returnData["originalInvoiceNo"] as? String ?: "").uppercase()
                val customerName = (returnData["customerName"] as? String ?: "WALK-IN CUSTOMER").uppercase()
                val cashierName = (returnData["cashierName"] as? String ?: "ADMIN").uppercase()
                val dateTime = returnData["dateTime"] as? String ?: ""
                val refundAmount = returnData["refundAmount"] as? String ?: "LKR 0.00"
                val paymentMethod = (returnData["paymentMethod"] as? String ?: "CASH").uppercase()
                val items = returnData["items"] as? List<Map<String, Any?>> ?: emptyList()

                s.printText(appName, size = 30, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("RETURN NOTE / REFUND SLIP", size = 24, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 48)

                s.printTwoCols("RETURN #:", returnNo, size = 24, bold = true)
                if (originalInvoice.isNotEmpty()) s.printTwoCols("ORIGINAL INV #:", originalInvoice, size = 22, bold = false)
                s.printTwoCols("DATE:", dateTime, size = 22, bold = false)
                s.printTwoCols("CASHIER:", cashierName, size = 22, bold = false)
                if (customerName.isNotEmpty() && customerName != "WALK-IN CUSTOMER") {
                    s.printTwoCols("CUSTOMER:", customerName, size = 22, bold = false)
                }
                s.printDivider("-", 48)

                s.printTableHeader(size = 23, bold = true)
                s.printDivider("-", 48)

                var ln = 1
                for (item in items) {
                    val desc = (item["description"] as? String ?: "").uppercase()
                    val qty = item["qty"] as? String ?: "1"
                    val price = item["price"] as? String ?: ""
                    val total = item["total"] as? String ?: ""
                    s.printProductRow(ln, desc, size = 23, bold = true)
                    s.printItemValues(price, qty, total, size = 23, bold = true)
                    ln++
                }
                s.printDivider("-", 48)

                s.printTwoCols("REFUNDED VIA:", paymentMethod, size = 23, bold = true)
                s.printTwoCols("TOTAL REFUNDED (LKR):", s.cleanAmount(refundAmount), size = 32, bold = true)
                s.printDivider("-", 48)

                s.printSpace(1)
                s.printText("CASHIER SIGN: ....................", size = 20, bold = false, align = Layout.Alignment.ALIGN_NORMAL)
                s.printSpace(1)
                s.printText("CUSTOMER SIGN: ....................", size = 20, bold = false, align = Layout.Alignment.ALIGN_NORMAL)
                s.printDivider("-", 48)

                s.feedAndCut(5)
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing return receipt on DBL Z93: ${e.message}", e)
                onComplete(false, "DBL Z93 print error: ${e.message}")
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
                    onComplete(false, "DBL Z93 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z93 printer instance is null")
                val s = NativePrinterSession(p, context)

                val appName = (holdData["appName"] as? String ?: "ONIMTA POS").uppercase()
                val holdNo = (holdData["holdNo"] as? String ?: "").uppercase()
                val totalAmount = holdData["totalAmount"] as? String ?: "LKR 0.00"
                val totalItems = ((holdData["totalItems"] as? String) ?: "").uppercase()
                val customerName = ((holdData["customerName"] as? String) ?: (holdData["customer"] as? String) ?: "WALK-IN CUSTOMER").uppercase()
                val cashierName = ((holdData["cashierName"] as? String) ?: (holdData["cashier"] as? String) ?: "ADMIN").uppercase()
                val dateTime = holdData["dateTime"] as? String ?: ""
                val items = holdData["items"] as? List<Map<String, Any?>> ?: emptyList()

                s.printText(appName, size = 30, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("*** HELD BILL RECEIPT ***", size = 24, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 48)

                s.printTwoCols("HOLD BILL #:", holdNo, size = 24, bold = true)
                if (dateTime.isNotEmpty()) s.printTwoCols("DATE:", dateTime, size = 22, bold = false)
                s.printTwoCols("CASHIER:", cashierName, size = 22, bold = false)
                if (customerName.isNotEmpty() && customerName != "WALK-IN CUSTOMER") {
                    s.printTwoCols("CUSTOMER:", customerName, size = 22, bold = false)
                }
                s.printDivider("-", 48)

                if (items.isNotEmpty()) {
                    s.printText("HELD ITEMS", size = 22, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                    for (item in items) {
                        val desc = (item["description"] as? String ?: "").uppercase()
                        val qty = item["qty"] as? String ?: "1"
                        val price = item["price"] as? String ?: ""
                        val total = item["total"] as? String ?: ""
                        val cleanPrice = s.cleanAmount(price)
                        val cleanTotal = s.cleanAmount(total)
                        s.printText(desc, size = 24, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                        s.printTwoCols("  $qty x $cleanPrice", cleanTotal, size = 22, bold = false)
                    }
                    s.printDivider("-", 48)
                }

                if (totalItems.isNotEmpty()) {
                    s.printTwoCols("TOTAL ITEMS:", totalItems, size = 24, bold = true)
                }
                s.printTwoCols("HELD AMOUNT:", totalAmount, size = 28, bold = true)
                s.printDivider("-", 48)

                if (holdNo.isNotEmpty()) {
                    s.printBarCode(holdNo, height = 120, width = 576)
                    s.printText("* $holdNo *", size = 24, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                    s.printQrCode(holdNo, size = 200)
                    s.printDivider("-", 48)
                    s.printText("SCAN BARCODE OR QR CODE TO RECALL", size = 20, bold = false, align = Layout.Alignment.ALIGN_CENTER)
                    s.printText("HELD BILL TO CURRENT CART.", size = 20, bold = false, align = Layout.Alignment.ALIGN_CENTER)
                    s.printDivider("-", 48)
                }

                s.feedAndCut(5)
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing hold receipt on DBL Z93: ${e.message}", e)
                onComplete(false, "DBL Z93 print error: ${e.message}")
            }
        }.start()
    }

    // ==========================================
    // 7. ITEM-WISE SALES REPORT (80mm)
    // ==========================================
    fun printItemWiseSalesReport(
        reportData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!isPrinterReady()) {
                    onComplete(false, "DBL Z93 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z93 printer instance is null")
                val s = NativePrinterSession(p, context)

                val appName = (reportData["appName"] as? String ?: "ONIMTA POS").uppercase()
                val title = ((reportData["title"] as? String) ?: "ITEM WISE SALES").uppercase()
                val period = ((reportData["period"] as? String) ?: "Today").uppercase()
                val cashier = (((reportData["cashierName"] as? String) ?: (reportData["cashier"] as? String) ?: "Admin")).uppercase()
                val dateTime = reportData["dateTime"] as? String ?: ""
                val totalQty = (reportData["totalQuantity"] as? String) ?: (reportData["totalQty"] as? String) ?: "0"
                val totalRevenue = reportData["totalRevenue"] as? String ?: "LKR 0.00"
                val items = reportData["items"] as? List<Map<String, Any?>> ?: emptyList()

                s.printText(appName, size = 30, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText(title, size = 24, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 48)

                s.printTwoCols("PERIOD:", period, size = 22, bold = false)
                s.printTwoCols("CASHIER:", cashier, size = 22, bold = false)
                if (dateTime.isNotEmpty()) {
                    s.printTwoCols("DATE:", dateTime, size = 22, bold = false)
                }
                s.printDivider("-", 48)

                s.printText("ITEM DESCRIPTION", size = 22, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                s.printTwoCols("  SOLD QTY", "TOTAL AMOUNT", size = 22, bold = true)
                s.printDivider("-", 48)

                var rank = 1
                for (item in items) {
                    val desc = (item["description"] as? String ?: "").uppercase()
                    val qty = (item["qty"] as? String) ?: (item["quantity"] as? String) ?: "0"
                    val total = (item["total"] as? String) ?: (item["amount"] as? String) ?: "LKR 0.00"
                    s.printText("$rank. $desc", size = 24, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                    s.printTwoCols("   Qty: $qty", total, size = 22, bold = false)
                    rank++
                }

                s.printDivider("-", 48)
                s.printTwoCols("TOTAL ITEMS SOLD:", totalQty, size = 24, bold = true)
                s.printTwoCols("TOTAL REVENUE:", totalRevenue, size = 28, bold = true)
                s.printDivider("-", 48)

                s.feedAndCut(5)
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing item-wise report on DBL Z93: ${e.message}", e)
                onComplete(false, "DBL Z93 print error: ${e.message}")
            }
        }.start()
    }

    // ==========================================
    // 8. TOTAL SALES REPORT (80mm)
    // ==========================================
    fun printTotalSalesReport(
        reportData: Map<String, Any?>,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!isPrinterReady()) {
                    onComplete(false, "DBL Z93 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z93 printer instance is null")
                val s = NativePrinterSession(p, context)

                val appName = (reportData["appName"] as? String ?: "ONIMTA POS").uppercase()
                val title = ((reportData["title"] as? String) ?: "TOTAL SALES REPORT").uppercase()
                val period = ((reportData["period"] as? String) ?: "Today").uppercase()
                val cashier = (((reportData["cashierName"] as? String) ?: (reportData["cashier"] as? String) ?: "Admin")).uppercase()
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
                val nonCashSales = reportData["nonCashSales"] as? String ?: "LKR 0.00"
                val nonCashBreakdown = (reportData["nonCashBreakdown"] as? Map<*, *>)?.mapNotNull { (k, v) ->
                    if (k != null && v != null) k.toString().uppercase() to v.toString() else null
                }?.toMap() ?: emptyMap()
                val cardSales = reportData["cardSales"] as? String ?: "LKR 0.00"
                val qrSales = reportData["qrSales"] as? String ?: "LKR 0.00"
                val creditSales = reportData["creditSales"] as? String ?: "LKR 0.00"

                s.printText(appName, size = 30, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText(title, size = 24, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 48)

                s.printTwoCols("PERIOD:", period, size = 22, bold = true)
                s.printTwoCols("CASHIER:", cashier, size = 22, bold = true)
                if (dateTime.isNotEmpty()) {
                    s.printTwoCols("DATE:", dateTime, size = 22, bold = true)
                }
                s.printDivider("-", 48)

                s.printText("SALES SUMMARY", size = 23, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                s.printTwoCols("TOTAL INVOICES:", totalInvoices, size = 22, bold = true)
                s.printTwoCols("GROSS SALES:", grossSales, size = 22, bold = true)
                if (discount.isNotEmpty() && discount != "LKR 0.00" && discount != "0.00") {
                    s.printTwoCols("DISCOUNTS:", "-$discount", size = 22, bold = true)
                }
                if (tax.isNotEmpty() && tax != "LKR 0.00" && tax != "0.00") {
                    s.printTwoCols("TAX:", tax, size = 22, bold = true)
                }
                s.printTwoCols("NET SALES:", netSales, size = 25, bold = true)
                if (returnsCount != "0" && returnsCount.isNotEmpty()) {
                    s.printTwoCols("RETURNS ($returnsCount bills):", "-$returnsAmount", size = 22, bold = true)
                }
                s.printDivider("-", 48)
                s.printTwoCols("TOTAL NET REVENUE:", totalNetRevenue, size = 26, bold = true)
                s.printDivider("-", 48)

                s.printText("PAYMENTS / TENDER BREAKDOWN", size = 23, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                s.printTwoCols("CASH SALES:", cashSales, size = 22, bold = true)
                s.printTwoCols("NON-CASH SALES:", nonCashSales, size = 22, bold = true)
                if (nonCashBreakdown.isNotEmpty()) {
                    for ((method, amount) in nonCashBreakdown) {
                        s.printTwoCols("  • ${method.uppercase()}:", amount, size = 20, bold = true)
                    }
                } else {
                    if (cardSales != "LKR 0.00" && cardSales.isNotEmpty()) {
                        s.printTwoCols("  • CARD SALES:", cardSales, size = 20, bold = true)
                    }
                    if (qrSales != "LKR 0.00" && qrSales.isNotEmpty()) {
                        s.printTwoCols("  • QR / ONLINE:", qrSales, size = 20, bold = true)
                    }
                    if (creditSales != "LKR 0.00" && creditSales.isNotEmpty()) {
                        s.printTwoCols("  • CREDIT SALES:", creditSales, size = 20, bold = true)
                    }
                }
                s.printDivider("-", 48)

                s.feedAndCut(5)
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing total sales report on DBL Z93: ${e.message}", e)
                onComplete(false, "DBL Z93 print error: ${e.message}")
            }
        }.start()
    }

    // ==========================================
    // 9. FONT TEST PRINT (80mm)
    // ==========================================
    fun printFontTest(
        fontName: String,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!isPrinterReady()) {
                    onComplete(false, "DBL Z93 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z93 printer instance is null")
                activeFont = fontName
                val s = NativePrinterSession(p, context, fontName)

                s.printText("ONIMTA POS - FONT TEST (80MM)", size = 28, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("STYLE: ${fontName.uppercase()}", size = 22, bold = false, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 48)
                s.printText("The quick brown fox jumps over the lazy dog.", size = 22, bold = false)
                s.printText("0123456789 - LKR 1,250.00", size = 24, bold = true)
                s.printDivider("-", 48)
                s.printTwoCols("1. SAMPLE PRODUCT ITEM", "LKR 450.00", size = 22, bold = false)
                s.printTwoCols("2. ANOTHER RETAIL ITEM", "LKR 800.00", size = 22, bold = false)
                s.printDivider("=", 48)
                s.printTwoCols("TOTAL TEST AMOUNT:", "LKR 1,250.00", size = 24, bold = true)
                s.printDivider("=", 48)
                s.printText("80MM FONT APPLIED SUCCESSFULLY!", size = 22, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.feedAndCut(5)
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing font test on DBL Z93: ${e.message}", e)
                onComplete(false, "DBL Z93 print error: ${e.message}")
            }
        }.start()
    }
}
