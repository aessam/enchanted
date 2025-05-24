//
//  ToolCall.swift
//  Enchanted
//
//  Created by Copilot on 24/05/2025.
//

import Foundation

// Structure to represent a tool call request from an LLM
struct ToolCall: Codable, Identifiable, Hashable {
    var id: String
    var type: String = "function"
    var name: String
    var arguments: String
    
    // Parse arguments as JSON dictionary
    var parsedArguments: [String: Any]? {
        guard let data = arguments.data(using: .utf8) else { return nil }
        
        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } catch {
            print("Error parsing tool call arguments: \(error)")
            return nil
        }
    }
}

// Structure to represent a tool call response
struct ToolCallResponse: Codable, Hashable {
    var toolCallId: String
    var role: String = "tool"
    var name: String
    var content: String
    
    enum CodingKeys: String, CodingKey {
        case toolCallId = "tool_call_id"
        case role
        case name
        case content
    }
}

// Structure for handling tool responses in messages
struct ToolCallResult: Codable, Hashable {
    var toolCall: ToolCall
    var response: String
    
    // Format the response as a ToolCallResponse object
    var asToolCallResponse: ToolCallResponse {
        ToolCallResponse(
            toolCallId: toolCall.id,
            name: toolCall.name,
            content: response
        )
    }
}