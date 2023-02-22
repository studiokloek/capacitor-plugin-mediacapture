import Capacitor
import MobileCoreServices
import AVFoundation
import Photos
import UIKit
import UIKit.UIDevice

var AVCaptureSessionPresets: [String: AVCaptureSession.Preset] = [
    "low":  .low,
    "medium": .medium,
    "high": .high,
    "photo": .photo,
    "640x480": .vga640x480,
    "1280x720": .hd1280x720,
    "1920x1080": .hd1920x1080,
    "3840x2160": .hd4K3840x2160
]

var AVCaptureDevicePositions: [String: AVCaptureDevice.Position] = [
    "back":  .back,
    "rear":  .back,
    "front":  .front,
]

class CaptureVideoFileOutput : AVCaptureMovieFileOutput {
    var call : CAPPluginCall?
}

class CaptureImageOutput : AVCapturePhotoOutput {
    var call : CAPPluginCall?
}

class CaptureFileOutput : AVCaptureFileOutput {
    var call : CAPPluginCall?
}

@objc(CameraController) class CameraController : NSObject {
    var didStartRecordingBlock: ((String) -> ())?
    
    // MARK: Video session
    var captureSession : AVCaptureSession? = nil
    var sessionPreset = AVCaptureSession.Preset.high
    var sessionDevicePosition = AVCaptureDevice.Position.unspecified
    
    // MARK: Preview
    var preview : AVCaptureVideoPreviewLayer? = nil
    var previewBounds = CGRect.zero
    var previewUseDeviceOrientation = false
    var previewVideoGravity = AVLayerVideoGravity.resizeAspectFill
    
    // MARK: Video recording
    var videoRecording : CaptureVideoFileOutput? = nil
    var videoRecordingUseDeviceOrientation = false
    var videoRecordingAutoSave = false
    
    // MARK: Grab Image
    var imageOutput : CaptureImageOutput? = nil
    var imageFixOrientation = true
    var imageAutoAdjust = true
    var imageAutoSave = false
    var imageFullFrame = true
        
    var currentOrientation: UIDeviceOrientation = .portrait
}

extension CameraController : AVCaptureFileOutputRecordingDelegate, AVCapturePhotoCaptureDelegate {    
        
    // MARK: - Session methods
    func startSession( call: CAPPluginCall )
    {
        print("CameraController.startSession()")
        
        if isSessionRunning() {
            return call.reject("Session is already running")
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        // audio / video?
        func configureOptions() throws {
            // determine preset
            let preset : String = call.getString("preset") ?? call.getString("quality") ?? "high"
            sessionPreset = AVCaptureSessionPresets[preset] ?? AVCaptureSession.Preset.high
            
            // determine camera position
            let position : String = call.getString("position") ?? call.getString("camera") ?? "back"
            sessionDevicePosition = AVCaptureDevicePositions[position] ?? AVCaptureDevice.Position.unspecified
            
            // photo still capture quality
            imageFullFrame = call.getBool("fullFramePhotos") ?? true
        }
        
        func createCaptureSession() {
            self.captureSession = AVCaptureSession()
        }
        
        func preparePreview() {
            // prepare the preview view
            self.preview = AVCaptureVideoPreviewLayer.init(session: self.captureSession!)
        }
        
        func configureVideoCaptureDevice() throws {
            // find the default device and then try to find it by position
            var videoCaptureDevice = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: .video, position: self.sessionDevicePosition).devices.first
            
            if videoCaptureDevice == nil {
                videoCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video)
            }
            
            if videoCaptureDevice == nil {
                throw CameraControllerError.noCaptureDeviceFound
            }
            
            do {
                try videoCaptureDevice?.lockForConfiguration()
                
                if (videoCaptureDevice!.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance)){
                    videoCaptureDevice?.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                
                if (videoCaptureDevice?.isAutoFocusRangeRestrictionSupported == true) {
                    videoCaptureDevice?.autoFocusRangeRestriction = .near
                }
                
                if (videoCaptureDevice?.isLowLightBoostSupported == true) {
                    videoCaptureDevice?.automaticallyEnablesLowLightBoostWhenAvailable = true
                }
                
                videoCaptureDevice?.unlockForConfiguration()
                
            } catch {
                throw error
            }
            
            do {
                let videoCaptureDeviceInput = try AVCaptureDeviceInput.init(device: videoCaptureDevice!)
                
                if self.captureSession!.canAddInput(videoCaptureDeviceInput) {
                    self.captureSession?.addInput(videoCaptureDeviceInput)
                } else {
                    throw CameraControllerError.invalidCaptureInput
                }
            } catch {
                throw CameraControllerError.invalidCaptureInput
            }
        }
        
