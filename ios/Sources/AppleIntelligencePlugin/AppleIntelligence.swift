import Foundation
import UIKit

#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(ImagePlayground)
import ImagePlayground
#endif

// MARK: - Error Types

/// Error codes for Apple Intelligence plugin
public enum AppleIntelligenceErrorCode: String {
    case invalidJson = "INVALID_JSON"
    case schemaMismatch = "SCHEMA_MISMATCH"
    case unavailable = "UNAVAILABLE"
    case nativeError = "NATIVE_ERROR"
}

/// Custom error type for Apple Intelligence operations
public struct AppleIntelligenceError: Error {
    public let code: AppleIntelligenceErrorCode
    public let message: String
    
    public init(code: AppleIntelligenceErrorCode, message: String) {
        self.code = code
        self.message = message
    }
    
    public var asDictionary: [String: Any] {
        return [
            "code": code.rawValue,
            "message": message
        ]
    }
}

// MARK: - Message Types

/// Role for a message in the conversation
public enum MessageRole: String {
    case system
    case user
}

/// A message in the conversation
public struct Message {
    public let role: MessageRole
    public let content: String
    
    public init(role: MessageRole, content: String) {
        self.role = role
        self.content = content
    }
}

// MARK: - Image Generation Options

/// Configuration options for image generation
public struct ImageGenerationOptions {
    /// JPEG compression quality (0.0 to 1.0)
    public let compressionQuality: CGFloat
    /// Maximum dimension for the output image
    public let maxDimension: CGFloat?
    /// Output format
    public let format: ImageFormat
    
    public enum ImageFormat {
        case png
        case jpeg
    }
    
    public static let `default` = ImageGenerationOptions(
        compressionQuality: 0.8,
        maxDimension: 1024,
        format: .jpeg
    )
    
    public init(compressionQuality: CGFloat = 0.8, maxDimension: CGFloat? = 1024, format: ImageFormat = .jpeg) {
        self.compressionQuality = min(1.0, max(0.0, compressionQuality))
        self.maxDimension = maxDimension
        self.format = format
    }
}

// MARK: - Main Implementation

/// Apple Intelligence implementation class
/// Handles on-device LLM generation with JSON schema validation
@objc public class AppleIntelligence: NSObject {
    
    // MARK: - Constants
    
    private let maxRetries = 1
    private let maxImageCount = 10
    private let minImageCount = 1
    
    // MARK: - Task Management
    
    /// Currently running generation tasks for cancellation support
    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    private let taskLock = NSLock()
    
    /// Cancel all active generation tasks
    public func cancelAllTasks() {
        taskLock.lock()
        defer { taskLock.unlock() }
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }
    
    /// Register a task for tracking
    private func registerTask(_ task: Task<Void, Never>) -> UUID {
        let id = UUID()
        taskLock.lock()
        activeTasks[id] = task
        taskLock.unlock()
        return id
    }
    
    /// Unregister a completed task
    private func unregisterTask(_ id: UUID) {
        taskLock.lock()
        activeTasks.removeValue(forKey: id)
        taskLock.unlock()
    }
    
    // MARK: - Helper Methods
    
    /// Convert schema dictionary to JSON string
    private func schemaToString(_ schema: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: schema, options: [.prettyPrinted, .sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }
    
    /// Parse message dictionaries into Message objects
    public func parseMessages(_ messages: [[String: String]]) -> [Message]? {
        let parsed = messages.compactMap { dict -> Message? in
            guard let roleStr = dict["role"],
                  let content = dict["content"],
                  let role = MessageRole(rawValue: roleStr) else { return nil }
            return Message(role: role, content: content)
        }
        return parsed.isEmpty ? nil : parsed
    }
    
    /// Safely escape string for JSON embedding
    private func escapeForJson(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: string, options: []),
              let escaped = String(data: data, encoding: .utf8) else {
            // Fallback: basic escaping
            return string
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")
        }
        // Remove surrounding quotes from JSON string serialization
        return String(escaped.dropFirst().dropLast())
    }
    
