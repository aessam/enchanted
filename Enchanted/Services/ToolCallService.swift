//
//  ToolCallService.swift
//  Enchanted
//
//  Created by Claude AI on 24/05/2025.
//

import Foundation

class ToolCallService: @unchecked Sendable {
    static let shared = ToolCallService()
    
    private init() {}
    
    func getAvailableTools() -> [ToolDefinition] {
        return ToolType.allCases.map { $0.definition }
    }
    
    func executeToolCall(_ toolCall: ToolCall) async -> ToolCallResult {
        guard let toolType = ToolType(rawValue: toolCall.function.name) else {
            return ToolCallResult(
                toolCallId: toolCall.id,
                result: "",
                error: "Unknown tool: \(toolCall.function.name)"
            )
        }
        
        do {
            let arguments = try parseArguments(toolCall.function.arguments)
            let result = try await executeFunction(toolType, arguments: arguments)
            
            return ToolCallResult(
                toolCallId: toolCall.id,
                result: result,
                error: nil
            )
        } catch {
            return ToolCallResult(
                toolCallId: toolCall.id,
                result: "",
                error: error.localizedDescription
            )
        }
    }
    
    private func parseArguments(_ argumentsString: String) throws -> [String: Any] {
        guard !argumentsString.isEmpty else { return [:] }
        
        let data = argumentsString.data(using: .utf8) ?? Data()
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        
        guard let arguments = json as? [String: Any] else {
            throw ToolCallError.invalidArguments
        }
        
        return arguments
    }
    
    private func executeFunction(_ toolType: ToolType, arguments: [String: Any]) async throws -> String {
        switch toolType {
        case .getCurrentTime:
            return try getCurrentTime(arguments: arguments)
        case .getCurrentDate:
            return try getCurrentDate(arguments: arguments)
        case .getTimestamp:
            return try getTimestamp(arguments: arguments)
        case .formatDate:
            return try formatDate(arguments: arguments)
        case .getTimeZone:
            return try getTimeZone(arguments: arguments)
        }
    }
    
    // MARK: - Time Functions
    
    private func getCurrentTime(arguments: [String: Any]) throws -> String {
        let format = arguments["format"] as? String ?? "24-hour"
        let timezoneString = arguments["timezone"] as? String
        
        let formatter = DateFormatter()
        
        if let timezoneString = timezoneString {
            if let timezone = TimeZone(identifier: timezoneString) {
                formatter.timeZone = timezone
            } else {
                throw ToolCallError.invalidTimezone(timezoneString)
            }
        }
        
        switch format {
        case "12-hour":
            formatter.dateFormat = "h:mm:ss a"
        case "24-hour":
            formatter.dateFormat = "HH:mm:ss"
        case "HH:mm":
            formatter.dateFormat = "HH:mm"
        case "HH:mm:ss":
            formatter.dateFormat = "HH:mm:ss"
        default:
            formatter.dateFormat = format
        }
        
        let currentTime = formatter.string(from: Date())
        let timezoneInfo = timezoneString ?? TimeZone.current.identifier
        
        return "\(currentTime) (\(timezoneInfo))"
    }
    
    private func getCurrentDate(arguments: [String: Any]) throws -> String {
        let format = arguments["format"] as? String ?? "YYYY-MM-DD"
        let timezoneString = arguments["timezone"] as? String
        
        let formatter = DateFormatter()
        
        if let timezoneString = timezoneString {
            if let timezone = TimeZone(identifier: timezoneString) {
                formatter.timeZone = timezone
            } else {
                throw ToolCallError.invalidTimezone(timezoneString)
            }
        }
        
        switch format {
        case "YYYY-MM-DD":
            formatter.dateFormat = "yyyy-MM-dd"
        case "MM/DD/YYYY":
            formatter.dateFormat = "MM/dd/yyyy"
        case "DD/MM/YYYY":
            formatter.dateFormat = "dd/MM/yyyy"
        case "long":
            formatter.dateStyle = .long
        case "short":
            formatter.dateStyle = .short
        case "medium":
            formatter.dateStyle = .medium
        case "full":
            formatter.dateStyle = .full
        default:
            formatter.dateFormat = format
        }
        
        let currentDate = formatter.string(from: Date())
        let timezoneInfo = timezoneString ?? TimeZone.current.identifier
        
        return "\(currentDate) (\(timezoneInfo))"
    }
    
