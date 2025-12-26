import Foundation
import Capacitor

/// Capacitor plugin class for Apple Intelligence
/// Bridges JavaScript calls to the native AppleIntelligence implementation
@objc(AppleIntelligencePlugin)
public class AppleIntelligencePlugin: CAPPlugin, CAPBridgedPlugin {
    
    // MARK: - Plugin Configuration
    
    public let identifier = "AppleIntelligencePlugin"
    public let jsName = "AppleIntelligence"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "generate", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "generateText", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "generateTextWithLanguage", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "checkAvailability", returnType: CAPPluginReturnPromise)
    ]
    
    // MARK: - Implementation
    
    private let implementation = AppleIntelligence()
    
    // MARK: - Plugin Methods
    
    /// Generate structured JSON output using Apple Intelligence
    /// - Parameter call: The plugin call containing messages and response_format
    @objc func generate(_ call: CAPPluginCall) {
        // Validate input
        guard let messagesArray = call.getArray("messages") as? [[String: String]] else {
            call.resolve([
                "success": false,
                "error": [
                    "code": "NATIVE_ERROR",
                    "message": "Invalid or missing 'messages' array. Expected array of { role: string, content: string }."
                ]
            ])
            return
        }
        
        guard let responseFormat = call.getObject("response_format") else {
            call.resolve([
                "success": false,
                "error": [
                    "code": "NATIVE_ERROR",
                    "message": "Missing 'response_format' object."
                ]
            ])
            return
        }
        
        guard let formatType = responseFormat["type"] as? String, formatType == "json_schema" else {
            call.resolve([
                "success": false,
                "error": [
                    "code": "NATIVE_ERROR",
                    "message": "response_format.type must be 'json_schema'."
                ]
            ])
            return
        }
        
        guard let schema = responseFormat["schema"] as? [String: Any] else {
            call.resolve([
                "success": false,
                "error": [
                    "code": "NATIVE_ERROR",
                    "message": "Missing or invalid 'schema' in response_format."
                ]
            ])
            return
        }
        
        // Check availability
        let availability = implementation.checkAvailability()
        if !availability.available {
            call.resolve([
                "success": false,
                "error": availability.error?.asDictionary ?? [
                    "code": "UNAVAILABLE",
                    "message": "Apple Intelligence is not available on this device."
                ]
            ])
            return
        }
        
        // Execute generation asynchronously
        if #available(iOS 26, *) {
            Task {
                let result = await implementation.generateForBridge(
                    messages: messagesArray,
                    schema: schema
                )
                
                // Resolve on main thread
                await MainActor.run {
                    call.resolve(result)
                }
            }
        } else {
            call.resolve([
                "success": false,
                "error": [
                    "code": "UNAVAILABLE",
                    "message": "Apple Intelligence requires iOS 26 or later."
                ]
            ])
        }
    }

    /// Generate plain text output using Apple Intelligence
    @objc func generateText(_ call: CAPPluginCall) {
        guard let messagesArray = call.getArray("messages") as? [[String: String]] else {
            call.resolve([
                "success": false,
                "error": [
                    "code": "NATIVE_ERROR",
                    "message": "Invalid or missing 'messages' array."
                ]
            ])
            return
        }

        // Check availability
        let availability = implementation.checkAvailability()
        if !availability.available {
            call.resolve([
                "success": false,
                "error": availability.error?.asDictionary ?? [
                    "code": "UNAVAILABLE",
                    "message": "Apple Intelligence is not available on this device."
                ]
            ])
            return
        }

        if #available(iOS 26, *) {
            Task {
                let result = await implementation.generateTextForBridge(messages: messagesArray)
                await MainActor.run {
                    call.resolve(result)
                }
            }
        } else {
            call.resolve([
                "success": false,
                "error": [
                    "code": "UNAVAILABLE",
                    "message": "Apple Intelligence requires iOS 26 or later."
                ]
            ])
        }
    }

    /// Generate plain text output with specific language
    @objc func generateTextWithLanguage(_ call: CAPPluginCall) {
        guard let messagesArray = call.getArray("messages") as? [[String: String]] else {
            call.resolve([
                "success": false,
                "error": [
                    "code": "NATIVE_ERROR",
                    "message": "Invalid or missing 'messages' array."
                ]
            ])
            return
        }

        guard let language = call.getString("language") else {
            call.resolve([
                "success": false,
                "error": [
                    "code": "NATIVE_ERROR",
                    "message": "Missing 'language' string."
                ]
            ])
            return
        }

        // Check availability
        let availability = implementation.checkAvailability()
        if !availability.available {
            call.resolve([
                "success": false,
                "error": availability.error?.asDictionary ?? [
                    "code": "UNAVAILABLE",
                    "message": "Apple Intelligence is not available on this device."
                ]
            ])
            return
        }

        if #available(iOS 26, *) {
            Task {
                let result = await implementation.generateTextWithLanguageForBridge(
                    messages: messagesArray,
                    language: language
                )
                await MainActor.run {
                    call.resolve(result)
                }
            }
        } else {
            call.resolve([
                "success": false,
                "error": [
                    "code": "UNAVAILABLE",
                    "message": "Apple Intelligence requires iOS 26 or later."
                ]
            ])
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
                    "code": "UNAVAILABLE",
                    "message": "Apple Intelligence is not available on this device."
                ]
            ])
        }
    }
}
