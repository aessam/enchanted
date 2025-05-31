//
//  Tool.swift
//  Enchanted
//
//  Created by Copilot on 24/05/2025.
//

import Foundation

// Tool definition that matches the OpenAI/Ollama tool format
struct Tool: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var description: String
    var parameters: ToolParameters?
    
    // Time tool definition
    static let timeTools = Tool(
        name: "get_time",
        description: "Get the current time or format a time string",
        parameters: ToolParameters(
            type: "object",
            properties: [
                "timezone": ToolParameterProperty(
                    type: "string",
                    description: "Timezone for the time (e.g., 'UTC', 'America/New_York', 'Europe/London'). Optional, defaults to local timezone."
                ),
                "format": ToolParameterProperty(
                    type: "string",
                    description: "Format for the time (e.g., 'HH:mm:ss'). Optional, defaults to full time representation."
                )
            ],
            required: []
        )
    )
    
    // Date tool definition
    static let dateTools = Tool(
        name: "get_date",
        description: "Get the current date or format a date string",
        parameters: ToolParameters(
            type: "object",
            properties: [
                "timezone": ToolParameterProperty(
                    type: "string",
                    description: "Timezone for the date (e.g., 'UTC', 'America/New_York', 'Europe/London'). Optional, defaults to local timezone."
                ),
                "format": ToolParameterProperty(
                    type: "string",
                    description: "Format for the date (e.g., 'yyyy-MM-dd'). Optional, defaults to full date representation."
                )
            ],
            required: []
        )
    )
    
    // All available tools array
    static let availableTools = [
        timeTools,
        dateTools
    ]
}

// Tool parameters structure
struct ToolParameters: Codable, Hashable {
    var type: String
    var properties: [String: ToolParameterProperty]
    var required: [String]?
}

// Tool parameter property
struct ToolParameterProperty: Codable, Hashable {
    var type: String
    var description: String
    var enum_values: [String]? = nil
    
    enum CodingKeys: String, CodingKey {
        case type
        case description
        case enum_values = "enum"
    }
}