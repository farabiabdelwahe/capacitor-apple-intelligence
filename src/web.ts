import { WebPlugin } from '@capacitor/core';

import type { AppleIntelligencePlugin, GenerateRequest, GenerateResponse } from './definitions';

/**
 * Web implementation stub for Apple Intelligence.
 * Always returns UNAVAILABLE since Apple Intelligence is iOS-only.
 */
export class AppleIntelligenceWeb extends WebPlugin implements AppleIntelligencePlugin {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async generate(_request: GenerateRequest): Promise<GenerateResponse> {
    return {
      success: false,
      error: {
        code: 'UNAVAILABLE',
        message: 'Apple Intelligence is only available on iOS 26+ devices with Apple Intelligence enabled.',
      },
    };
  }

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async generateText(_request: unknown): Promise<any> {
    return {
      success: false,
      error: {
        code: 'UNAVAILABLE',
        message: 'Apple Intelligence is only available on iOS 26+ devices with Apple Intelligence enabled.',
      },
    };
  }

  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async generateTextWithLanguage(_request: unknown): Promise<any> {
    return {
      success: false,
      error: {
        code: 'UNAVAILABLE',
        message: 'Apple Intelligence is only available on iOS 26+ devices with Apple Intelligence enabled.',
      },
    };
  }

  async checkAvailability(): Promise<any> {
    return {
      available: false,
      error: {
        code: 'UNAVAILABLE',
        message: 'Apple Intelligence is only available on iOS 26+ devices with Apple Intelligence enabled.',
      },
    };
  }
}
