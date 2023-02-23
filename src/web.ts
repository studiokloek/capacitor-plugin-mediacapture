import { WebPlugin } from '@capacitor/core';

import type {
  CameraPreviewShowOptions,
  CameraSessionOptions,
  MediaCapturePlugin,
  CameraPreviewHideOptions,
  CameraRecordingResult,
  GrabCameraImageOptions,
  GrabCameraImageResult,
  MicrophoneRecordingResult,
  MicrophoneSessionOptions,
  StartCameraRecordingOptions,
  StartMicrophoneRecordingOptions,
  PermissionStatus,
} from './definitions';

export class MediaCaptureWeb extends WebPlugin implements MediaCapturePlugin {
  async checkPermissions(): Promise<PermissionStatus> {
    console.warn(
      'MediaCaptureWeb.checkPermissions() is not implemented on this platform.',
    );

    return {
      camera: 'granted',
      microphone: 'granted',
      photos: 'granted',
    };
  }

  async requestPermissions(): Promise<PermissionStatus> {
    console.warn(
      'MediaCaptureWeb.checkPermissions() is not implemented on this platform.',
    );

    return {
      camera: 'granted',
      microphone: 'granted',
      photos: 'granted',
    };
  }

  // CAMERA
  async startCameraSession(options: CameraSessionOptions): Promise<boolean> {
    console.warn(
      'MediaCaptureWeb.startCameraSession() is not implemented on this platform.',
      options,
    );

    return false;
  }

  async stopCameraSession(): Promise<boolean> {
    console.warn(
      'MediaCaptureWeb.stopCameraSession() is not implemented on this platform.',
    );

    return false;
  }

  async showCameraPreview(options: CameraPreviewShowOptions): Promise<boolean> {
    console.warn(
      'MediaCaptureWeb.showCameraPreview() is not implemented on this platform.',
      options,
    );

    return false;
  }

  async hideCameraPreview(options: CameraPreviewHideOptions): Promise<boolean> {
    console.warn(
      'MediaCaptureWeb.hideCameraPreview() is not implemented on this platform.',
      options,
    );

    return false;
  }

  async startCameraRecording(
    options: StartCameraRecordingOptions,
  ): Promise<boolean> {
    console.warn(
      'MediaCaptureWeb.startCameraRecording() is not implemented on this platform.',
      options,
    );

    return false;
  }

  async stopCameraRecording(): Promise<undefined | CameraRecordingResult> {
    console.warn(
      'MediaCaptureWeb.stopCameraRecording() is not implemented on this platform.',
    );

    return;
  }

  async grabCameraImage(
    options: GrabCameraImageOptions,
  ): Promise<undefined | GrabCameraImageResult> {
    console.warn(
      'MediaCaptureWeb.grabCameraImage() is not implemented on this platform.',
      options,
    );

    return;
  }

  // MICROPHONE

  async startMicrophoneSession(
    options: MicrophoneSessionOptions,
  ): Promise<boolean> {
    console.warn(
      'MediaCaptureWeb.startMicrophoneSession() is not implemented on this platform.',
      options,
    );

    return false;
  }

  async stopMicrophoneSession(): Promise<boolean> {
    console.warn(
      'MediaCaptureWeb.stopMicrophoneSession() is not implemented on this platform.',
    );

    return false;
  }
  async startMicrophoneRecording(
    options: StartMicrophoneRecordingOptions,
  ): Promise<boolean> {
    console.warn(
      'MediaCaptureWeb.startMicrophoneRecording() is not implemented on this platform.',
      options,
    );

    return false;
  }

  async stopMicrophoneRecording(): Promise<
    undefined | MicrophoneRecordingResult
  > {
    console.warn(
      'MediaCaptureWeb.stopMicrophoneRecording() is not implemented on this platform.',
    );

    return;
  }
}
