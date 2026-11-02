import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TextReader") {
      TextReader.register(with: registrar.messenger())
    }
  }
}

/// "Scan to fill": reads the text in a photo with Apple's on-device Vision
/// framework. Answers `read(path)` with one entry per recognised line:
/// its text, confidence, and box (0..1, top-left origin, as displayed).
enum TextReader {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "daily_bag/text_reader", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "read",
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        let reply: Any
        do {
          reply = try read(path: path)
        } catch {
          reply = FlutterError(code: "read_failed", message: error.localizedDescription, details: nil)
        }
        DispatchQueue.main.async { result(reply) }
      }
    }
  }

  private static func read(path: String) throws -> [[String: Any]] {
    guard let image = UIImage(contentsOfFile: path), let cgImage = image.cgImage else {
      throw NSError(
        domain: "TextReader", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not open the photo"])
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["en-US"]
    request.usesLanguageCorrection = true

    let handler = VNImageRequestHandler(
      cgImage: cgImage, orientation: orientation(of: image), options: [:])
    try handler.perform([request])

    return (request.results ?? []).compactMap { observation in
      guard let best = observation.topCandidates(1).first else { return nil }
      let box = observation.boundingBox
      return [
        "text": best.string,
        "confidence": Double(best.confidence),
        "x": Double(box.minX),
        "y": Double(1 - box.maxY),
        "w": Double(box.width),
        "h": Double(box.height),
      ]
    }
  }

  private static func orientation(of image: UIImage) -> CGImagePropertyOrientation {
    switch image.imageOrientation {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
  }
}
