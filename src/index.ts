import { registerPlugin } from '@capacitor/core';

import type { AppleIntelligencePlugin } from './definitions';

/**
 * Apple Intelligence Plugin instance.
 *
 * Provides schema-constrained JSON generation using Apple's on-device
 * Foundation Models framework.
 *
 * @example
 * ```typescript
 * import { AppleIntelligence } from 'capacitor-apple-intelligence';
 *
 * const result = await AppleIntelligence.generate({
 *   messages: [{ role: "user", content: "Suggest 3 books" }],
 *   response_format: {
 *     type: "json_schema",
 *     schema: {
 *       type: "array",
 *       items: {
 *         type: "object",
 *         properties: {
 *           title: { type: "string" },
 *           author: { type: "string" }
 *         },
 *         required: ["title", "author"]
 *       }
 *     }
 *   }
 * });
 * ```
 */
const AppleIntelligence = registerPlugin<AppleIntelligencePlugin>('AppleIntelligence', {
  web: () => import('./web').then((m) => new m.AppleIntelligenceWeb()),
});

export * from './definitions';
export { AppleIntelligence };
