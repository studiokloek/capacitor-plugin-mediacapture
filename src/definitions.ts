// PERMISSIONS
export type MediaCapturePermissionState = PermissionState | 'limited';

export type MediaCapturePermissionType = 'camera' | 'photos' | 'microphone';

export interface PermissionStatus {
  camera: MediaCapturePermissionState;
  photos: MediaCapturePermissionState;
  microphone: MediaCapturePermissionState;
}

export interface MediaCapturePluginPermissions {
  permissions: MediaCapturePermissionType[];
}

// CAMERA
export interface CameraSessionOptions {
  audio?: boolean;
  video?: boolean;
  photo?: boolean;
  preset?: string;
  position?: string;
  fullFramePhotos?: boolean;
}

export interface CameraPreviewShowOptions {
  frame?: { x: number; y: number; width: number; height: number };
  gravity?: string;
  fadeDuration?: number;
  useDeviceOrientation?: boolean;
}

export interface CameraPreviewHideOptions {
  fadeDuration?: number;
}

export interface StartCameraRecordingOptions {
  autoSave?: boolean;
  duration?: number;
  useDeviceOrientation?: boolean;
}

export interface CameraRecordingResult {
  url: string;
}

export interface GrabCameraImageOptions {
  autoSave?: boolean;
  useDeviceOrientation?: boolean;
  autoAdjust?: boolean;
}

export interface GrabCameraImageResult {
  url: string;
}

// MICROPHONE
export interface MicrophoneSessionOptions {
  sampleRate?: number;
  reuseRecorder?: boolean;
  numChannels?: number;
}

export interface StartMicrophoneRecordingOptions {
  duration?: number;
}

export interface MicrophoneRecordingResult {
  url: string;
}

export interface MediaCapturePlugin {
  // PERMISSIONS
  checkPermissions(): Promise<PermissionStatus>;
  requestPermissions(
    permissions?: MediaCapturePluginPermissions,
  ): Promise<PermissionStatus>;

  // CAMERA
  startCameraSession(options: CameraSessionOptions): Promise<boolean>;
  stopCameraSession(): Promise<boolean>;

  showCameraPreview(options: CameraPreviewShowOptions): Promise<boolean>;
  hideCameraPreview(options: CameraPreviewHideOptions): Promise<boolean>;

  startCameraRecording(options: StartCameraRecordingOptions): Promise<boolean>;
  stopCameraRecording(): Promise<undefined | CameraRecordingResult>;
  grabCameraImage(
    options: GrabCameraImageOptions,
  ): Promise<undefined | GrabCameraImageResult>;

  // MICROPHONE
  startMicrophoneSession(options: MicrophoneSessionOptions): Promise<boolean>;
  stopMicrophoneSession(): Promise<boolean>;
  startMicrophoneRecording(
    options: StartMicrophoneRecordingOptions,
  ): Promise<boolean>;
  stopMicrophoneRecording(): Promise<undefined | MicrophoneRecordingResult>;
}