    private func getTimestamp(arguments: [String: Any]) throws -> String {
        let unit = arguments["unit"] as? String ?? "seconds"
        let currentDate = Date()
        
        switch unit {
        case "seconds":
            return String(Int(currentDate.timeIntervalSince1970))
        case "milliseconds":
            return String(Int(currentDate.timeIntervalSince1970 * 1000))
        default:
            throw ToolCallError.invalidUnit(unit)
        }
    }
    
    private func formatDate(arguments: [String: Any]) throws -> String {
        guard let input = arguments["input"] as? String else {
            throw ToolCallError.missingRequiredParameter("input")
        }
        
        guard let outputFormat = arguments["outputFormat"] as? String else {
            throw ToolCallError.missingRequiredParameter("outputFormat")
        }
        
        let inputFormat = arguments["inputFormat"] as? String
        let timezoneString = arguments["timezone"] as? String
        
        let inputDate: Date
        
        if inputFormat == "timestamp" || inputFormat == nil && input.allSatisfy({ $0.isNumber }) {
            // Parse as timestamp
            if let timestamp = Double(input) {
                // Determine if it's seconds or milliseconds based on magnitude
                let timestampValue = timestamp > 1_000_000_000_000 ? timestamp / 1000 : timestamp
                inputDate = Date(timeIntervalSince1970: timestampValue)
            } else {
                throw ToolCallError.invalidDateFormat
            }
        } else {
            // Parse with specified format
            let inputFormatter = DateFormatter()
            if let inputFormat = inputFormat {
                inputFormatter.dateFormat = inputFormat
            } else {
                // Try common formats
                let commonFormats = ["yyyy-MM-dd", "MM/dd/yyyy", "dd/MM/yyyy", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss"]
                var parsedDate: Date?
                
                for format in commonFormats {
                    inputFormatter.dateFormat = format
                    if let date = inputFormatter.date(from: input) {
                        parsedDate = date
                        break
                    }
                }
                
                guard let date = parsedDate else {
                    throw ToolCallError.invalidDateFormat
                }
                inputDate = date
            }
            
            guard let date = inputFormatter.date(from: input) else {
                throw ToolCallError.invalidDateFormat
            }
            inputDate = date
        }
        
        // Format output
        let outputFormatter = DateFormatter()
        
        if let timezoneString = timezoneString {
            if let timezone = TimeZone(identifier: timezoneString) {
                outputFormatter.timeZone = timezone
            } else {
                throw ToolCallError.invalidTimezone(timezoneString)
            }
        }
        
        outputFormatter.dateFormat = outputFormat
        return outputFormatter.string(from: inputDate)
    }
    
    private func getTimeZone(arguments: [String: Any]) throws -> String {
        let timezoneString = arguments["timezone"] as? String
        
        let timezone: TimeZone
        if let timezoneString = timezoneString {
            guard let tz = TimeZone(identifier: timezoneString) else {
                throw ToolCallError.invalidTimezone(timezoneString)
            }
            timezone = tz
        } else {
            timezone = TimeZone.current
        }
        
        let formatter = DateFormatter()
        formatter.timeZone = timezone
        
        let currentDate = Date()
        let offsetSeconds = timezone.secondsFromGMT(for: currentDate)
        let offsetHours = offsetSeconds / 3600
        let offsetMinutes = abs(offsetSeconds % 3600) / 60
        
        let offsetString = String(format: "%+03d:%02d", offsetHours, offsetMinutes)
        
        return """
        Timezone: \(timezone.identifier)
        Abbreviation: \(timezone.abbreviation(for: currentDate) ?? "Unknown")
        UTC Offset: \(offsetString)
        Is DST: \(timezone.isDaylightSavingTime(for: currentDate))
        """
    }
}

enum ToolCallError: LocalizedError {
    case invalidArguments
    case invalidTimezone(String)
    case invalidUnit(String)
    case missingRequiredParameter(String)
    case invalidDateFormat
    
    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            return "Invalid function arguments format"
        case .invalidTimezone(let timezone):
            return "Invalid timezone: \(timezone)"
        case .invalidUnit(let unit):
            return "Invalid unit: \(unit)"
        case .missingRequiredParameter(let param):
            return "Missing required parameter: \(param)"
        case .invalidDateFormat:
            return "Invalid date format or unable to parse date"
        }
    }
}