        func configureAudioCaptureDevice() throws {
            let audioCaptureDevice = AVCaptureDevice.default(for: AVMediaType.audio)
            do {
                let audioCaptureDeviceInput = try AVCaptureDeviceInput.init(device: audioCaptureDevice!)
                
                if self.captureSession!.canAddInput(audioCaptureDeviceInput) {
                    self.captureSession?.addInput(audioCaptureDeviceInput)
                } else {
                    throw CameraControllerError.invalidCaptureInput
                }
            } catch {
                throw CameraControllerError.invalidCaptureInput
            }
        }
        
        func configureImageOutput() throws {
            imageOutput = CaptureImageOutput()
            imageOutput?.isHighResolutionCaptureEnabled = imageFullFrame
            imageOutput?.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format:[AVVideoCodecKey:AVVideoCodecType.jpeg])], completionHandler: nil)
            
            if self.captureSession?.canAddOutput(imageOutput!) ?? false {
                self.captureSession?.addOutput(imageOutput!)
            } else {
                throw CameraControllerError.invalidCaptureOutput
            }
        }
        
        func configureVideoOutput() throws {
            videoRecording = CaptureVideoFileOutput()
            videoRecording?.movieFragmentInterval = CMTime.invalid // unrecommended in docs, but other libs use this
            
            if self.captureSession?.canAddOutput(videoRecording!) ?? false {
                self.captureSession?.addOutput(videoRecording!)
            } else {
                throw CameraControllerError.invalidCaptureOutput
            }
        }
        
        func startSession() throws {
            captureSession?.startRunning()
            captureSession?.sessionPreset = sessionPreset
        }
        
        // starting up a background thread for running checks and starting the session
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try configureOptions()
                createCaptureSession()
                preparePreview();
                try configureVideoCaptureDevice()
                try configureAudioCaptureDevice()
                try configureImageOutput()
                try configureVideoOutput()
                try startSession()
            }
            
            catch {
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
    
    func stopSession( call : CAPPluginCall )
    {
        print("CameraController.stopSession()")
        
        if !isSessionRunning() {
            return call.reject("Session not running")
        }
        
        preview?.removeFromSuperlayer()
        
        NotificationCenter.default.removeObserver(self)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.stopRunning()
            self.captureSession = nil
            
            self.preview?.connection?.isEnabled = false
            self.preview = nil
            
            self.videoRecording = nil
            self.imageOutput = nil
            
            call.resolve()
        }
    }
    
    // MARK: - Orienatation
    @objc func orientationChanged() {
        currentOrientation = UIDevice.current.orientation
    }
    
    // MARK: - Preview methods
    
    func showPreview(call : CAPPluginCall, targetLayer:CALayer)
    {
        print("CameraController.showPreview()")
        
        if !isSessionRunning() {
            return call.reject("Session not running")
        }
        
        if preview != nil && preview?.superlayer != nil {
            return call.reject("Preview already showing")
        }
        
        let rect : Dictionary<String, Double>? = call.get("bounds", Dictionary<String, Double>.self);
        previewBounds = CGRect.init(x: rect?["x"] ?? 0, y: rect?["y"] ?? 0, width: rect?["width"] ?? 1920, height: rect?["height"] ?? 1080)
        previewUseDeviceOrientation = call.getBool("useDeviceOrientation") ?? false
        
        let videoGravity = call.getString("gravity")
        switch videoGravity {
        case "resize"?: previewVideoGravity = .resize
        case "fill"?: previewVideoGravity = .resizeAspectFill
        case "resizeAspect"?: previewVideoGravity = .resizeAspect
        case "contain"?: previewVideoGravity = .resizeAspect
        case "resizeAspectFill"?: previewVideoGravity = .resizeAspectFill
        case "cover"?: previewVideoGravity = .resizeAspectFill
        default: previewVideoGravity = .resizeAspectFill
        }
        
        self.preview?.bounds = self.previewBounds
        self.preview?.videoGravity = self.previewVideoGravity
        self.preview?.position = CGPoint(x: self.previewBounds.midX, y:self.previewBounds.midY)
        self.preview?.connection?.videoOrientation = findPreviewOrientation()
        self.preview?.connection?.isEnabled = true
        
        var duration = call.getDouble("fadeDuration") ?? 0
        
        if duration == 0 {
            duration = 0.01
        }
        
        let fadeAnim = CABasicAnimation(keyPath: "opacity")
        fadeAnim.fromValue = 0
        fadeAnim.toValue = 1
        fadeAnim.duration = duration
        
        DispatchQueue.main.async {
            targetLayer.addSublayer(self.preview!);
            
            CATransaction.begin()
            
            CATransaction.setCompletionBlock {
                self.preview?.removeAllAnimations()
                call.resolve();
            }
            
            self.preview?.opacity = 1
            self.preview?.add(fadeAnim, forKey: "opacity")
            
            CATransaction.commit()
        }
    }
    
    func hidePreview(call : CAPPluginCall)
    {
        print("CameraController.hidePreview()")
        
        if !isSessionRunning() {
            return call.reject("Session not running")
        }
        
        if preview == nil && preview?.superlayer == nil {
            return call.reject("No preview available")
        }
        
        var duration = call.getDouble("fadeDuration") ?? 0
        
        if duration == 0 {
            duration = 0.01
        }
        
        let fadeAnim = CABasicAnimation(keyPath: "opacity")
        fadeAnim.fromValue = 1
        fadeAnim.toValue = 0
        fadeAnim.duration = duration
        
        DispatchQueue.main.async {
            CATransaction.begin()
            
            CATransaction.setCompletionBlock {
                self.preview?.removeAllAnimations()
                self.preview?.connection?.isEnabled = false
                self.preview?.removeFromSuperlayer()
                
                call.resolve();
            }
            
            self.preview?.opacity = 0
            self.preview?.add(fadeAnim, forKey: "opacity")
            
            CATransaction.commit()
        }
    }
    
    
    // MARK: - Image grab / capture functions
    
    func grabImage( call:CAPPluginCall ) {
        print("CameraController.grabImage()")
        
        if !isSessionRunning() {
            return call.reject("Session not running")
        }
        
        imageFixOrientation = call.getBool("fixOrientation") ?? true
        imageAutoAdjust = call.getBool("autoAdjust") ?? true
        imageAutoSave = call.getBool("autoSave") ?? false
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = AVCaptureDevice.FlashMode.off
        settings.isHighResolutionPhotoEnabled = false
        settings.isAutoStillImageStabilizationEnabled = true;
        
        if #available(iOS 12.0, *) {
            settings.isAutoRedEyeReductionEnabled = true
        } else {
            // Fallback on earlier versions
        }
        
        imageOutput?.call = call
        imageOutput?.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        print("CameraController.photoOutput()")
        
        let capture : CaptureImageOutput? = output as? CaptureImageOutput
        if (capture == nil) {
            return
        }
        
        // get plugin call and unset it
        let call = capture?.call
        capture?.call = nil
        
        if (error != nil) {
            call?.reject(error!.localizedDescription)
            return;
        }
        
        let fileName = String(format: "%@%@", NSUUID().uuidString, ".jpg")
        let fileURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
                
        var imageData = photo.cgImageRepresentation()!.takeUnretainedValue();
        
        if (self.imageFixOrientation) {
            var tempImage = CIImage(cgImage: imageData)
            
            switch currentOrientation {
            case .portrait:
                tempImage = tempImage.oriented(forExifOrientation: 6)
            case .landscapeRight:
                tempImage = tempImage.oriented(forExifOrientation: 3)
            case .landscapeLeft:
                tempImage = tempImage.oriented(forExifOrientation: 1)
            default:
                break
            }
            
            imageData = CIContext(options: nil).createCGImage(tempImage, from: tempImage.extent)!
        }

        var image = UIImage.init(cgImage:imageData)

        if (self.imageAutoAdjust) {
            image = image.autoAdjust()
        }
        
        do {
            try image.jpegData(compressionQuality: 0.75)?.write(to: fileURL!)
        } catch {
            call?.reject(error.localizedDescription)
        }
        
        let result : Dictionary<String, Any> = [
            "url" : fileURL!.absoluteString
        ]
        
        // should we save it to the library?
        if self.imageAutoSave {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }) { saved, error in
                if !saved {
                    call?.reject(error?.localizedDescription ?? "Unable to save to photo library")
                } else {
                    call?.resolve(result)
                }
            }
        } else {
            call?.resolve(result)
        }
    }
    
    // MARK: - Video recording / capture functions
    
    func startRecording( call: CAPPluginCall)
    {
        print("CameraController.startRecording()")
        
        if !isSessionRunning() {
            return call.reject("Session not running")
        }
        
        if isRecording() {
            return call.reject("Recording already running")
        }
        
        // get options
        videoRecordingUseDeviceOrientation = call.getBool("useDeviceOrientation") ?? false
        videoRecordingAutoSave = call.getBool("autoSave") ?? false
        
        // determine filename and path
        let fileName = String(format: "%@%@", NSUUID().uuidString, ".mov")
        let fileURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        // determine max duration
        let duration = call.getDouble("duration") ?? nil
        if duration != nil {
            videoRecording?.maxRecordedDuration = CMTime.init(seconds: duration!, preferredTimescale: 1)
        }
        
        // fix orientation
        let connection : AVCaptureConnection? = videoRecording?.connection(with: AVMediaType.video)
        if connection?.isVideoOrientationSupported ?? false {
            connection?.videoOrientation = findVideoRecordingOrientation()
        }
        
        videoRecording?.call = call
        videoRecording?.startRecording(to: fileURL!, recordingDelegate: self)
    }
    
    func stopRecording( call: CAPPluginCall)
    {
        print("CameraController.startRecording()")
        
        if !isRecording() {
            return call.reject("Recording not running")
        }
        
        videoRecording?.stopRecording()
        
        call.resolve();
    }
    
    func fileOutput(_ captureOutput: AVCaptureFileOutput, didStartRecordingTo: URL, from: [AVCaptureConnection]) {
        
        print("CameraController.fileOutput(start)")
        
        // start of capture
        let capture : CaptureVideoFileOutput? = captureOutput as? CaptureVideoFileOutput
        
        if capture == nil {
            let call = capture?.call
            capture?.call = nil
            call?.reject("Invalid capture")
            return
        }
        
        // let plugin know we started recording
        self.didStartRecordingBlock!(didStartRecordingTo.absoluteString);
    }
    
    func fileOutput(_ captureOutput: AVCaptureFileOutput, didFinishRecordingTo: URL, from: [AVCaptureConnection], error: Error?) {
        
        print("CameraController.fileOutput(finish)")
        
        let capture : CaptureVideoFileOutput? = captureOutput as? CaptureVideoFileOutput

        if capture == nil {
            return
        }

        let call = capture?.call
        capture?.call = nil
        
        let result : Dictionary<String, Any> = [
            "url" : didFinishRecordingTo.absoluteString
        ]
        
        // save to library?
        if !videoRecordingAutoSave {
            call?.resolve(result);
            return;
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: didFinishRecordingTo)
        }) { saved, error in
            
            if !saved {
                call?.reject(error?.localizedDescription ?? "Unable to save to photo library")
                return
            }
            
            call?.resolve(result);
        }
    }
    
    
    // MARK: - Util functions
    func isSessionRunning() -> Bool
    {
        return (captureSession != nil && captureSession!.isRunning)
    }
    
    func isRecording() -> Bool
    {
        return videoRecording != nil && videoRecording!.isRecording
    }
    
    func findPreviewOrientation() -> AVCaptureVideoOrientation
    {
        if previewUseDeviceOrientation {
            return getDeviceOriented()
        }
        
        return getStatusBarOriented()
    }
    
    func getDeviceOriented() -> AVCaptureVideoOrientation
    {
        switch UIDevice.current.orientation {
        case UIDeviceOrientation.landscapeLeft: return AVCaptureVideoOrientation.landscapeRight //yes right on left :S
        case UIDeviceOrientation.landscapeRight: return AVCaptureVideoOrientation.landscapeLeft
        case UIDeviceOrientation.portraitUpsideDown: return AVCaptureVideoOrientation.portraitUpsideDown
        default: return AVCaptureVideoOrientation.portrait
        }
    }
    
    func getStatusBarOriented() -> AVCaptureVideoOrientation
    {
        switch UIApplication.shared.statusBarOrientation {
        case UIInterfaceOrientation.landscapeLeft: return AVCaptureVideoOrientation.landscapeLeft
        case UIInterfaceOrientation.landscapeRight: return AVCaptureVideoOrientation.landscapeRight
        case UIInterfaceOrientation.portraitUpsideDown: return AVCaptureVideoOrientation.portraitUpsideDown
        default: return AVCaptureVideoOrientation.portrait
        }
    }
    
    func findVideoRecordingOrientation() -> AVCaptureVideoOrientation
    {
        if videoRecordingUseDeviceOrientation {
            return getDeviceOriented()
        }
        
        return getStatusBarOriented()
    }
    
    func findImageOrientation() -> AVCaptureVideoOrientation
    {
        if imageFixOrientation {
            return getDeviceOriented()
        }
        
        return getStatusBarOriented()
    }
    
    
    // MARK: - Permission / device poll methods
    func isFrontCameraAvailable() -> Bool
    {
        return UIImagePickerController.isCameraDeviceAvailable(UIImagePickerController.CameraDevice.front)
    }
    
    func isRearCameraAvailable() -> Bool
    {
        return UIImagePickerController.isCameraDeviceAvailable(UIImagePickerController.CameraDevice.rear)
    }
}


