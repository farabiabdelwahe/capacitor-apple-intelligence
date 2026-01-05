import Foundation
import Capacitor

/// Capacitor plugin class for Apple Intelligence
/// Bridges JavaScript calls to the native AppleIntelligence implementation
@MainActor
@objc(AppleIntelligencePlugin)
public class AppleIntelligencePlugin: CAPPlugin, CAPBridgedPlugin {
    
    // MARK: - Plugin Configuration
    
    public let identifier = "AppleIntelligencePlugin"
    public let jsName = "AppleIntelligence"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "generate", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "generateText", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "generateTextWithLanguage", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "generateImage", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "checkAvailability", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "cancelAllTasks", returnType: CAPPluginReturnPromise)
    ]
    
    // MARK: - Implementation
    
    private let implementation = AppleIntelligence()
    
    // MARK: - Helper Methods
    
    /// Create a standardized error response dictionary
    private func errorResponse(code: AppleIntelligenceErrorCode, message: String) -> [String: Any] {
        return [
            "success": false,
            "error": [
                "code": code.rawValue,
                "message": message
            ]
        ]
    }
    
    /// Create an unavailable error response from the availability check
    private func unavailableResponse(from availability: (available: Bool, error: AppleIntelligenceError?)) -> [String: Any] {
        return [
            "success": false,
            "error": availability.error?.asDictionary ?? [
                "code": AppleIntelligenceErrorCode.unavailable.rawValue,
                "message": "Apple Intelligence is not available on this device."
            ]
        ]
    }
    
    // MARK: - Plugin Methods
    
    /// Generate structured JSON output using Apple Intelligence
    /// - Parameter call: The plugin call containing messages and response_format
    @objc func generate(_ call: CAPPluginCall) {
        // Validate input
        guard let messagesArray = call.getArray("messages") as? [[String: String]] else {
            call.resolve(errorResponse(
                code: .nativeError,
                message: "Invalid or missing 'messages' array. Expected array of { role: string, content: string }."
            ))
            return
        }
        
        guard let responseFormat = call.getObject("response_format") else {
            call.resolve(errorResponse(
                code: .nativeError,
                message: "Missing 'response_format' object."
            ))
            return
        }
        
        guard let formatType = responseFormat["type"] as? String, formatType == "json_schema" else {
            call.resolve(errorResponse(
                code: .nativeError,
                message: "response_format.type must be 'json_schema'."
            ))
            return
        }
        
        guard let schema = responseFormat["schema"] as? [String: Any] else {
            call.resolve(errorResponse(
                code: .nativeError,
                message: "Missing or invalid 'schema' in response_format."
            ))
            return
        }
        
        // Check availability (handles both iOS version and Apple Intelligence feature availability)
        let availability = implementation.checkAvailability()
        guard availability.available else {
            call.resolve(unavailableResponse(from: availability))
            return
        }
        
        // Execute generation asynchronously
        if #available(iOS 26, *) {
            Task { [weak self] in
                guard let self = self else { return }
                
                let result = await self.implementation.generateForBridge(
                    messages: messagesArray,
                    schema: schema
                )
                
                call.resolve(result)
            }
        }
        // Note: No else needed - checkAvailability already handles iOS version check
    }

    /// Generate plain text output using Apple Intelligence
    @objc func generateText(_ call: CAPPluginCall) {
        guard let messagesArray = call.getArray("messages") as? [[String: String]] else {
            call.resolve(errorResponse(
                code: .nativeError,
                message: "Invalid or missing 'messages' array."
            ))
            return
        }

        // Check availability
        let availability = implementation.checkAvailability()
        guard availability.available else {
            call.resolve(unavailableResponse(from: availability))
            return
        }

        if #available(iOS 26, *) {
            Task { [weak self] in
                guard let self = self else { return }
                
                let result = await self.implementation.generateTextForBridge(messages: messagesArray)
                call.resolve(result)
            }
        }
    }

    /// Generate plain text output with specific language
    @objc func generateTextWithLanguage(_ call: CAPPluginCall) {
        guard let messagesArray = call.getArray("messages") as? [[String: String]] else {
            call.resolve(errorResponse(
                code: .nativeError,
                message: "Invalid or missing 'messages' array."
            ))
            return
        }

        guard let language = call.getString("language") else {
            call.resolve(errorResponse(
                code: .nativeError,
                message: "Missing 'language' string."
            ))
            return
        }

        // Check availability
        let availability = implementation.checkAvailability()
        guard availability.available else {
            call.resolve(unavailableResponse(from: availability))
            return
        }

        if #available(iOS 26, *) {
            Task { [weak self] in
                guard let self = self else { return }
                
                let result = await self.implementation.generateTextWithLanguageForBridge(
                    messages: messagesArray,
                    language: language
                )
                call.resolve(result)
            }
        }
    }

    /// Generate image using Apple Intelligence
    @objc func generateImage(_ call: CAPPluginCall) {
        guard let prompt = call.getString("prompt") else {
            call.resolve(errorResponse(
                code: .nativeError,
                message: "Missing 'prompt' string."
            ))
            return
        }

        let style = call.getString("style")
        let count = call.getInt("count") ?? 1
        let compressionQuality = call.getDouble("compressionQuality")
        let sourceImage = call.getString("sourceImage")

        // Check availability
        let availability = implementation.checkAvailability()
        guard availability.available else {
            call.resolve(unavailableResponse(from: availability))
            return
        }

        if #available(iOS 26, *) {
            Task { [weak self] in
                guard let self = self else { return }
                
                let result = await self.implementation.generateImageForBridge(
                    prompt: prompt,
                    style: style,
                    count: count,
                    sourceImageBase64: sourceImage,
                    compressionQuality: compressionQuality.map { CGFloat($0) }
                )
                call.resolve(result)
            }
        }
    }

    /// Check if Apple Intelligence is available on this device
    @objc func checkAvailability(_ call: CAPPluginCall) {
        let availability = implementation.checkAvailability()
        
        if availability.available {
            call.resolve([
                "available": true
            ])
        } else {
            call.resolve([
                "available": false,
                "error": availability.error?.asDictionary ?? [
                    "code": AppleIntelligenceErrorCode.unavailable.rawValue,
                    "message": "Apple Intelligence is not available on this device."
                ]
            ])
        }
    }
    
    /// Cancel all active generation tasks
    @objc func cancelAllTasks(_ call: CAPPluginCall) {
        implementation.cancelAllTasks()
        call.resolve([
            "success": true
        ])
    }
}
