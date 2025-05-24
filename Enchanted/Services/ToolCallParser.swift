//
//  ToolCallParser.swift
//  Enchanted
//
//  Created by Claude AI on 24/05/2025.
//

import Foundation

class ToolCallParser {
    static let shared = ToolCallParser()
    
    private init() {}
    
    struct ParsedResponse {
        let hasToolCalls: Bool
        let toolCalls: [ToolCall]
        let content: String
    }
    
    func parseResponse(_ content: String) -> ParsedResponse {
        // Look for JSON structure containing tool_calls
        let toolCalls = extractToolCalls(from: content)
        
        if !toolCalls.isEmpty {
            // Remove the tool call JSON from the content for cleaner display
            let cleanedContent = removeToolCallJSON(from: content)
            return ParsedResponse(hasToolCalls: true, toolCalls: toolCalls, content: cleanedContent)
        }
        
        return ParsedResponse(hasToolCalls: false, toolCalls: [], content: content)
    }
    
    private func extractToolCalls(from content: String) -> [ToolCall] {
        // Look for JSON blocks containing tool_calls
        let jsonPattern = #"```json\s*(\{[\s\S]*?\})\s*```"#
        let regex = try? NSRegularExpression(pattern: jsonPattern, options: [])
        
        guard let regex = regex else { return [] }
        
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, options: [], range: range)
        
        for match in matches {
            if match.numberOfRanges >= 2 {
                let jsonRange = Range(match.range(at: 1), in: content)
                if let jsonRange = jsonRange {
                    let jsonString = String(content[jsonRange])
                    if let toolCalls = parseToolCallsFromJSON(jsonString) {
                        return toolCalls
                    }
                }
            }
        }
        
        // Also try to find tool calls without markdown formatting
        return findToolCallsInPlainText(content)
    }
    
    private func parseToolCallsFromJSON(_ jsonString: String) -> [ToolCall]? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        
        do {
            let decoder = JSONDecoder()
            
            // Try to parse as complete tool call response
            if let toolCallResponse = try? decoder.decode(ToolCallResponse.self, from: data) {
                return toolCallResponse.tool_calls
            }
            
            // Try to parse as array of tool calls directly
            if let toolCalls = try? decoder.decode([ToolCall].self, from: data) {
                return toolCalls
            }
            
        } catch {
            print("Failed to parse tool calls JSON: \(error)")
        }
        
        return nil
    }
    
    private func findToolCallsInPlainText(_ content: String) -> [ToolCall] {
        // Look for JSON-like structures even without markdown
        let patterns = [
            #"\{\s*"tool_calls"\s*:\s*\[[\s\S]*?\]\s*\}"#,
            #"\{\s*"id"\s*:\s*"[^"]+"\s*,\s*"type"\s*:\s*"function"[\s\S]*?\}"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: content, options: [], range: NSRange(content.startIndex..<content.endIndex, in: content)),
               let range = Range(match.range, in: content) {
                
                let jsonString = String(content[range])
                if let toolCalls = parseToolCallsFromJSON(jsonString) {
                    return toolCalls
                }
            }
        }
        
        return []
    }
    
    private func removeToolCallJSON(from content: String) -> String {
        var cleanedContent = content
        
        // Remove JSON code blocks
        let jsonPattern = #"```json\s*\{[\s\S]*?\}\s*```"#
        if let regex = try? NSRegularExpression(pattern: jsonPattern, options: []) {
            let range = NSRange(cleanedContent.startIndex..<cleanedContent.endIndex, in: cleanedContent)
            cleanedContent = regex.stringByReplacingMatches(in: cleanedContent, options: [], range: range, withTemplate: "")
        }
        
        // Clean up any remaining tool call patterns
        let patterns = [
            #"\{\s*"tool_calls"\s*:\s*\[[\s\S]*?\]\s*\}"#,
            #"\{\s*"id"\s*:\s*"[^"]+"\s*,\s*"type"\s*:\s*"function"[\s\S]*?\}"#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(cleanedContent.startIndex..<cleanedContent.endIndex, in: cleanedContent)
                cleanedContent = regex.stringByReplacingMatches(in: cleanedContent, options: [], range: range, withTemplate: "")
            }
        }
        
        return cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ToolCallResponse: Codable {
    let tool_calls: [ToolCall]
}