import Flutter
import UIKit
import QuickLook
import Security
import CryptoKit

@main
@objc class AppDelegate: FlutterAppDelegate, UIDocumentPickerDelegate, QLPreviewControllerDataSource {
  private var oauthChannel: FlutterMethodChannel?
  private var initialOAuthLink: String?
  private func isOAuthLink(_ url: URL) -> Bool { url.scheme == "com.creo.app" && url.host == "app" && url.path == "/auth/google/callback" }
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    if isOAuthLink(url) { initialOAuthLink = url.absoluteString; oauthChannel?.invokeMethod("link", arguments: initialOAuthLink); return true }
    return super.application(app, open: url, options: options)
  }
  private var fileResult: FlutterResult?
  private var saveResult: FlutterResult?
  private var saveTempURL: URL?
  private var mediaOnly = true
  private var previewURL: URL?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let initial = launchOptions?[.url] as? URL, isOAuthLink(initial) { initialOAuthLink = initial.absoluteString }
    if let controller = window?.rootViewController as? FlutterViewController {
      oauthChannel = FlutterMethodChannel(name: "creo/oauth", binaryMessenger: controller.binaryMessenger)
      oauthChannel?.setMethodCallHandler { [weak self] call, result in
        guard let self = self else { return }
        if call.method == "takeInitialLink" { let link = self.initialOAuthLink; self.initialOAuthLink = nil; result(link) }
        else if call.method == "createPkce" {
          if #available(iOS 13.0, *) {
            var bytes = [UInt8](repeating: 0, count: 32)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { result(FlutterError(code: "RANDOM_FAILED", message: "Unable to create secure sign-in.", details: nil)); return }
            func encode(_ data: Data) -> String { data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
            let verifier = encode(Data(bytes))
            let challenge = encode(Data(SHA256.hash(data: Data(verifier.utf8))))
            result(["verifier": verifier, "challenge": challenge])
          } else { result(FlutterError(code: "UNSUPPORTED_IOS", message: "Google sign-in needs iOS 13 or later.", details: nil)) }
        } else { result(FlutterMethodNotImplemented) }
      }
      FlutterMethodChannel(name: "creo/workstation_files", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { [weak self, weak controller] call, result in
          guard let self = self else { return }
          if call.method == "pick" {
            guard self.fileResult == nil && self.saveResult == nil else {
              result(FlutterError(code: "BUSY", message: "A file picker is already open.", details: nil)); return
            }
            self.fileResult = result
            self.mediaOnly = (call.arguments as? [String: Any])?["mediaOnly"] as? Bool != false
            let picker = UIDocumentPickerViewController(documentTypes: self.mediaOnly ? ["public.image", "public.movie"] : ["public.data"], in: .import)
            picker.delegate = self
            controller?.present(picker, animated: !UIAccessibility.isReduceMotionEnabled)
          } else if call.method == "save" {
            guard self.fileResult == nil && self.saveResult == nil else {
              result(FlutterError(code: "BUSY", message: "A file operation is already open.", details: nil)); return
            }
            guard
              let args = call.arguments as? [String: Any],
              let payload = args["bytes"] as? FlutterStandardTypedData,
              !payload.data.isEmpty,
              let rawName = args["name"] as? String,
              let mimeType = args["mimeType"] as? String,
              !mimeType.isEmpty
            else {
              result(FlutterError(code: "INVALID_DOWNLOAD", message: "The downloaded file is incomplete.", details: nil)); return
            }
            let safeName = rawName.components(separatedBy: CharacterSet(charactersIn: "/\\")).last ?? ""
            guard !safeName.isEmpty else {
              result(FlutterError(code: "INVALID_DOWNLOAD", message: "The downloaded file name is invalid.", details: nil)); return
            }
            self.saveResult = result
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("creo-downloads", isDirectory: true)
            let target = folder.appendingPathComponent(UUID().uuidString).appendingPathComponent(safeName)
            self.saveTempURL = target
            DispatchQueue.global(qos: .userInitiated).async {
              do {
                try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try payload.data.write(to: target, options: .atomic)
                DispatchQueue.main.async {
                  guard let controller = controller else {
                    self.finishSave(false)
                    return
                  }
                  let picker: UIDocumentPickerViewController
                  if #available(iOS 14.0, *) {
                    picker = UIDocumentPickerViewController(forExporting: [target], asCopy: true)
                  } else {
                    picker = UIDocumentPickerViewController(url: target, in: .exportToService)
                  }
                  picker.delegate = self
                  controller.present(picker, animated: !UIAccessibility.isReduceMotionEnabled)
                }
              } catch {
                DispatchQueue.main.async {
                  self.finishSave(false, error: FlutterError(code: "SAVE_FAILED", message: "The downloaded file could not be prepared for saving.", details: nil))
                }
              }
            }
          } else if call.method == "release" {
            if let args = call.arguments as? [String: String], let path = args["path"] {
              let target = URL(fileURLWithPath: path).standardizedFileURL
              let folder = FileManager.default.temporaryDirectory.appendingPathComponent("workstation-files").standardizedFileURL
              if target.deletingLastPathComponent() == folder { try? FileManager.default.removeItem(at: target) }
            }
            result(nil)
          } else if call.method == "preview" {
            if let args = call.arguments as? [String: String], let path = args["path"] {
              let target = URL(fileURLWithPath: path).standardizedFileURL
              let folder = FileManager.default.temporaryDirectory.appendingPathComponent("workstation-files").standardizedFileURL
              if target.deletingLastPathComponent() == folder && FileManager.default.fileExists(atPath: target.path) {
                self.previewURL = target
                let preview = QLPreviewController()
                preview.dataSource = self
                controller?.present(preview, animated: !UIAccessibility.isReduceMotionEnabled)
                result(nil); return
              }
            }
            result(FlutterError(code: "PREVIEW_UNAVAILABLE", message: "Select the file again to preview it.", details: nil))
          } else { result(FlutterMethodNotImplemented) }
        }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func numberOfPreviewItems(in controller: QLPreviewController) -> Int { return previewURL == nil ? 0 : 1 }
  func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { return previewURL! as NSURL }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    if saveResult != nil {
      finishSave(false)
    } else {
      fileResult?(nil); fileResult = nil
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    if saveResult != nil {
      finishSave(!urls.isEmpty)
      return
    }
    guard let source = urls.first, let result = fileResult else { return }
    fileResult = nil
    DispatchQueue.global(qos: .userInitiated).async {
      let permitted = source.startAccessingSecurityScopedResource()
      defer { if permitted { source.stopAccessingSecurityScopedResource() } }
      do {
        let values = try source.resourceValues(forKeys: [.fileSizeKey])
        let mimes = ["mp4": "video/mp4", "mov": "video/quicktime", "png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "webp": "image/webp", "gif": "image/gif"]
        let mime = mimes[source.pathExtension.lowercased()] ?? "application/octet-stream"
        let size = values.fileSize ?? 0
        let supported = ["video/mp4", "video/quicktime", "image/png", "image/jpeg", "image/webp", "image/gif"]
        guard (!self.mediaOnly || supported.contains(mime)), size > 0, size <= (!self.mediaOnly ? 50 : mime.hasPrefix("video/") ? 500 : 10) * 1024 * 1024 else {
          throw NSError(domain: "InvalidFile", code: 1)
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("workstation-files", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let target = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(source.pathExtension)
        try FileManager.default.copyItem(at: source, to: target)
        DispatchQueue.main.async { result(["path": target.path, "name": source.lastPathComponent, "size": size, "mimeType": mime]) }
      } catch {
        DispatchQueue.main.async { result(FlutterError(code: "FILE_READ_FAILED", message: "Choose a readable image up to 10 MB or MP4/MOV video up to 500 MB.", details: nil)) }
      }
    }
  }

  private func finishSave(_ saved: Bool, error: FlutterError? = nil) {
    let result = saveResult
    saveResult = nil
    if let temp = saveTempURL {
      try? FileManager.default.removeItem(at: temp.deletingLastPathComponent())
    }
    saveTempURL = nil
    if let error = error {
      result?(error)
    } else {
      result?(saved)
    }
  }
}
