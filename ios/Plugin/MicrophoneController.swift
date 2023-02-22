import Capacitor
import MobileCoreServices
import AVFoundation

class CaptureAudioRecorder: AVAudioRecorder {
    var call: CAPPluginCall?
}

@objc(MicrophoneController) class MicrophoneController: NSObject {
    var didStartRecordingBlock: ((String) -> Void)?
    var meteringUpdateBlock: ((Float, Float) -> Void)?

    // MARK: Audio session
    var audioSession: AVAudioSession?
    var audioRecorder: CaptureAudioRecorder?

    // MARK: Audio settings
    var audioSampleRate = 44100.0
    var audioNumChannels = 1
    var audioReuseRecorder = false
    var audioMeterTimer: Timer?
    var audioHasRecorded = false
}

extension MicrophoneController: AVAudioRecorderDelegate {

    // MARK: - Session methods
    func startSession( call: CAPPluginCall ) {
        print("MicrophoneController.startSession()")

        if hasSession() {
            return call.reject("Session is already running")
        }

        // audio / video?
        func configureOptions() throws {
            audioSampleRate = call.getDouble("sampleRate") ?? 44100.0
            audioNumChannels = call.getInt("numChannels") ?? 1
            audioReuseRecorder = call.getBool("reuseRecorder") ?? false
        }

        func createCaptureSession() throws {
            audioSession = AVAudioSession.sharedInstance()
        }

        // starting up a background thread for running checks and starting the session
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try configureOptions()
                try createCaptureSession()
            } catch {
                DispatchQueue.main.async {
                    call.reject(error.localizedDescription)
                }

                return
            }

            DispatchQueue.main.async {
                call.resolve()
            }
        }
    }

    func stopSession( call: CAPPluginCall ) {
        print("MicrophoneController.stopSession()")

        if !hasSession() {
            return call.reject("Session not running")
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.audioSession?.setActive(false)

                self.audioSession = nil

                if !self.audioHasRecorded {
                    self.audioRecorder?.deleteRecording()
                }

                self.audioMeterTimer?.invalidate()

                self.audioRecorder = nil

                call.resolve()
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    // MARK: - Record functions

    func startRecording( call: CAPPluginCall ) {
        let duration = call.getDouble("duration")

        DispatchQueue.global(qos: .userInitiated).async {
            if !self.hasSession() {
                call.reject("No session running")
                return
            }

            if self.isRecording() {
                call.reject("Recording already running")
                return
            }

            // prepare recorder
            do {
                try self.audioSession?.setCategory(AVAudioSession.Category(rawValue: AVAudioSession.Category.record.rawValue))
                try self.audioSession?.setActive(true)
                try self.prepareRecorder()
            } catch {
                call.reject(error.localizedDescription)
                return
            }

            if duration != nil {
                self.audioRecorder?.record(forDuration: duration!)
            } else {
                self.audioRecorder?.record()
            }

            self.audioRecorder?.call = call
            self.audioHasRecorded = true

            self.didStartRecordingBlock!(self.audioRecorder!.url.absoluteString)

            DispatchQueue.main.async {
                self.audioMeterTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                                            target: self,
                                                            selector: #selector(self.updateAudioMeter(_:)),
                                                            userInfo: nil,
                                                            repeats: true)
            }
        }
    }

    func stopRecording( call: CAPPluginCall) {
        if !hasSession() {
            return call.reject("No session running")
        }

        if !isRecording() {
            return call.reject("Recording not running")
        }

        audioRecorder?.stop()

        call.resolve()
    }

    // MARK: - Util functions

    func prepareRecorder() throws {
        // re-use recorder?
        if audioReuseRecorder && audioRecorder != nil {
            audioRecorder?.prepareToRecord()
            return
        }

        audioRecorder = try CaptureAudioRecorder.init(url: createFileUrl()!, settings: [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: audioSampleRate,
            AVNumberOfChannelsKey: audioNumChannels,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ])

        audioRecorder?.delegate = self
        audioRecorder?.prepareToRecord()
        audioRecorder?.isMeteringEnabled = true

        audioHasRecorded = false
    }

    @objc func updateAudioMeter(_ timer: Timer) {

        if audioRecorder == nil {
            return
        }

        audioRecorder?.updateMeters()

        let average = audioRecorder?.averagePower(forChannel: 0) ?? -50
        let peak = audioRecorder?.peakPower(forChannel: 0) ?? -50

        meteringUpdateBlock!(average, peak)
    }

    func createFileUrl() -> URL? {
        let fileName = String(format: "%@%@", NSUUID().uuidString, ".m4a")
        let fileURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        return fileURL
    }

    // MARK: AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        audioMeterTimer?.invalidate()

        let capture: CaptureAudioRecorder? = recorder as? CaptureAudioRecorder

        let call = capture?.call
        capture?.call = nil

        if !flag {
            call?.reject("Recorder finished unsuccessfully")
            return
        }

        let finalURL = createFileUrl()

        do {
            try audioSession?.setCategory(AVAudioSession.Category(rawValue: AVAudioSession.Category.playback.rawValue))
            try FileManager.default.copyItem(at: capture!.url, to: finalURL!)
        } catch {
            call?.reject(error.localizedDescription)
            return
        }

        let result: [String: Any] = [
            "url": finalURL!.absoluteString
        ]

        call?.resolve(result)
    }

    func hasSession() -> Bool {
        return (audioSession != nil)
    }

    func isRecording() -> Bool {
        return audioRecorder != nil && audioRecorder!.isRecording
    }
}

enum MicrophoneControllerError: Swift.Error {
    case unknown
}

extension MicrophoneControllerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unknown:
            return NSLocalizedString("Unknown", comment: "Unknown")
        }
    }
}