    /// Get full language name from locale code
    private func fullLanguageName(from code: String) -> String {
        // First try to get from system locale
        if let name = Locale.current.localizedString(forLanguageCode: code.lowercased()) {
            return name
        }
        
        // Fallback map for common codes
        let fallbackMap: [String: String] = [
            "en": "English",
            "es": "Spanish",
            "fr": "French",
            "de": "German",
            "ja": "Japanese",
            "zh": "Chinese",
            "it": "Italian",
            "pt": "Portuguese",
            "ru": "Russian",
            "ar": "Arabic",
            "ko": "Korean",
            "nl": "Dutch",
            "pl": "Polish",
            "tr": "Turkish",
            "vi": "Vietnamese",
            "th": "Thai",
            "hi": "Hindi",
            "he": "Hebrew",
            "id": "Indonesian",
            "ms": "Malay",
            "sv": "Swedish",
            "da": "Danish",
            "no": "Norwegian",
            "fi": "Finnish",
            "cs": "Czech",
            "el": "Greek",
            "hu": "Hungarian",
            "ro": "Romanian",
            "uk": "Ukrainian"
        ]
        
        return fallbackMap[code.lowercased()] ?? code
    }
    
    // MARK: - JSON Schema Validation
    
    /// Validate JSON data against a JSON schema
    private func validateAgainstSchema(_ json: Any, schema: [String: Any]) -> (valid: Bool, error: String?) {
        guard let schemaType = schema["type"] as? String else {
            return (false, "Schema missing 'type' property")
        }
        
        switch schemaType {
        case "object":
            return validateObject(json, schema: schema)
        case "array":
            return validateArray(json, schema: schema)
        case "string":
            return (json is String, json is String ? nil : "Expected string, got \(type(of: json))")
        case "number", "integer":
            return validateNumber(json)
        case "boolean":
            return validateBoolean(json)
        case "null":
            return (json is NSNull, json is NSNull ? nil : "Expected null, got \(type(of: json))")
        default:
            return (false, "Unknown schema type: \(schemaType)")
        }
    }
    
    /// Validate a number value (ensuring it's not actually a boolean)
    private func validateNumber(_ json: Any) -> (valid: Bool, error: String?) {
        guard let number = json as? NSNumber else {
            return (false, "Expected number, got \(type(of: json))")
        }
        
        // Use CFGetTypeID to properly distinguish booleans from numbers
        let boolID = CFBooleanGetTypeID()
        let typeID = CFGetTypeID(number as CFTypeRef)
        
        if typeID == boolID {
            return (false, "Expected number, got boolean")
        }
        
        return (true, nil)
    }
    
    /// Validate a boolean value
    private func validateBoolean(_ json: Any) -> (valid: Bool, error: String?) {
        guard let number = json as? NSNumber else {
            return (false, "Expected boolean, got \(type(of: json))")
        }
        
        // Use CFGetTypeID to properly identify booleans
        let boolID = CFBooleanGetTypeID()
        let typeID = CFGetTypeID(number as CFTypeRef)
        
        if typeID == boolID {
            return (true, nil)
        }
        
        return (false, "Expected boolean, got number")
    }
    
    /// Validate an object against a schema
    private func validateObject(_ json: Any, schema: [String: Any]) -> (valid: Bool, error: String?) {
        guard let jsonObject = json as? [String: Any] else {
            return (false, "Expected object, got \(type(of: json))")
        }
        
        // Check required properties
        if let required = schema["required"] as? [String] {
            for requiredProp in required {
                if jsonObject[requiredProp] == nil {
                    return (false, "Missing required property: '\(requiredProp)'")
                }
            }
        }
        
        // Validate properties against their schemas
        if let properties = schema["properties"] as? [String: Any] {
            for (key, value) in jsonObject {
                if let propSchema = properties[key] as? [String: Any] {
                    let result = validateAgainstSchema(value, schema: propSchema)
                    if !result.valid {
                        return (false, "Property '\(key)': \(result.error ?? "validation failed")")
                    }
                }
            }
        }
        
        return (true, nil)
    }
    
    /// Validate an array against a schema
    private func validateArray(_ json: Any, schema: [String: Any]) -> (valid: Bool, error: String?) {
        guard let jsonArray = json as? [Any] else {
            return (false, "Expected array, got \(type(of: json))")
        }
        
        // Validate items against item schema
        if let itemSchema = schema["items"] as? [String: Any] {
            for (index, item) in jsonArray.enumerated() {
                let result = validateAgainstSchema(item, schema: itemSchema)
                if !result.valid {
                    return (false, "Item at index \(index): \(result.error ?? "validation failed")")
                }
            }
        }
        
        // Validate minItems
        if let minItems = schema["minItems"] as? Int {
            if jsonArray.count < minItems {
                return (false, "Array has \(jsonArray.count) items, minimum is \(minItems)")
            }
        }
        
        // Validate maxItems
        if let maxItems = schema["maxItems"] as? Int {
            if jsonArray.count > maxItems {
                return (false, "Array has \(jsonArray.count) items, maximum is \(maxItems)")
            }
        }
        
        return (true, nil)
    }
    
