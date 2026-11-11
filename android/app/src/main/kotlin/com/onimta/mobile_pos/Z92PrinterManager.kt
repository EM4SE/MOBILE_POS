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
    companion object {
        const val PAPER_WIDTH = 384 // 58mm thermal paper = 384 dots
    }

    private val TAG = "Z92PrinterManager"

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

                val leftX = 6f
                val rightX = (PAPER_WIDTH - 6).toFloat()

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
                Log.w("Z92Printer", "printText error: ${e.message}")
            }
        }

        fun printTwoCols(
            left: String,
            right: String,
            size: Int = 20,
            bold: Boolean = false,
            indent: Float = 6f
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
                val rightX = (PAPER_WIDTH - 6).toFloat()

                if (leftWidth + rightWidth + 12f <= (PAPER_WIDTH - (indent + 6f))) {
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
            size: Int = 20,
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

                val leftX = 6f
                val productX = 42f
                val priceX = 220f
                val qtyCenterX = 270f
                val totalX = (PAPER_WIDTH - 6).toFloat()

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
                Log.w("Z92Printer", "printTableHeader error: ${e.message}")
            }
        }

        fun printProductRow(
            ln: Int,
            desc: String,
            size: Int = 20,
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

                val leftX = 6f
                val productX = 42f
                val maxTextWidth = (PAPER_WIDTH - 6) - productX

                val descLines = wrapText(desc, maxTextWidth, paint)
                if (descLines.isEmpty()) {
                    return
                }

                val totalHeight = (descLines.size * lineHeight) + (paddingY * 2)
                val bmp = Bitmap.createBitmap(PAPER_WIDTH, totalHeight, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bmp)
                canvas.drawColor(Color.WHITE)

                paint.textAlign = Paint.Align.LEFT
                // Line number only on line 1, matching "LN" header at leftX
                canvas.drawText(String.format("%2d.", ln), leftX, baseline + paddingY, paint)

                // Every line of description starts strictly at productX under "PRODUCT" column
                for (i in descLines.indices) {
                    val y = baseline + paddingY + (i * lineHeight)
                    canvas.drawText(descLines[i], productX, y, paint)
                }

                p.setPrintAppendBitmap(bmp, Layout.Alignment.ALIGN_NORMAL, PAPER_WIDTH)
            } catch (e: Throwable) {
                Log.w("Z92Printer", "printProductRow error: ${e.message}")
            }
        }

        fun printItemValues(
            price: String,
            qty: String,
            total: String,
            size: Int = 20,
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

                val priceX = 220f
                val qtyCenterX = 270f
                val totalX = (PAPER_WIDTH - 6).toFloat()

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
                Log.w("Z92Printer", "printItemValues error: ${e.message}")
            }
        }

        fun printItemCols(
            col1: String,
            col2: String,
            col3: String,
            col4: String,
            size: Int = 20,
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

                    val leftX = 6f
                    val priceX = 220f
                    val qtyCenterX = 270f
                    val totalX = (PAPER_WIDTH - 6).toFloat()

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
                    Log.w("Z92Printer", "printItemCols error: ${e.message}")
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

        fun printDivider(lineChar: String = "-", totalChars: Int = 32) {
            try {
                val h = 18
                val bmp = Bitmap.createBitmap(PAPER_WIDTH, h, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bmp)
                canvas.drawColor(Color.WHITE)
                val paint = Paint().apply {
                    color = Color.BLACK
                    style = Paint.Style.STROKE
                    strokeWidth = if (lineChar == "=") 3.0f else 3.5f
                    isAntiAlias = false
                }
                val leftX = 6f
                val rightX = (PAPER_WIDTH - 6).toFloat()
                val y = h / 2f
                if (lineChar == "=") {
                    canvas.drawLine(leftX, y - 3.5f, rightX, y - 3.5f, paint)
                    canvas.drawLine(leftX, y + 3.5f, rightX, y + 3.5f, paint)
                } else {
                    canvas.drawLine(leftX, y, rightX, y, paint)
                }
                p.setPrintAppendBitmap(bmp, Layout.Alignment.ALIGN_NORMAL, PAPER_WIDTH)
            } catch (e: Throwable) {
                Log.w("Z92Printer", "printDivider error: ${e.message}")
            }
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

        private fun calculateBigStoreNameSize(text: String, maxWidth: Int, max: Int = 46, min: Int = 28): Int {
            val paint = Paint().apply {
                typeface = getTypeface(true)
                isFakeBoldText = true
            }
            for (s in max downTo min step 2) {
                paint.textSize = s.toFloat()
                if (paint.measureText(text) <= maxWidth) {
                    return s
                }
            }
            return min
        }

        fun printReceiptHeader(
            data: Map<String, Any?>,
            title: String,
            dividerCount: Int = 32
        ) {
            val storeNameRaw = (data["storeName"] as? String)?.trim()?.takeIf { it.isNotEmpty() }
                ?: (data["appName"] as? String)?.trim()?.takeIf { it.isNotEmpty() }
                ?: "ONIMTA POS"
            val storeAddress = (data["storeAddress"] as? String)?.trim() ?: ""
            val storePhone = (data["storePhone"] as? String)?.trim() ?: ""

            val normalizedStoreName = storeNameRaw.replace("\\n", "\n")
            val nameLines = normalizedStoreName.split("\n").map { it.trim() }.filter { it.isNotEmpty() }

            if (nameLines.isNotEmpty()) {
                val firstLine = nameLines[0].uppercase()
                val bigSize = calculateBigStoreNameSize(firstLine, PAPER_WIDTH - 20, max = 46, min = 28)
                printText(firstLine, size = bigSize, bold = true, align = Layout.Alignment.ALIGN_CENTER)

                for (i in 1 until nameLines.size) {
                    printText(nameLines[i].uppercase(), size = 22, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                }
            }

            if (storeAddress.isNotEmpty()) {
                val normalizedAddr = storeAddress.replace("\\n", "\n")
                val addrLines = normalizedAddr.split("\n").map { it.trim() }.filter { it.isNotEmpty() }
                for (addrLine in addrLines) {
                    val wrapped = wrapText(addrLine, 32)
                    for (wl in wrapped) {
                        printText(wl, size = 20, bold = false, align = Layout.Alignment.ALIGN_CENTER)
                    }
                }
            }

            if (storePhone.isNotEmpty()) {
                val phoneText = if (storePhone.uppercase().startsWith("TEL") || storePhone.uppercase().startsWith("PHONE")) {
                    storePhone
                } else {
                    "TEL: $storePhone"
                }
                printText(phoneText, size = 20, bold = false, align = Layout.Alignment.ALIGN_CENTER)
            }

            if (title.isNotEmpty()) {
                printText(title, size = 22, bold = true, align = Layout.Alignment.ALIGN_CENTER)
            }
            printDivider("-", dividerCount)
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

                // 1. Header
                s.printReceiptHeader(receiptData, "ORDER INVOICE", 32)

                // 2. Invoice Info
                s.printTwoCols("INVOICE #:", invoiceNo, size = 22, bold = true)
                if (dateStr.isNotEmpty()) s.printTwoCols("DATE:", dateStr, size = 20, bold = false)
                s.printTwoCols("CASHIER:", cashierName, size = 20, bold = false)
                s.printTwoCols("CUSTOMER:", customerName, size = 20, bold = false)
                s.printDivider("-", 32)

                // 3. Items List
                s.printTableHeader(size = 20, bold = true)
                s.printDivider("-", 32)

                var ln = 1
                for (item in items) {
                    val desc = (item["description"] as? String ?: "").uppercase()
                    val qty = item["qty"] as? String ?: "1"
                    val price = item["price"] as? String ?: ""
                    val itemDisc = item["discount"] as? String ?: ""
                    val total = item["total"] as? String ?: ""

                    s.printProductRow(ln, desc, size = 20, bold = true)
                    s.printItemValues(price, qty, total, size = 20, bold = true)
                    if (itemDisc.isNotEmpty() && itemDisc != "LKR 0.00" && itemDisc != "0.00") {
                        val cleanDisc = s.cleanAmount(itemDisc)
                        s.printTwoCols("    ITEM DISC:", "-$cleanDisc", size = 18, bold = false)
                    }
                    ln++
                }
                s.printDivider("-", 32)

                // 4. Financial Summary
                s.printTwoCols("SUBTOTAL:", s.cleanAmount(subtotal), size = 20, bold = false)
                if (discount.isNotEmpty() && discount != "LKR 0.00" && discount != "0.00") {
                    s.printTwoCols("DISCOUNT:", "-${s.cleanAmount(discount)}", size = 20, bold = false)
                }
                if (exchangeCredit.isNotEmpty() && exchangeCredit != "LKR 0.00" && exchangeCredit != "0.00") {
                    s.printTwoCols("EXCHANGE CREDIT:", "-${s.cleanAmount(exchangeCredit)}", size = 20, bold = false)
                }
                if (tax.isNotEmpty() && tax != "LKR 0.00" && tax != "0.00") {
                    s.printTwoCols("TAX:", s.cleanAmount(tax), size = 20, bold = false)
                }
                s.printDivider("=", 32)
                s.printTwoCols("GRAND TOTAL (LKR):", s.cleanAmount(grandTotal), size = 26, bold = true)
                s.printDivider("=", 32)

                // 5. Payments Breakdown
                if (payments.isNotEmpty()) {
                    s.printTwoCols("PAYMENTS:", "", size = 20, bold = true)
                    for (pay in payments) {
                        val method = (pay["method"] as? String ?: "PAYMENT").uppercase()
                        val amt = pay["amount"] as? String ?: ""
                        s.printTwoCols("  $method", s.cleanAmount(amt), size = 19, bold = false, indent = 16f)
                    }
                }
                if (totalPaid.isNotEmpty()) s.printTwoCols("TOTAL PAID:", s.cleanAmount(totalPaid), size = 20, bold = true)
                if (change.isNotEmpty() && change != "LKR 0.00" && change != "0.00") {
                    s.printTwoCols("CHANGE RETURNED:", s.cleanAmount(change), size = 20, bold = true)
                }
                s.printDivider("-", 32)

                // 6. Footer & Clear paper feed
                s.printText("THANK YOU FOR SHOPPING WITH US!", size = 20, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("PLEASE COME AGAIN", size = 18, bold = false, align = Layout.Alignment.ALIGN_CENTER)

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

                val appName = (movementData["appName"] as? String ?: "ONIMTA POS").uppercase()
                val type = (movementData["type"] as? String ?: "PAID IN").uppercase()
                val amount = movementData["amount"] as? String ?: "LKR 0.00"
                val reason = (movementData["reason"] as? String ?: "CASH MOVEMENT").uppercase()
                val cashier = (movementData["cashier"] as? String ?: "ADMIN").uppercase()
                val dateStr = movementData["dateTime"] as? String ?: ""

                s.printReceiptHeader(movementData, "*** $type RECEIPT ***", 32)

                if (dateStr.isNotEmpty()) s.printTwoCols("DATE:", dateStr, size = 20, bold = false)
                s.printTwoCols("CASHIER:", cashier, size = 20, bold = false)
                s.printTwoCols("TYPE:", type, size = 22, bold = true)
                s.printText("REASON / REMARK:", size = 20, bold = false, align = Layout.Alignment.ALIGN_NORMAL)
                s.printText("  $reason", size = 22, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                s.printDivider("-", 32)

                s.printTwoCols("TOTAL $type:", amount, size = 24, bold = true)
                s.printDivider("-", 32)
                s.printSpace(1)
                s.printText("CASHIER SIGNATURE: _____________", size = 20, bold = false, align = Layout.Alignment.ALIGN_NORMAL)
                s.printSpace(1)
                s.printText("APPROVED BY:       _____________", size = 20, bold = false, align = Layout.Alignment.ALIGN_NORMAL)
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

                val appName = (reportData["appName"] as? String ?: "ONIMTA POS").uppercase()
                val title = ((reportData["title"] as? String) ?: "SHIFT REPORT").uppercase()
                val dayNumber = reportData["dayNumber"] as? String ?: "1"
                val shiftNumber = reportData["shiftNumber"] as? String ?: "1"
                val cashier = ((reportData["cashier"] as? String) ?: "ADMIN").uppercase()
                val dateTime = reportData["dateTime"] as? String ?: ""
                val openedAt = reportData["openedAt"] as? String ?: ""
                val isEndReport = reportData["isEndReport"] as? Boolean ?: false

                s.printReceiptHeader(reportData, title, 32)

                s.printTwoCols("DAY #:", dayNumber, size = 20, bold = true)
                s.printTwoCols("SHIFT #:", shiftNumber, size = 20, bold = true)
                s.printTwoCols("CASHIER:", cashier, size = 20, bold = true)
                if (dateTime.isNotEmpty()) s.printTwoCols("DATE / TIME:", dateTime, size = 20, bold = true)
                if (openedAt.isNotEmpty()) s.printTwoCols("OPENED AT:", openedAt, size = 20, bold = true)
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

                    s.printText("SALES SUMMARY", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                    s.printTwoCols("TOTAL INVOICES:", totalInvoices, size = 20, bold = true)
                    s.printTwoCols("GROSS SALES:", grossSales, size = 20, bold = true)
                    if (discount.isNotEmpty() && discount != "LKR 0.00") {
                        s.printTwoCols("DISCOUNTS:", "-$discount", size = 20, bold = true)
                    }
                    if (tax.isNotEmpty() && tax != "LKR 0.00") {
                        s.printTwoCols("TAX:", tax, size = 20, bold = true)
                    }
                    s.printTwoCols("NET SALES:", netSales, size = 22, bold = true)
                    s.printDivider("-", 32)

                    s.printText("PAYMENTS BREAKDOWN", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                    s.printTwoCols("CASH SALES:", cashSales, size = 20, bold = true)
                    s.printTwoCols("NON-CASH SALES:", nonCashSales, size = 20, bold = true)
                    if (nonCashBreakdown.isNotEmpty()) {
                        for ((method, amount) in nonCashBreakdown) {
                            s.printTwoCols("  • ${method.uppercase()}:", amount, size = 18, bold = true)
                        }
                    } else if (cardSales.isNotEmpty() && cardSales != "LKR 0.00") {
                        s.printTwoCols("  • CARD SALES:", cardSales, size = 18, bold = true)
                    }
                    s.printDivider("-", 32)

                    s.printText("DRAWER RECONCILIATION", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                    s.printTwoCols("OPENING BALANCE:", openingBalance, size = 20, bold = true)
                    s.printTwoCols("+ CASH SALES:", cashSales, size = 20, bold = true)
                    if (paidIn != "LKR 0.00" && paidIn.isNotEmpty()) {
                        s.printTwoCols("+ PAID IN (ENTRY):", paidIn, size = 20, bold = true)
                    }
                    if (paidOut != "LKR 0.00" && paidOut.isNotEmpty()) {
                        s.printTwoCols("- PAID OUT (EXPENSE):", "-$paidOut", size = 20, bold = true)
                    }
                    s.printDivider("-", 32)
                    s.printTwoCols("EXPECTED CASH:", expectedCash, size = 22, bold = true)
                    s.printTwoCols("ACTUAL CASH IN HAND:", actualCash, size = 22, bold = true)
                    s.printTwoCols("OVER / SHORT:", cashDiff, 22, bold = true)
                }

                s.printDivider("-", 32)
                s.printSpace(1)
                s.printText("CASHIER SIGNATURE: _____________", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                s.printSpace(1)
                s.printText("MANAGER SIGNATURE: _____________", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
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

                val appName = (exchangeData["appName"] as? String ?: "ONIMTA POS").uppercase()
                val voucherCode = (exchangeData["voucherCode"] as? String ?: "").uppercase()
                val totalAmount = exchangeData["totalAmount"] as? String ?: "LKR 0.00"
                val customerName = (exchangeData["customerName"] as? String ?: "WALK-IN CUSTOMER").uppercase()
                val cashierName = (exchangeData["cashierName"] as? String ?: "ADMIN").uppercase()
                val dateTime = exchangeData["dateTime"] as? String ?: ""
                val items = exchangeData["items"] as? List<Map<String, Any?>> ?: emptyList()

                s.printReceiptHeader(exchangeData, "EXCHANGE VOUCHER / SLIP", 32)

                s.printTwoCols("VOUCHER #:", voucherCode, size = 24, bold = true)
                s.printTwoCols("DATE:", dateTime, size = 20, bold = false)
                s.printTwoCols("CASHIER:", cashierName, size = 20, bold = false)
                if (customerName.isNotEmpty() && customerName != "WALK-IN CUSTOMER") {
                    s.printTwoCols("CUSTOMER:", customerName, size = 20, bold = false)
                }
                s.printDivider("-", 32)

                s.printTwoCols("LN  PRODUCT", "PRICE QTY TOTAL", size = 19, bold = true)
                s.printDivider("-", 32)

                var ln = 1
                for (item in items) {
                    val desc = (item["description"] as? String ?: "").uppercase()
                    val qty = item["qty"] as? String ?: "1"
                    val price = item["price"] as? String ?: ""
                    val total = item["total"] as? String ?: ""
                    s.printText(String.format("%2d. %s", ln, desc), size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                    val priceQtyTotal = String.format("%9s %4s %9s", price, qty, total)
                    s.printText(priceQtyTotal, size = 19, bold = false, align = Layout.Alignment.ALIGN_OPPOSITE)
                    ln++
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
                s.printText("SCAN BARCODE OR QR CODE TO REDEEM", size = 18, bold = false, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("EXCHANGE CREDIT ON YOUR NEXT BILL.", size = 18, bold = false, align = Layout.Alignment.ALIGN_CENTER)
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

                val appName = (returnData["appName"] as? String ?: "ONIMTA POS").uppercase()
                val returnNo = (returnData["returnNo"] as? String ?: "").uppercase()
                val refundAmount = returnData["refundAmount"] as? String ?: "LKR 0.00"
                val paymentMethod = (returnData["paymentMethod"] as? String ?: "CASH").uppercase()
                val reason = (returnData["reason"] as? String ?: "CUSTOMER RETURN").uppercase()
                val customerName = (returnData["customerName"] as? String ?: "WALK-IN CUSTOMER").uppercase()
                val cashierName = (returnData["cashierName"] as? String ?: "ADMIN").uppercase()
                val dateTime = returnData["dateTime"] as? String ?: ""
                val items = returnData["items"] as? List<Map<String, Any?>> ?: emptyList()

                s.printReceiptHeader(returnData, "RETURN / REFUND RECEIPT", 32)

                s.printTwoCols("RETURN REF #:", returnNo, size = 22, bold = true)
                s.printTwoCols("DATE:", dateTime, size = 20, bold = false)
                s.printTwoCols("CASHIER:", cashierName, size = 20, bold = false)
                if (customerName.isNotEmpty() && customerName != "WALK-IN CUSTOMER") {
                    s.printTwoCols("CUSTOMER:", customerName, size = 20, bold = false)
                }
                s.printTwoCols("REASON:", reason, size = 20, bold = false)
                s.printDivider("-", 32)

                s.printTableHeader(size = 20, bold = true)
                s.printDivider("-", 32)

                var ln = 1
                for (item in items) {
                    val desc = (item["description"] as? String ?: "").uppercase()
                    val qty = item["qty"] as? String ?: "1"
                    val price = item["price"] as? String ?: ""
                    val total = item["total"] as? String ?: ""
                    s.printProductRow(ln, desc, size = 20, bold = true)
                    s.printItemValues(price, qty, total, size = 20, bold = true)
                    ln++
                }
                s.printDivider("-", 32)

                s.printTwoCols("REFUNDED VIA:", paymentMethod, size = 20, bold = true)
                s.printTwoCols("TOTAL REFUNDED (LKR):", s.cleanAmount(refundAmount), size = 26, bold = true)
                s.printDivider("-", 32)

                s.printSpace(1)
                s.printText("CASHIER SIGN: _____________", size = 20, bold = false, align = Layout.Alignment.ALIGN_NORMAL)
                s.printSpace(1)
                s.printText("CUSTOMER SIGN: ____________", size = 20, bold = false, align = Layout.Alignment.ALIGN_NORMAL)
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

                val holdNo = (holdData["holdNo"] as? String ?: "").uppercase()
                val totalAmount = holdData["totalAmount"] as? String ?: "LKR 0.00"
                val totalItems = ((holdData["totalItems"] as? String) ?: "").uppercase()
                val customerName = ((holdData["customerName"] as? String) ?: (holdData["customer"] as? String) ?: "WALK-IN CUSTOMER").uppercase()
                val cashierName = ((holdData["cashierName"] as? String) ?: (holdData["cashier"] as? String) ?: "ADMIN").uppercase()
                val dateTime = holdData["dateTime"] as? String ?: ""
                val items = holdData["items"] as? List<Map<String, Any?>> ?: emptyList()

                s.printReceiptHeader(holdData, "*** HELD BILL RECEIPT ***", 32)

                s.printTwoCols("HOLD BILL #:", holdNo, size = 24, bold = true)
                if (dateTime.isNotEmpty()) s.printTwoCols("DATE:", dateTime, size = 20, bold = false)
                s.printTwoCols("CASHIER:", cashierName, size = 20, bold = false)
                if (customerName.isNotEmpty() && customerName != "WALK-IN CUSTOMER") {
                    s.printTwoCols("CUSTOMER:", customerName, size = 20, bold = false)
                }
                s.printDivider("-", 32)

                if (items.isNotEmpty()) {
                    s.printText("HELD ITEMS", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                    for (item in items) {
                        val desc = (item["description"] as? String ?: "").uppercase()
                        val qty = item["qty"] as? String ?: "1"
                        val price = item["price"] as? String ?: ""
                        val total = item["total"] as? String ?: ""
                        val cleanPrice = s.cleanAmount(price)
                        val cleanTotal = s.cleanAmount(total)
                        s.printText(desc, size = 22, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                        s.printTwoCols("  $qty x $cleanPrice", cleanTotal, size = 20, bold = false)
                    }
                    s.printDivider("-", 32)
                }

                if (totalItems.isNotEmpty()) {
                    s.printTwoCols("TOTAL ITEMS:", totalItems, size = 22, bold = true)
                }
                s.printTwoCols("HELD AMOUNT:", totalAmount, size = 26, bold = true)
                s.printDivider("-", 32)

                if (holdNo.isNotEmpty()) {
                    s.printBarCode(holdNo, height = 110, width = 384)
                    s.printText("* $holdNo *", size = 22, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                    s.printQrCode(holdNo, size = 180)
                    s.printDivider("-", 32)
                    s.printText("SCAN BARCODE OR QR CODE TO RECALL", size = 18, bold = false, align = Layout.Alignment.ALIGN_CENTER)
                    s.printText("HELD BILL TO CURRENT CART.", size = 18, bold = false, align = Layout.Alignment.ALIGN_CENTER)
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

                val appName = (reportData["appName"] as? String ?: "ONIMTA POS").uppercase()
                val title = ((reportData["title"] as? String) ?: "ITEM WISE SALES").uppercase()
                val period = ((reportData["period"] as? String) ?: "Today").uppercase()
                val cashier = (((reportData["cashierName"] as? String) ?: (reportData["cashier"] as? String) ?: "Admin")).uppercase()
                val dateTime = reportData["dateTime"] as? String ?: ""
                val totalQty = (reportData["totalQuantity"] as? String) ?: (reportData["totalQty"] as? String) ?: "0"
                val totalRevenue = reportData["totalRevenue"] as? String ?: "LKR 0.00"
                val items = reportData["items"] as? List<Map<String, Any?>> ?: emptyList()

                s.printReceiptHeader(reportData, title, 32)

                s.printTwoCols("PERIOD:", period, size = 20, bold = false)
                s.printTwoCols("CASHIER:", cashier, size = 20, bold = false)
                if (dateTime.isNotEmpty()) {
                    s.printTwoCols("DATE:", dateTime, size = 20, bold = false)
                }
                s.printDivider("-", 32)

                s.printText("ITEM DESCRIPTION", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                s.printTwoCols("  SOLD QTY", "TOTAL AMOUNT", size = 20, bold = true)
                s.printDivider("-", 32)

                var rank = 1
                for (item in items) {
                    val desc = (item["description"] as? String ?: "").uppercase()
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

                s.printReceiptHeader(reportData, title, 32)

                s.printTwoCols("PERIOD:", period, size = 20, bold = true)
                s.printTwoCols("CASHIER:", cashier, size = 20, bold = true)
                if (dateTime.isNotEmpty()) {
                    s.printTwoCols("DATE:", dateTime, size = 20, bold = true)
                }
                s.printDivider("-", 32)

                s.printText("SALES SUMMARY", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                s.printTwoCols("TOTAL INVOICES:", totalInvoices, size = 20, bold = true)
                s.printTwoCols("GROSS SALES:", grossSales, size = 20, bold = true)
                if (discount.isNotEmpty() && discount != "LKR 0.00" && discount != "0.00") {
                    s.printTwoCols("DISCOUNTS:", "-$discount", size = 20, bold = true)
                }
                if (tax.isNotEmpty() && tax != "LKR 0.00" && tax != "0.00") {
                    s.printTwoCols("TAX:", tax, size = 20, bold = true)
                }
                s.printTwoCols("NET SALES:", netSales, size = 22, bold = true)
                if (returnsCount != "0" && returnsCount.isNotEmpty()) {
                    s.printTwoCols("RETURNS ($returnsCount bills):", "-$returnsAmount", size = 20, bold = true)
                }
                s.printDivider("-", 32)
                s.printTwoCols("TOTAL NET REVENUE:", totalNetRevenue, size = 26, bold = true)
                s.printDivider("-", 32)

                s.printText("PAYMENTS / TENDER BREAKDOWN", size = 20, bold = true, align = Layout.Alignment.ALIGN_NORMAL)
                s.printTwoCols("CASH SALES:", cashSales, size = 20, bold = true)
                s.printTwoCols("NON-CASH SALES:", nonCashSales, size = 20, bold = true)
                if (nonCashBreakdown.isNotEmpty()) {
                    for ((method, amount) in nonCashBreakdown) {
                        s.printTwoCols("  • ${method.uppercase()}:", amount, size = 18, bold = true)
                    }
                } else {
                    if (cardSales != "LKR 0.00" && cardSales.isNotEmpty()) {
                        s.printTwoCols("  • CARD SALES:", cardSales, size = 18, bold = true)
                    }
                    if (qrSales != "LKR 0.00" && qrSales.isNotEmpty()) {
                        s.printTwoCols("  • QR / ONLINE:", qrSales, size = 18, bold = true)
                    }
                    if (creditSales != "LKR 0.00" && creditSales.isNotEmpty()) {
                        s.printTwoCols("  • CREDIT SALES:", creditSales, size = 18, bold = true)
                    }
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

    // ==========================================
    // 9. FONT TEST PRINT (58mm)
    // ==========================================
    fun printFontTest(
        fontName: String,
        onComplete: (Boolean, String?) -> Unit
    ) {
        Thread {
            try {
                if (!isPrinterReady()) {
                    onComplete(false, "DBL Z92 printer is not ready or out of paper")
                    return@Thread
                }
                val p = printer ?: return@Thread onComplete(false, "DBL Z92 printer instance is null")
                activeFont = fontName
                val s = NativePrinterSession(p, context, fontName)

                s.printText("ONIMTA POS - FONT TEST", size = 26, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.printText("STYLE: ${fontName.uppercase()}", size = 20, bold = false, align = Layout.Alignment.ALIGN_CENTER)
                s.printDivider("-", 32)
                s.printText("The quick brown fox jumps over the lazy dog.", size = 20, bold = false)
                s.printText("0123456789 - LKR 1,250.00", size = 22, bold = true)
                s.printDivider("-", 32)
                s.printTwoCols("1. SAMPLE ITEM", "LKR 450.00", size = 20, bold = false)
                s.printTwoCols("2. ANOTHER ITEM", "LKR 800.00", size = 20, bold = false)
                s.printDivider("=", 32)
                s.printTwoCols("TOTAL TEST:", "LKR 1,250.00", size = 22, bold = true)
                s.printDivider("=", 32)
                s.printText("FONT APPLIED SUCCESSFULLY!", size = 20, bold = true, align = Layout.Alignment.ALIGN_CENTER)
                s.feedAndCut(5)
                onComplete(true, null)
            } catch (e: Throwable) {
                Log.e(TAG, "Error printing font test on DBL Z92: ${e.message}", e)
                onComplete(false, "DBL Z92 print error: ${e.message}")
            }
        }.start()
    }
}
