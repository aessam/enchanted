//
//  OllamaService.swift
//  Enchanted
//
//  Created by Augustinas Malinauskas on 09/12/2023.
//

import Foundation
import OllamaKit
import Combine

class OllamaService: @unchecked Sendable {
    static let shared = OllamaService()
    
    var ollamaKit: OllamaKit
    
    init() {
        ollamaKit = OllamaKit(baseURL: URL(string: "http://localhost:11434")!)
        initEndpoint()
    }
    
    func initEndpoint(url: String? = nil, bearerToken: String? = "okki") {
        let defaultUrl = "http://localhost:11434"
        let localStorageUrl = UserDefaults.standard.string(forKey: "ollamaUri")
        let bearerToken = UserDefaults.standard.string(forKey: "ollamaBearerToken")
        if var ollamaUrl = [localStorageUrl, defaultUrl].compactMap({$0}).filter({$0.count > 0}).first {
            if !ollamaUrl.contains("http") {
                ollamaUrl = "http://" + ollamaUrl
            }
            
            if let url = URL(string: ollamaUrl) {
                ollamaKit =  OllamaKit(baseURL: url, bearerToken: bearerToken)
                return
            }
        }
    }
    
    func getModels() async throws -> [LanguageModel]  {
        let response = try await ollamaKit.models()
        let models = response.models.map{
            LanguageModel(
                name: $0.name,
                provider: .ollama,
                imageSupport: $0.details.families?.contains(where: { $0 == "clip" || $0 == "mllama" }) ?? false
            )
        }
        return models
    }
    
    func reachable() async -> Bool {
        return await ollamaKit.reachable()
    }
    
    // MARK: - Tool Calling Support
    
    func chatWithTools(
        model: String,
        messages: [OKChatRequestData.Message],
        tools: [ToolDefinition],
        temperature: Double = 0
    ) -> AnyPublisher<OKChatResponse, Error> {
        
        // Create a custom request structure that includes tools
        var request = OKChatRequestData(model: model, messages: messages)
        request.options = OKCompletionOptions(temperature: Float(temperature))
        
        // Since OllamaKit might not support tools directly, we'll add tool definitions
        // to the system message to enable function calling via prompt engineering
        let toolsPrompt = createToolsSystemPrompt(tools: tools)
        
        // Prepend tools prompt to system message or create new system message
        var modifiedMessages = messages
        if let firstMessage = modifiedMessages.first, firstMessage.role == .system {
            // Append to existing system message
            let combinedContent = "\(firstMessage.content)\n\n\(toolsPrompt)"
            modifiedMessages[0] = OKChatRequestData.Message(
                role: .system,
                content: combinedContent,
                images: firstMessage.images
            )
        } else {
            // Insert new system message at the beginning
            modifiedMessages.insert(
                OKChatRequestData.Message(role: .system, content: toolsPrompt),
                at: 0
            )
        }
        
        var toolRequest = OKChatRequestData(model: model, messages: modifiedMessages)
        var options = OKCompletionOptions()
        options.temperature = Float(temperature)
        toolRequest.options = options
        
        return ollamaKit.chat(data: toolRequest)
    }
    
    private func createToolsSystemPrompt(tools: [ToolDefinition]) -> String {
        let toolsJson = tools.map { tool in
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(tool),
               let jsonString = String(data: data, encoding: .utf8) {
                return jsonString
            }
            return ""
        }.joined(separator: ",\n")
        
        return """
        You are an AI assistant with access to the following tools. When you need to call a function, respond with a JSON object in this exact format:

        ```json
        {
          "tool_calls": [
            {
              "id": "call_123",
              "type": "function",
              "function": {
                "name": "function_name",
                "arguments": "{\"param1\": \"value1\"}"
              }
            }
          ]
        }
        ```

        Available tools:
        [\(toolsJson)]

        Important:
        - Only use these tools when the user asks for time/date information
        - Always provide a unique ID for each tool call (e.g., "call_1", "call_2", etc.)
        - Arguments must be a JSON string, not a JSON object
        - After receiving tool results, respond naturally with the information
        - If you don't need to call any tools, respond normally without the JSON structure
        """
    }
}
