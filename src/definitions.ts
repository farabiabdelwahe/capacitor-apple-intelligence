/**
 * Apple Intelligence Plugin for Capacitor v8
 *
 * Provides schema-constrained JSON generation using Apple's on-device
 * Foundation Models framework, behaving like Groq/Gemini response_format: json_object.
 *
 * @module capacitor-apple-intelligence
 */

/**
 * Message role for conversation history.
 */
export type MessageRole = 'system' | 'user';

/**
 * A message in the conversation.
 */
export interface Message {
    /**
     * The role of the message sender.
     * - 'system': Instructions for the AI model
     * - 'user': User input/queries
     */
    role: MessageRole;

    /**
     * The text content of the message.
     */
    content: string;
}

/**
 * JSON Schema response format specification.
 */
export interface ResponseFormat {
    /**
     * The type of response format. Must be 'json_schema'.
     */
    type: 'json_schema';

    /**
     * The JSON schema that the model output must conform to.
     * Supports standard JSON Schema properties including:
     * - type: 'object' | 'array' | 'string' | 'number' | 'boolean' | 'null'
     * - properties: Object defining property schemas
     * - required: Array of required property names
     * - items: Schema for array items
     */
    schema: Record<string, unknown>;
}

/**
 * Request payload for the generate method.
 */
export interface GenerateRequest {
    /**
     * Array of messages forming the conversation context.
     * Should include system messages for instructions and
     * user messages for the actual query.
     */
    messages: Message[];

    /**
     * Response format specification requiring JSON schema compliance.
     */
    response_format: ResponseFormat;
}

/**
 * Error codes returned by the plugin.
 */
export type ErrorCode = 'INVALID_JSON' | 'SCHEMA_MISMATCH' | 'UNAVAILABLE' | 'NATIVE_ERROR';

/**
 * Structured error object returned on failure.
 */
export interface GenerateError {
    /**
     * Error code for programmatic handling.
     * - INVALID_JSON: Model output was not valid JSON
     * - SCHEMA_MISMATCH: JSON valid but doesn't match provided schema
     * - UNAVAILABLE: iOS version < 26 or Apple Intelligence not available
     * - NATIVE_ERROR: Other Swift/Foundation Models errors
     */
    code: ErrorCode;

    /**
     * Human-readable error message.
     */
    message: string;
}

/**
 * Response from the generate method.
 */
export interface GenerateResponse {
    /**
     * Whether the generation was successful.
     */
    success: boolean;

    /**
     * The parsed JSON data on success.
     * The structure will match the provided schema.
     */
    data?: unknown;

    /**
     * Error details on failure.
     * Only present when success is false.
     */
    error?: GenerateError;
}

/**
 * Apple Intelligence Plugin interface.
 *
 * Provides access to Apple's on-device Foundation Models for
 * schema-constrained JSON generation.
 */
export interface AppleIntelligencePlugin {
    /**
     * Generate structured JSON output using Apple Intelligence.
     *
     * This method:
     * 1. Injects the JSON schema into the system prompt
     * 2. Instructs the model to return ONLY valid JSON
     * 3. Validates the output against the provided schema
     * 4. Retries once on validation failure
     *
     * @param request - The generation request containing messages and schema
     * @returns Promise resolving to a structured response with success/error
     *
     * @example
     * ```typescript
     * const result = await AppleIntelligence.generate({
     *   messages: [
     *     { role: "system", content: "You are a helpful assistant." },
     *     { role: "user", content: "List 3 fruits" }
     *   ],
     *   response_format: {
     *     type: "json_schema",
     *     schema: {
     *       type: "array",
     *       items: {
     *         type: "object",
     *         properties: {
     *           name: { type: "string" },
     *           color: { type: "string" }
     *         },
     *         required: ["name", "color"]
     *       }
     *     }
     *   }
     * });
     *
     * if (result.success) {
     *   console.log(result.data);
     *   // [{ name: "Apple", color: "red" }, ...]
     * }
     * ```
     */
    generate(request: GenerateRequest): Promise<GenerateResponse>;

    /**
     * Generate plain text output using Apple Intelligence.
     * 
     * @param request - The generation request containing messages
     * @returns Promise resolving to a text response with success/error
     */
    generateText(request: GenerateTextRequest): Promise<GenerateTextResponse>;

    /**
     * Generate plain text output using Apple Intelligence with a specific target language.
     * 
     * @param request - The generation request containing messages and target language
     * @returns Promise resolving to a text response with success/error
     */
    generateTextWithLanguage(request: GenerateTextWithLanguageRequest): Promise<GenerateTextResponse>;

    /**
     * Check if Apple Intelligence is available on this device.
     * 
     * @returns Promise resolving to availability status
     */
    checkAvailability(): Promise<AvailabilityResponse>;
}

/**
 * Request payload for text generation.
 */
export interface GenerateTextRequest {
    /**
     * Array of messages forming the conversation context.
     */
    messages: Message[];
}

/**
 * Request payload for text generation with language.
 */
export interface GenerateTextWithLanguageRequest {
    /**
     * Array of messages forming the conversation context.
     */
    messages: Message[];

    /**
     * Target language for the response (e.g., "English", "Spanish", "French").
     */
    language: string;
}

/**
 * Response for text generation.
 */
export interface GenerateTextResponse {
    /**
     * Whether the generation was successful.
     */
    success: boolean;

    /**
     * The generated text content on success.
     */
    content?: string;

    /**
     * Error details on failure.
     * Only present when success is false.
     */
    error?: GenerateError;
}

/**
 * Response for availability check.
 */
export interface AvailabilityResponse {
    /**
     * Whether Apple Intelligence is available on this device.
     */
    available: boolean;

    /**
     * Error details if unavailable.
     */
    error?: GenerateError;
}
