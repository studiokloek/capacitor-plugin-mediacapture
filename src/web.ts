import { WebPlugin } from '@capacitor/core';

import type {
  MediaCapturePlugin,
  MediaCapturePorts,
  OutputOverrideType,
} from './definitions';

export class MediaCaptureWeb extends WebPlugin implements MediaCapturePlugin {
  async currentOutputs(): Promise<MediaCapturePorts[]> {
    console.log(
      'MediaCapturePlugin.currentOutputs()',
      'only available on a iOS device.',
    );

    return [];
  }

  async overrideOutput(type: OutputOverrideType): Promise<boolean> {
    console.log(
      `MediaCapturePlugin.currentOutputs(${type})`,
      'only available on a iOS device.',
    );

    return false;
  }
}