// UIIMAGE EXTENSIONS


extension UIImage {
    struct RotationOptions: OptionSet {
        let rawValue: Int   
        static let flipOnVerticalAxis = RotationOptions(rawValue: 1)
        static let flipOnHorizontalAxis = RotationOptions(rawValue: 2)
    }
}

extension UIImage {
    func autoAdjust() -> UIImage {
        var inputImage = CIImage(image: self)!
        let filters = inputImage.autoAdjustmentFilters(options: nil)
        for filter: CIFilter in filters {
            filter.setValue(inputImage, forKey: kCIInputImageKey)
            inputImage = filter.outputImage!
        }
        
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(inputImage, from: inputImage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        
        return image
    }
    
//    func fixedOrientation(isUsingFrontCamera: Bool) -> UIImage? {
//        var flip:Bool = false //used to see if the image is mirrored
//        var isRotatedBy90:Bool = false // used to check whether aspect ratio is to be changed or not
//
//        var transform = CGAffineTransform.identity
//
//        //check current orientation of original image
//        switch self.imageOrientation {
//        case .down, .downMirrored:
//            print("down")
//            transform = transform.rotated(by: .pi)
//        case .left, .leftMirrored:
//            print("left")
//            transform = transform.rotated(by: .pi / 2)
//            isRotatedBy90 = true
//        case .right, .rightMirrored:
//            print("right")
//            transform = transform.rotated(by: .pi / -2)
//            isRotatedBy90 = true
//        case .up, .upMirrored:
//            print("up")
//            break
//        default:
//            print("unknown")
//        }
//
//        switch self.imageOrientation {
//        case .upMirrored, .downMirrored:
//            transform = transform.translatedBy(x: self.size.width, y: 0)
//            flip = true
//            print("mirror vertical")
//
//        case .leftMirrored, .rightMirrored:
//            transform = transform.translatedBy(x: self.size.height, y: 0)
//            flip = true
//            print("mirror horizontal")
//        default:
//            break
//        }
//
//        if isUsingFrontCamera {
//            transform = transform.translatedBy(x: self.size.width, y: 0)
//            flip = true
//        }
//
//        // calculate the size of the rotated view's containing box for our drawing space
//        let rotatedViewBox = UIView(frame: CGRect(origin: CGPoint(x:0, y:0), size: size))
//        rotatedViewBox.transform = transform
//        let rotatedSize = rotatedViewBox.frame.size
//
//        // Create the bitmap context
//        UIGraphicsBeginImageContext(rotatedSize)
//        let bitmap = UIGraphicsGetCurrentContext()
//
//        // Move the origin to the middle of the image so we will rotate and scale around the center.
//        bitmap!.translateBy(x: rotatedSize.width / 2.0, y: rotatedSize.height / 2.0)
//
//        // Now, draw the rotated/scaled image into the context
//        if(flip){
//            bitmap!.scaleBy(x: 1.0, y: 1.0)
//        } else {
//            bitmap!.scaleBy(x: 1.0, y: -1.0)
//        }
//
//
//        print("Transform Image", flip, isRotatedBy90, separator:" ")
//
//        //check if we have to fix the aspect ratio
//        if isRotatedBy90 {
//            bitmap?.draw(self.cgImage!, in: CGRect(x: -floor(size.height / 2), y: -floor(size.width / 2), width: size.height,height: size.width))
//        } else {
//            bitmap?.draw(self.cgImage!, in: CGRect(x: -floor(size.width / 2), y: -floor(size.height / 2), width: size.width,height: size.height))
//        }
//
//        let fixedImage = UIGraphicsGetImageFromCurrentImageContext()
//        UIGraphicsEndImageContext()
//
//        return fixedImage
//    }
}

enum CameraControllerError: Swift.Error {
    case noCaptureDeviceFound
    case invalidCaptureInput
    case invalidCaptureOutput
    case invalidSessionOptions
    case invalidOperation
    case noCamerasAvailable
    case unknown
}

extension CameraControllerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .noCaptureDeviceFound:
            return NSLocalizedString("No suitable capture device found", comment: "No suitable capture device found")
        case .invalidSessionOptions:
            return NSLocalizedString("Invalid session options provided", comment: "Invalid session options provided")
        case .invalidCaptureInput:
            return NSLocalizedString("Capture iInput is invalid", comment: "The capture device could not be added as input to the session.")
        case .invalidCaptureOutput:
            return NSLocalizedString("Caputre output is invalid", comment: "The capture output could not be added to the session.")
        case .invalidOperation:
            return NSLocalizedString("Invalid Operation", comment: "Invalid Operation")
        case .noCamerasAvailable:
            return NSLocalizedString("Failed to access device camera(s)", comment: "No Cameras Available")
        case .unknown:
            return NSLocalizedString("Unknown", comment: "Unknown")
        }
    }
}