    // MARK: - Prompt Building
    
    /// Build the system prompt with JSON schema instructions
    private func buildSystemPrompt(userSystemPrompt: String?, schema: [String: Any]) -> String {
        let schemaJson = schemaToString(schema)
        
        var prompt = """
        You are a JSON generator. Your response must be ONLY valid JSON that matches the provided schema.
        
        SCHEMA:
        \(schemaJson)
        
        RULES:
        1. Return ONLY the JSON object or array - nothing else
        2. Do NOT wrap the response in markdown code blocks (no ```)
        3. Do NOT include any comments
        4. Do NOT include any explanations before or after the JSON
        5. The JSON must be valid and parseable
        6. All required properties must be present
        7. Property types must match the schema exactly
        
        """
        
        if let userSystem = userSystemPrompt, !userSystem.isEmpty {
            prompt += "\nADDITIONAL CONTEXT:\n\(userSystem)\n"
        }
        
        return prompt
    }
    
    /// Build corrective prompt for retry attempts
    private func buildCorrectivePrompt(previousResponse: String, validationError: String, schema: [String: Any]) -> String {
        let schemaJson = schemaToString(schema)
        
        return """
        The previous response was invalid JSON or did not match the required schema.
        
        PREVIOUS RESPONSE:
        \(previousResponse)
        
        ERROR:
        \(validationError)
        
        REQUIRED SCHEMA:
        \(schemaJson)
        
        Fix the response and return ONLY valid JSON matching the schema. No explanations, no markdown, just the JSON.
        """
    }
    
    // MARK: - Availability Check
    
