#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

// Define the plugin using the CAP_PLUGIN Macro, and
// each method the plugin supports using the CAP_PLUGIN_METHOD macro.
CAP_PLUGIN(MediaCapturePlugin, "MediaCapture",
           CAP_PLUGIN_METHOD(checkPermissions, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(requestPermissions, CAPPluginReturnPromise);
           
           CAP_PLUGIN_METHOD(startCameraSession, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(stopCameraSession, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(showCameraPreview, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(hideCameraPreview, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(grabCameraImage, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(startCameraRecording, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(stopCameraRecording, CAPPluginReturnPromise);
           
           CAP_PLUGIN_METHOD(startMicrophoneSession, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(stopMicrophoneSession, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(startMicrophoneRecording, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(stopMicrophoneRecording, CAPPluginReturnPromise);
)
