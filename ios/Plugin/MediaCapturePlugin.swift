import Foundation
import Capacitor
import AVFoundation
import Photos

@objc(MediaCapturePlugin)
public class MediaCapturePlugin: CAPPlugin {
    private let cameraController = CameraController()
    private let microphoneController = MicrophoneController()

    @objc override public func load() {
        // listen for events
        cameraController.didStartRecordingBlock = { url in
            self.notifyListeners("cameraRecordingStarted", data: ["url": url])
        }

        microphoneController.didStartRecordingBlock = { url in
            self.notifyListeners("microphoneRecordingStarted", data: ["url": url])
        }

        microphoneController.meteringUpdateBlock = { average, peak in
            self.notifyListeners("microphoneMeteringUpdate", data: ["average": average, "peak": peak])
        }
    }

    // MARK: - Permission

    @objc override public func checkPermissions(_ call: CAPPluginCall) {
        var result: [String: Any] = [:]
        for permission in MediaCapturePermissionType.allCases {
            let state: String
            switch permission {
            case .camera:
                state = AVCaptureDevice.authorizationStatus(for: .video).authorizationState
            case .microphone:
                state = AVCaptureDevice.authorizationStatus(for: .audio).authorizationState
            case .photos:
                if #available(iOS 14, *) {
                    state = PHPhotoLibrary.authorizationStatus(for: .readWrite).authorizationState
                } else {
                    state = PHPhotoLibrary.authorizationStatus().authorizationState
                }
            }
            result[permission.rawValue] = state
        }
        call.resolve(result)
    }

    @objc override public func requestPermissions(_ call: CAPPluginCall) {
        // get the list of desired types, if passed
        let typeList = call.getArray("permissions", String.self)?.compactMap({ (type) -> MediaCapturePermissionType? in
            return MediaCapturePermissionType(rawValue: type)
        }) ?? []
        // otherwise check everything
        let permissions: [MediaCapturePermissionType] = (typeList.count > 0) ? typeList : MediaCapturePermissionType.allCases
        // request the permissions
        let group = DispatchGroup()
        for permission in permissions {
            switch permission {
            case .camera:
                group.enter()
                AVCaptureDevice.requestAccess(for: .video) { _ in
                    group.leave()
                }
            case .microphone:
                group.enter()
                AVCaptureDevice.requestAccess(for: .audio) { _ in
                    group.leave()
                }
            case .photos:
                group.enter()
                if #available(iOS 14, *) {
                    PHPhotoLibrary.requestAuthorization(for: .readWrite) { (_) in
                        group.leave()
                    }
                } else {
                    PHPhotoLibrary.requestAuthorization({ (_) in
                        group.leave()
                    })
                }
            }
        }
        group.notify(queue: DispatchQueue.main) { [weak self] in
            self?.checkPermissions(call)
        }
    }

    // MARK: - Camera
    @objc func startCameraSession(_ call: CAPPluginCall) {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
            guard granted else {
                call.reject("permission failed")
                return
            }

            DispatchQueue.main.async {
                self.cameraController.startSession(call: call)
            }
        })
    }

    @objc func stopCameraSession(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.cameraController.stopSession(call: call)
        }
    }

    @objc func showCameraPreview(_ call: CAPPluginCall) {

        guard let targetLayer = self.webView?.superview?.layer else {
            call.reject("Could not find target layer")
            return
        }

        AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
            guard granted else {
                call.reject("permission failed")
                return
            }

            DispatchQueue.main.async {
                self.cameraController.showPreview(call: call, targetLayer: targetLayer)
            }
        })
    }

    @objc func hideCameraPreview(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.cameraController.hidePreview(call: call)
        }
    }

    @objc func grabCameraImage(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.cameraController.grabImage(call: call)
        }
    }

    @objc func startCameraRecording(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.cameraController.startRecording(call: call)
        }
    }

    @objc func stopCameraRecording(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.cameraController.stopRecording(call: call)
        }
    }

    // MARK: - Microphone

    @objc func startMicrophoneSession(_ call: CAPPluginCall) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: { (granted: Bool) in
            guard granted else {
                call.reject("permission failed")
                return
            }

            DispatchQueue.main.async {
                self.microphoneController.startSession(call: call)
            }
        })
    }

    @objc func stopMicrophoneSession(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.microphoneController.stopSession(call: call)
        }
    }

    @objc func startMicrophoneRecording(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.microphoneController.startRecording(call: call)
        }
    }

    @objc func stopMicrophoneRecording(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.microphoneController.stopRecording(call: call)
        }
    }
}

internal enum MediaCapturePermissionType: String, CaseIterable {
    case camera
    case microphone
    case photos
}

internal protocol CameraAuthorizationState {
    var authorizationState: String { get }
}

extension AVAuthorizationStatus: CameraAuthorizationState {
    var authorizationState: String {
        switch self {
        case .denied, .restricted:
            return "denied"
        case .authorized:
            return "granted"
        case .notDetermined:
            fallthrough
        @unknown default:
            return "prompt"
        }
    }
}

extension PHAuthorizationStatus: CameraAuthorizationState {
    var authorizationState: String {
        switch self {
        case .denied, .restricted:
            return "denied"
        case .authorized:
            return "granted"
        #if swift(>=5.3)
        // poor proxy for Xcode 12/iOS 14, should be removed once building with Xcode 12 is required
        case .limited:
            return "limited"
        #endif
        case .notDetermined:
            fallthrough
        @unknown default:
            return "prompt"
        }
    }
}
