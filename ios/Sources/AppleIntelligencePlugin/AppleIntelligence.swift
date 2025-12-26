import Foundation

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

// MARK: - Main Implementation

/// Apple Intelligence implementation class
/// Handles on-device LLM generation with JSON schema validation
@objc public class AppleIntelligence: NSObject {
    
    // MARK: - Constants
    
    private let maxRetries = 1
    
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
            return (json is NSNumber && !(json is Bool), 
                    (json is NSNumber && !(json is Bool)) ? nil : "Expected number, got \(type(of: json))")
        case "boolean":
            return (json is Bool, json is Bool ? nil : "Expected boolean, got \(type(of: json))")
        case "null":
            return (json is NSNull, json is NSNull ? nil : "Expected null, got \(type(of: json))")
        default:
            return (false, "Unknown schema type: \(schemaType)")
        }
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
        let schemaJson: String
        do {
            let schemaData = try JSONSerialization.data(withJSONObject: schema, options: [.prettyPrinted, .sortedKeys])
            schemaJson = String(data: schemaData, encoding: .utf8) ?? "{}"
        } catch {
            schemaJson = "{}"
        }
        
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
        let schemaJson: String
        do {
            let schemaData = try JSONSerialization.data(withJSONObject: schema, options: [.prettyPrinted, .sortedKeys])
            schemaJson = String(data: schemaData, encoding: .utf8) ?? "{}"
        } catch {
            schemaJson = "{}"
        }
        
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
    @objc public func checkAvailability() -> (available: Bool, error: AppleIntelligenceError?) {
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
        // Import Foundation Models at runtime
        // Note: This uses the new Foundation Models framework available in iOS 26+
        
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
        // Import Foundation Models framework
        // This framework provides access to the on-device LLM powering Apple Intelligence
        
        #if canImport(FoundationModels)
        import FoundationModels
        
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
        // Fallback for development/testing when FoundationModels isn't available
        // This should never be reached on iOS 26+ devices
        throw AppleIntelligenceError(
            code: .unavailable,
            message: "FoundationModels framework not available"
        )
        #endif
    }
    
    /// Generate method that returns a dictionary suitable for Capacitor bridge
    @available(iOS 26, *)
    public func generateForBridge(
        messages: [[String: String]],
        schema: [String: Any]
    ) async -> [String: Any] {
        // Convert raw dictionaries to Message objects
        let parsedMessages = messages.compactMap { dict -> Message? in
            guard let roleStr = dict["role"],
                  let content = dict["content"],
                  let role = MessageRole(rawValue: roleStr) else {
                return nil
            }
            return Message(role: role, content: content)
        }
        
        if parsedMessages.isEmpty {
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
        let systemMessages = messages.filter { $0.role == .system }.map { $0.content }
        let userMessages = messages.filter { $0.role == .user }.map { $0.content }
        
        var systemPrompt = systemMessages.joined(separator: "\n")
        // Append language instruction
        if !systemPrompt.isEmpty {
            systemPrompt += "\n\n"
        }
        systemPrompt += "Please respond in \(language)."
        
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
        let parsedMessages = messages.compactMap { dict -> Message? in
            guard let roleStr = dict["role"],
                  let content = dict["content"],
                  let role = MessageRole(rawValue: roleStr) else {
                return nil
            }
            return Message(role: role, content: content)
        }
        
        if parsedMessages.isEmpty {
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
        let parsedMessages = messages.compactMap { dict -> Message? in
            guard let roleStr = dict["role"],
                  let content = dict["content"],
                  let role = MessageRole(rawValue: roleStr) else {
                return nil
            }
            return Message(role: role, content: content)
        }
        
        if parsedMessages.isEmpty {
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
}
