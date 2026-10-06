package com.onimta.mobile_pos

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.oned.Code128Writer
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import java.util.EnumMap

object BarcodeBitmapHelper {

    /**
     * Generates an ultra-sharp, integer-scaled 1D Code-128 Barcode Bitmap
     * with crisp solid bars and large quiet zones (zero anti-aliasing / dithering).
     */
    fun createCrispCode128(
        content: String,
        maxWidth: Int = 384,
        barHeight: Int = 110
    ): Bitmap? {
        if (content.isEmpty()) return null
        return try {
            val hints = EnumMap<EncodeHintType, Any>(EncodeHintType::class.java).apply {
                put(EncodeHintType.MARGIN, 0)
            }
            val writer = Code128Writer()
            val rawMatrix = writer.encode(content, BarcodeFormat.CODE_128, 0, 0, hints)
            val moduleCount = rawMatrix.width

            // Determine integer scale factor (2px per module for codes <= 170 modules, 1px otherwise)
            val scale = if (moduleCount * 2 <= maxWidth - 24) 2 else 1
            val barcodeWidth = moduleCount * scale
            val totalWidth = maxWidth.coerceAtLeast(barcodeWidth + 24)
            val leftMargin = (totalWidth - barcodeWidth) / 2

            val bitmap = Bitmap.createBitmap(totalWidth, barHeight, Bitmap.Config.RGB_565)
            val canvas = Canvas(bitmap)
            canvas.drawColor(Color.WHITE)

            val paint = Paint().apply {
                color = Color.BLACK
                style = Paint.Style.FILL
                isAntiAlias = false // Razor-sharp thermal edges without grey blur
            }

            for (i in 0 until moduleCount) {
                if (rawMatrix.get(i, 0)) {
                    val xStart = leftMargin + (i * scale)
                    val xEnd = xStart + scale
                    canvas.drawRect(xStart.toFloat(), 0f, xEnd.toFloat(), barHeight.toFloat(), paint)
                }
            }

            bitmap
        } catch (e: Throwable) {
            e.printStackTrace()
            null
        }
    }

    /**
     * Generates a high-contrast QR code for instant camera & 2D scanner reading
     */
    fun createCrispQrCode(
        content: String,
        size: Int = 180
    ): Bitmap? {
        if (content.isEmpty()) return null
        return try {
            val hints = EnumMap<EncodeHintType, Any>(EncodeHintType::class.java).apply {
                put(EncodeHintType.MARGIN, 1)
                put(EncodeHintType.ERROR_CORRECTION, ErrorCorrectionLevel.M)
            }
            val bitMatrix = QRCodeWriter().encode(
                content,
                BarcodeFormat.QR_CODE,
                size,
                size,
                hints
            )

            val width = bitMatrix.width
            val height = bitMatrix.height
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565)
            val pixels = IntArray(width * height)

            for (y in 0 until height) {
                val offset = y * width
                for (x in 0 until width) {
                    pixels[offset + x] = if (bitMatrix.get(x, y)) Color.BLACK else Color.WHITE
                }
            }
            bitmap.setPixels(pixels, 0, width, 0, 0, width, height)
            bitmap
        } catch (e: Throwable) {
            e.printStackTrace()
            null
        }
    }
}
