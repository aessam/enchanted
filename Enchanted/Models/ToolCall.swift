//
//  ToolCall.swift
//  Enchanted
//
//  Created by Claude AI on 24/05/2025.
//

import Foundation

struct ToolCall: Codable, Identifiable {
    let id: String
    let type: String
    let function: FunctionCall
    
    struct FunctionCall: Codable {
        let name: String
        let arguments: String
    }
}

struct ToolCallResult: Codable {
    let toolCallId: String
    let result: String
    let error: String?
}

enum ToolType: String, CaseIterable {
    case getCurrentTime = "get_current_time"
    case getCurrentDate = "get_current_date"
    case getTimestamp = "get_timestamp"
    case formatDate = "format_date"
    case getTimeZone = "get_timezone"
    
    var definition: ToolDefinition {
        switch self {
        case .getCurrentTime:
            return ToolDefinition(
                type: "function",
                function: FunctionDefinition(
                    name: rawValue,
                    description: "Get the current time in a specified format",
                    parameters: ParametersSchema(
                        type: "object",
                        properties: [
                            "format": PropertySchema(
                                type: "string",
                                description: "Time format (e.g., 'HH:mm', '12-hour', '24-hour')",
                                enum: ["12-hour", "24-hour", "HH:mm", "HH:mm:ss"]
                            ),
                            "timezone": PropertySchema(
                                type: "string",
                                description: "Timezone identifier (e.g., 'UTC', 'America/New_York'). Defaults to system timezone."
                            )
                        ],
                        required: []
                    )
                )
            )
        case .getCurrentDate:
            return ToolDefinition(
                type: "function",
                function: FunctionDefinition(
                    name: rawValue,
                    description: "Get the current date in a specified format",
                    parameters: ParametersSchema(
                        type: "object",
                        properties: [
                            "format": PropertySchema(
                                type: "string",
                                description: "Date format (e.g., 'YYYY-MM-DD', 'MM/DD/YYYY', 'long', 'short')",
                                enum: ["YYYY-MM-DD", "MM/DD/YYYY", "DD/MM/YYYY", "long", "short", "medium", "full"]
                            ),
                            "timezone": PropertySchema(
                                type: "string",
                                description: "Timezone identifier. Defaults to system timezone."
                            )
                        ],
                        required: []
                    )
                )
            )
        case .getTimestamp:
            return ToolDefinition(
                type: "function",
                function: FunctionDefinition(
                    name: rawValue,
                    description: "Get the current Unix timestamp",
                    parameters: ParametersSchema(
                        type: "object",
                        properties: [
                            "unit": PropertySchema(
                                type: "string",
                                description: "Timestamp unit",
                                enum: ["seconds", "milliseconds"]
                            )
                        ],
                        required: []
                    )
                )
            )
        case .formatDate:
            return ToolDefinition(
                type: "function",
                function: FunctionDefinition(
                    name: rawValue,
                    description: "Format a given date string or timestamp to a different format",
                    parameters: ParametersSchema(
                        type: "object",
                        properties: [
                            "input": PropertySchema(
                                type: "string",
                                description: "Input date string or timestamp to format"
                            ),
                            "inputFormat": PropertySchema(
                                type: "string",
                                description: "Format of the input date (e.g., 'YYYY-MM-DD', 'timestamp')"
                            ),
                            "outputFormat": PropertySchema(
                                type: "string",
                                description: "Desired output format"
                            ),
                            "timezone": PropertySchema(
                                type: "string",
                                description: "Timezone for the output"
                            )
                        ],
                        required: ["input", "outputFormat"]
                    )
                )
            )
        case .getTimeZone:
            return ToolDefinition(
                type: "function",
                function: FunctionDefinition(
                    name: rawValue,
                    description: "Get information about the current or specified timezone",
                    parameters: ParametersSchema(
                        type: "object",
                        properties: [
                            "timezone": PropertySchema(
                                type: "string",
                                description: "Timezone identifier. If not provided, returns current system timezone info."
                            )
                        ],
                        required: []
                    )
                )
            )
        }
    }
}

struct ToolDefinition: Codable {
    let type: String
    let function: FunctionDefinition
}

struct FunctionDefinition: Codable {
    let name: String
    let description: String
    let parameters: ParametersSchema
}

struct ParametersSchema: Codable {
    let type: String
    let properties: [String: PropertySchema]
    let required: [String]
}

struct PropertySchema: Codable {
    let type: String
    let description: String
    let `enum`: [String]?
    
    init(type: String, description: String, enum: [String]? = nil) {
        self.type = type
        self.description = description
        self.enum = `enum`
    }
}