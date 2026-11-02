package com.example.little_expense

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "daily_bag/text_reader")
            .setMethodCallHandler { call, result ->
                val path = call.argument<String>("path")
                if (call.method != "read" || path == null) {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                read(path, result)
            }
    }

    /**
     * "Scan to fill": reads a photo with ML Kit's on-device text recognizer.
     * Replies with one entry per line: text, confidence, and its box
     * (0..1, top-left origin, in the upright photo).
     */
    private fun read(path: String, result: MethodChannel.Result) {
        val image = try {
            InputImage.fromFilePath(this, Uri.fromFile(File(path)))
        } catch (e: Exception) {
            result.error("read_failed", e.message, null)
            return
        }
        val turned = image.rotationDegrees % 180 != 0
        val width = (if (turned) image.height else image.width).toDouble()
        val height = (if (turned) image.width else image.height).toDouble()

        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
            .process(image)
            .addOnSuccessListener { text ->
                val lines = text.textBlocks.flatMap { it.lines }.mapNotNull { line ->
                    val box = line.boundingBox ?: return@mapNotNull null
                    mapOf(
                        "text" to line.text,
                        "confidence" to line.confidence.toDouble(),
                        "x" to box.left / width,
                        "y" to box.top / height,
                        "w" to box.width() / width,
                        "h" to box.height() / height,
                    )
                }
                result.success(lines)
            }
            .addOnFailureListener { e -> result.error("read_failed", e.message, null) }
    }
}
