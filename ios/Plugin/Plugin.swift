import Foundation;
import Capacitor;
import AVFoundation;

@objc(MediaCapture)
public class MediaCapture: CAPPlugin {
    let cameraController = CameraController()
    let microphoneController = MicrophoneController()
    
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
        DispatchQueue.main.async {
            self.cameraController.startSession(call: call);
        }
    } 
    
    @objc func stopCameraSession(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.cameraController.stopSession(call: call);
        }
    }
    
    @objc func showCameraPreview(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.cameraController.showPreview(call: call, targetLayer: self.bridge.viewController.view.layer);
        }
    }
    
    @objc func hideCameraPreview(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.cameraController.hidePreview(call: call);
        }
    }
    
    @objc func grabCameraImage(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.cameraController.grabImage(call: call);
        }
    }
    
    @objc func startCameraRecording(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.cameraController.startRecording(call: call);
        }
    }
    
    @objc func stopCameraRecording(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.cameraController.stopRecording(call: call);
        }
    }
    
    // MARK: - Microphone
    @objc func startMicrophoneSession(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.microphoneController.startSession(call: call);
        }
    }
    
    @objc func stopMicrophoneSession(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.microphoneController.stopSession(call: call);
        }
    }
    
    @objc func startMicrophoneRecording(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.microphoneController.startRecording(call: call);
        }
    }
    
    @objc func stopMicrophoneRecording(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.microphoneController.stopRecording(call: call);
        }
    }
}
