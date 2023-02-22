import Foundation
import Capacitor
import AVKit

var MediaCaptureOverrideTypes: [AVAudioSession.PortOverride: String] = [
    .none: "none",
    .speaker: "speaker"
]

var MediaCaptureRouteChangeReasons: [AVAudioSession.RouteChangeReason: String] = [
    .newDeviceAvailable: "new-device-available",
    .oldDeviceUnavailable: "old-device-unavailable",
    .categoryChange: "category-change",
    .override: "override",
    .wakeFromSleep: "wake-from-sleep",
    .noSuitableRouteForCategory: "no-suitable-route-for-category",
    .routeConfigurationChange: "route-config-change",
    .unknown: "unknown"
]

var MediaCaptureInterruptionTypes: [AVAudioSession.InterruptionType: String] = [
    .began: "began",
    .ended: "ended"
]

var MediaCapturePorts: [AVAudioSession.Port: String] = [
    .airPlay: "airplay",
    .bluetoothLE: "bluetooth-le",
    .bluetoothHFP: "bluetooth-hfp",
    .bluetoothA2DP: "bluetooth-a2dp",
    .builtInSpeaker: "builtin-speaker",
    .builtInReceiver: "builtin-receiver",
    .HDMI: "hdmi",
    .headphones: "headphones",
    .lineOut: "line-out"
]

public typealias MediaCaptureRouteChangeObserver = (String) -> Void
public typealias MediaCaptureInterruptionObserver = (String) -> Void
public typealias MediaCaptureOverrideCallback = (Bool, String) -> Void

public class MediaCapture: NSObject {

    var routeChangeObserver: MediaCaptureRouteChangeObserver?
    var interruptionObserver: MediaCaptureInterruptionObserver?

    public func load() {
        let nc = NotificationCenter.default

        nc.addObserver(self,
                       selector: #selector(self.handleRouteChange),
                       name: AVAudioSession.routeChangeNotification,
                       object: nil)

        nc.addObserver(self,
                       selector: #selector(self.handleInterruption),
                       name: AVAudioSession.interruptionNotification,
                       object: AVAudioSession.sharedInstance)
    }

    // EVENTS

    @objc func handleRouteChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reasonType = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
        let readableReason = MediaCaptureRouteChangeReasons[reasonType] ?? "unknown"

        CAPLog.print("MediaCapture.handleRouteChange() changed to \(readableReason)")

        self.routeChangeObserver?(readableReason)
    }

    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let interruptValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptType = AVAudioSession.InterruptionType(rawValue: interruptValue) else { return }
        let readableInterrupt = MediaCaptureInterruptionTypes[interruptType] ?? "unknown"

        CAPLog.print("MediaCapture.handleInterruption() interrupted status to \(readableInterrupt)")

        self.interruptionObserver?(readableInterrupt)
    }

    // METHODS

    public func currentOutputs() -> [String?] {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs.map({MediaCapturePorts[$0.portType]})

        return outputs
    }

    public func overrideOutput(_output: String, _callback:@escaping MediaCaptureOverrideCallback) {
        if _output == "unknown" {
            return _callback(false, "No valid output provided...")
        }

        // make it async, cause in latest IOS it started to take ~1 sec and produce UI thread blocking issues
        DispatchQueue.global(qos: .utility).async {
            let session = AVAudioSession.sharedInstance()

            // make sure the AVAudioSession is properly configured
            do {
                try session.setActive(true)
                try session.setCategory(AVAudioSession.Category.playAndRecord, options: AVAudioSession.CategoryOptions.duckOthers)
            } catch {
                CAPLog.print("MediaCapture.overrideOutput() error setting sessions settings.")
                _callback(false, "Error setting sessions settings.")
                return
            }

            do {
                if _output == "speaker" {
                    try session.overrideOutputAudioPort(.speaker)
                } else {
                    try session.overrideOutputAudioPort(.none)
                }

                _callback(true, "")
            } catch {
                CAPLog.print("MediaCapture.overrideOutput() could not override output port.")
                _callback(false, "Could not override output port.")
            }
        }
    }
}