    /// Check if Apple Intelligence is available on this device
    public func checkAvailability() -> (available: Bool, error: AppleIntelligenceError?) {
        // Runtime check for iOS 26+
        if #available(iOS 26, *) {
            // Foundation Models framework is available
            // Additional runtime check for Apple Intelligence capability would go here
            return (true, nil)
        } else {
            return (false, AppleIntelligenceError(
                code: .unavailable,
                message: "Apple Intelligence requires iOS 26 or later. Current device is running an earlier version."
            ))
        }
    }
    
    // MARK: - Generation
    
    /// Parse raw text response as JSON
    private func parseJsonResponse(_ text: String) -> Result<Any, AppleIntelligenceError> {
        // Clean the response - remove any markdown code blocks if present
        var cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if they exist
        if cleanedText.hasPrefix("```json") {
            cleanedText = String(cleanedText.dropFirst(7))
        } else if cleanedText.hasPrefix("```") {
            cleanedText = String(cleanedText.dropFirst(3))
        }
        
        if cleanedText.hasSuffix("```") {
            cleanedText = String(cleanedText.dropLast(3))
        }
        
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedText.data(using: .utf8) else {
            return .failure(AppleIntelligenceError(
                code: .invalidJson,
                message: "Failed to convert response to UTF-8 data"
            ))
        }
        
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return .success(json)
        } catch {
            return .failure(AppleIntelligenceError(
                code: .invalidJson,
                message: "Invalid JSON: \(error.localizedDescription)"
            ))
        }
    }
    
    /// Generate structured JSON output using Apple Intelligence
    /// - Parameters:
    ///   - messages: Array of conversation messages
    ///   - schema: JSON schema the output must conform to
    /// - Returns: Result containing parsed JSON or error
    @available(iOS 26, *)
    public func generate(
        messages: [Message],
        schema: [String: Any]
    ) async -> Result<Any, AppleIntelligenceError> {
        // Check for task cancellation
        if Task.isCancelled {
            return .failure(AppleIntelligenceError(
                code: .nativeError,
                message: "Generation was cancelled"
            ))
        }
        
        // Extract system and user messages
        let systemMessages = messages.filter { $0.role == .system }.map { $0.content }
        let userMessages = messages.filter { $0.role == .user }.map { $0.content }
        
        let userSystemPrompt = systemMessages.joined(separator: "\n")
        let userQuery = userMessages.joined(separator: "\n")
        
        // Build the full system prompt with schema
        let systemPrompt = buildSystemPrompt(userSystemPrompt: userSystemPrompt, schema: schema)
        
        // First attempt
        var lastResponse = ""
        var lastError = ""
        
        for attempt in 0...maxRetries {
            // Check for cancellation between attempts
            if Task.isCancelled {
                return .failure(AppleIntelligenceError(
                    code: .nativeError,
                    message: "Generation was cancelled"
                ))
            }
            
            do {
                let response: String
                
                if attempt == 0 {
                    response = try await callLanguageModel(
                        systemPrompt: systemPrompt,
                        userPrompt: userQuery
                    )
                } else {
                    // Retry with corrective prompt
                    let correctivePrompt = buildCorrectivePrompt(
                        previousResponse: lastResponse,
                        validationError: lastError,
                        schema: schema
                    )
                    response = try await callLanguageModel(
                        systemPrompt: systemPrompt,
                        userPrompt: correctivePrompt
                    )
                }
                
                lastResponse = response
                
                // Parse JSON
                let parseResult = parseJsonResponse(response)
                switch parseResult {
                case .success(let json):
                    // Validate against schema
                    let validation = validateAgainstSchema(json, schema: schema)
                    if validation.valid {
                        return .success(json)
                    } else {
                        lastError = validation.error ?? "Schema validation failed"
                        if attempt == maxRetries {
                            return .failure(AppleIntelligenceError(
                                code: .schemaMismatch,
                                message: "Schema validation failed after \(maxRetries + 1) attempts: \(lastError)"
                            ))
                        }
                    }
                case .failure(let error):
                    lastError = error.message
                    if attempt == maxRetries {
                        return .failure(error)
                    }
                }
            } catch {
                return .failure(AppleIntelligenceError(
                    code: .nativeError,
                    message: "Generation failed: \(error.localizedDescription)"
                ))
            }
        }
        
        return .failure(AppleIntelligenceError(
            code: .nativeError,
            message: "Generation failed after all retry attempts"
        ))
    }
    
    /// Call the on-device language model
    /// - Parameters:
    ///   - systemPrompt: The system instructions
    ///   - userPrompt: The user query
    /// - Returns: The model's text response
    @available(iOS 26, *) 
    private func callLanguageModel(systemPrompt: String, userPrompt: String) async throws -> String {
        #if canImport(FoundationModels)
        // Create a language model session
        let session = LanguageModelSession()
        
        // Build the prompt combining system and user messages
        let fullPrompt = """
        \(systemPrompt)
        
        USER REQUEST:
        \(userPrompt)
        """
        
        // Get response from the model
        let response = try await session.respond(to: fullPrompt)
        return response.content
        
        #else
        // Mock fallback for development/testing
        if systemPrompt.contains("You are a JSON generator") {
            // JSON mock for generate() calls - using proper JSON escaping
            let escapedQuery = escapeForJson(userPrompt)
            return """
            {
                "mock_response": "This is a mocked JSON response from Apple Intelligence (Runtime not available)",
                "original_query": "\(escapedQuery)"
            }
            """
        } else {
            // Return plain text for generateText() calls
            return "This is a mocked response from Apple Intelligence (Runtime not available). User query was: \(userPrompt)"
        }
        #endif
    }

    // MARK: - Bridge Helpers
    
    /// Generate method that returns a dictionary suitable for Capacitor bridge
    @available(iOS 26, *)
    public func generateForBridge(
        messages: [[String: String]],
        schema: [String: Any]
    ) async -> [String: Any] {
        guard let parsedMessages = parseMessages(messages) else {
            return [
                "success": false,
                "error": AppleIntelligenceError(
                    code: .nativeError,
                    message: "No valid messages provided"
                ).asDictionary
            ]
        }
        
        let result = await generate(messages: parsedMessages, schema: schema)
        
        switch result {
        case .success(let data):
            return [
                "success": true,
                "data": data
            ]
        case .failure(let error):
            return [
                "success": false,
                "error": error.asDictionary
            ]
        }
    }
    
    /// Generate plain text output using Apple Intelligence
    /// - Parameters:
    ///   - messages: Array of conversation messages
    /// - Returns: Result containing generated text or error
    @available(iOS 26, *)
    public func generateText(
        messages: [Message]
    ) async -> Result<String, AppleIntelligenceError> {
        // Check for task cancellation
        if Task.isCancelled {
            return .failure(AppleIntelligenceError(
                code: .nativeError,
                message: "Generation was cancelled"
            ))
        }
        
        let systemMessages = messages.filter { $0.role == .system }.map { $0.content }
        let userMessages = messages.filter { $0.role == .user }.map { $0.content }
        
        let systemPrompt = systemMessages.joined(separator: "\n")
        let userQuery = userMessages.joined(separator: "\n")
        
        do {
            let response = try await callLanguageModel(
                systemPrompt: systemPrompt,
                userPrompt: userQuery
            )
            return .success(response)
        } catch {
            return .failure(AppleIntelligenceError(
                code: .nativeError,
                message: "Generation failed: \(error.localizedDescription)"
            ))
        }
    }

    /// Generate plain text output with specific language
    /// - Parameters:
    ///   - messages: Array of conversation messages
    ///   - language: Target language for the response
    /// - Returns: Result containing generated text or error
    @available(iOS 26, *)
    public func generateTextWithLanguage(
        messages: [Message],
        language: String
    ) async -> Result<String, AppleIntelligenceError> {
        // Check for task cancellation
        if Task.isCancelled {
            return .failure(AppleIntelligenceError(
                code: .nativeError,
                message: "Generation was cancelled"
            ))
        }
        
        let systemMessages = messages.filter { $0.role == .system }.map { $0.content }
        let userMessages = messages.filter { $0.role == .user }.map { $0.content }
        
        // Get full language name dynamically
        let fullLanguageName = fullLanguageName(from: language)
        
        var systemPrompt = systemMessages.joined(separator: "\n")
        // Append language instruction
        if !systemPrompt.isEmpty {
            systemPrompt += "\n\n"
        }
        systemPrompt += "IMPORTANT: You must respond ONLY in \(fullLanguageName). Do not use any other language."
        
        let userQuery = userMessages.joined(separator: "\n")
        
        do {
            let response = try await callLanguageModel(
                systemPrompt: systemPrompt,
                userPrompt: userQuery
            )
            return .success(response)
        } catch {
            return .failure(AppleIntelligenceError(
                code: .nativeError,
                message: "Generation failed: \(error.localizedDescription)"
            ))
        }
    }
    
    /// Generate text bridge helper
    @available(iOS 26, *)
    public func generateTextForBridge(
        messages: [[String: String]]
    ) async -> [String: Any] {
        guard let parsedMessages = parseMessages(messages) else {
            return [
                "success": false,
                "error": AppleIntelligenceError(
                    code: .nativeError,
                    message: "No valid messages provided"
                ).asDictionary
            ]
        }
        
        let result = await generateText(messages: parsedMessages)
        
        switch result {
        case .success(let content):
            return [
                "success": true,
                "content": content
            ]
        case .failure(let error):
            return [
                "success": false,
                "error": error.asDictionary
            ]
        }
    }

    /// Generate text with language bridge helper
    @available(iOS 26, *)
    public func generateTextWithLanguageForBridge(
        messages: [[String: String]],
        language: String
    ) async -> [String: Any] {
        guard let parsedMessages = parseMessages(messages) else {
            return [
                "success": false,
                "error": AppleIntelligenceError(
                    code: .nativeError,
                    message: "No valid messages provided"
                ).asDictionary
            ]
        }
        
        let result = await generateTextWithLanguage(messages: parsedMessages, language: language)
        
        switch result {
        case .success(let content):
            return [
                "success": true,
                "content": content
            ]
        case .failure(let error):
            return [
                "success": false,
                "error": error.asDictionary
            ]
        }
    }
    
    // MARK: - Image Generation
    
    /// Supported image styles for Apple's on-device Image Playground
    /// Note: Photorealistic images are NOT supported by Apple's on-device API
    public static let supportedImageStyles = ["animation", "illustration", "sketch"]
    
    /// Generate images using Apple Intelligence
    /// - Parameters:
    ///   - prompt: Description of the image
    ///   - style: Style for the image. Supported values: "animation" (default), "illustration", "sketch".
    ///            Note: "photorealistic" and other styles are NOT supported by Apple's on-device Image Playground API.
    ///   - count: Number of images (clamped to 1-10)
    ///   - sourceImage: Optional source image for face-based generation. Required when prompt involves generating images of people.
    ///   - options: Image generation options for compression and sizing
    /// - Returns: Result containing array of base64 image strings or error
    @available(iOS 26, *)
    public func generateImage(
        prompt: String,
        style: String?,
        count: Int,
        sourceImage: UIImage? = nil,
        options: ImageGenerationOptions = .default
    ) async -> Result<[String], AppleIntelligenceError> {
        // Check for task cancellation
        if Task.isCancelled {
            return .failure(AppleIntelligenceError(
                code: .nativeError,
                message: "Image generation was cancelled"
            ))
        }
        
        // Validate style parameter
        if let styleStr = style?.lowercased(), !styleStr.isEmpty {
            if !Self.supportedImageStyles.contains(styleStr) {
                return .failure(AppleIntelligenceError(
                    code: .nativeError,
                    message: "Unsupported image style: '\(style ?? "")'. Apple's on-device Image Playground only supports: \(Self.supportedImageStyles.joined(separator: ", ")). Note: Photorealistic images are not supported by Apple's native API."
                ))
            }
        }
        
        // Validate and clamp count
        let validatedCount = max(minImageCount, min(count, maxImageCount))
        
        #if canImport(ImagePlayground)
        do {
            let creator = try await ImageCreator()
            
            // Build concepts array
            var concepts: [ImagePlaygroundConcept] = [.text(prompt)]
            
            // If source image provided, save to temp URL and add as image concept
            if let source = sourceImage, let jpegData = source.jpegData(compressionQuality: 0.9) {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("source_\(UUID().uuidString).jpg")
                try jpegData.write(to: tempURL)
                if let imageConcept = ImagePlaygroundConcept.image(tempURL) {
                    concepts.append(imageConcept)
                }
            }
            
            // Map style string to ImagePlaygroundStyle enum
            let imageStyle: ImagePlaygroundStyle
            switch style?.lowercased() {
            case "illustration": imageStyle = .illustration
            case "sketch": imageStyle = .sketch
            default: imageStyle = .animation  // Default to animation
            }
            
            var base64Images: [String] = []
            
            for try await createdImage in creator.images(for: concepts, style: imageStyle, limit: validatedCount) {
                // Check for cancellation during image generation
                if Task.isCancelled {
                    return .failure(AppleIntelligenceError(
                        code: .nativeError,
                        message: "Image generation was cancelled"
                    ))
                }
                
                var uiImage = UIImage(cgImage: createdImage.cgImage)
                
                // Resize if needed
                if let maxDim = options.maxDimension {
                    uiImage = resizeImage(uiImage, maxDimension: maxDim)
                }
                
                // Compress based on format
                let data: Data?
                switch options.format {
                case .png:
                    data = uiImage.pngData()
                case .jpeg:
                    data = uiImage.jpegData(compressionQuality: options.compressionQuality)
                }
                
                if let imageData = data {
                    base64Images.append(imageData.base64EncodedString())
                }
            }
            
            if base64Images.isEmpty {
                return .failure(AppleIntelligenceError(code: .nativeError, message: "No images were generated"))
            }
            return .success(base64Images)
        } catch let error as NSError {
            // Provide more helpful error message for face-related errors
            let errorMessage = error.localizedDescription
            if errorMessage.lowercased().contains("face") || errorMessage.lowercased().contains("person") || errorMessage.lowercased().contains("source image") {
                return .failure(AppleIntelligenceError(
                    code: .nativeError,
                    message: "This prompt requires generating images of people. Please provide a source image containing a face using the 'sourceImage' parameter, or modify your prompt to avoid generating human faces."
                ))
            }
            return .failure(AppleIntelligenceError(code: .nativeError, message: "Image generation failed: \(errorMessage)"))
        }
        #else
        return .failure(AppleIntelligenceError(code: .unavailable, message: "ImagePlayground not available"))
        #endif
    }
    
    /// Resize image to fit within maximum dimension while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        // Check if resizing is needed
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }
        
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Generate image bridge helper
    @available(iOS 26, *)
    public func generateImageForBridge(
        prompt: String,
        style: String?,
        count: Int,
        sourceImageBase64: String? = nil,
        compressionQuality: CGFloat? = nil
    ) async -> [String: Any] {
        let options = ImageGenerationOptions(
            compressionQuality: compressionQuality ?? 0.8,
            maxDimension: 1024,
            format: .jpeg
        )
        
        // Decode source image from base64 if provided
        var sourceImage: UIImage? = nil
        if let base64String = sourceImageBase64,
           let imageData = Data(base64Encoded: base64String) {
            sourceImage = UIImage(data: imageData)
        }
        
        let result = await generateImage(prompt: prompt, style: style, count: count, sourceImage: sourceImage, options: options)
        
        switch result {
        case .success(let images):
            return [
                "success": true,
                "images": images
            ]
        case .failure(let error):
            return [
                "success": false,
                "error": error.asDictionary
            ]
        }
    }
}
