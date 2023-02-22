import Foundation
import Capacitor
import AVFoundation

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
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
