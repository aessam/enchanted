//
//  TimeTools.swift
//  Enchanted
//
//  Created by Copilot on 24/05/2025.
//

import Foundation

class TimeTools {
    static let shared = TimeTools()
    
    private init() {}
    
    func getCurrentTime(timezone: String? = nil, format: String? = nil) -> String {
        let date = Date()
        let formatter = DateFormatter()
        
        // Set timezone if provided
        if let timezone = timezone, let timeZone = TimeZone(identifier: timezone) {
            formatter.timeZone = timeZone
        } else {
            formatter.timeZone = TimeZone.current
        }
        
        // Set format if provided
        if let format = format {
            formatter.dateFormat = format
        } else {
            formatter.timeStyle = .medium
            formatter.dateStyle = .none
        }
        
        return formatter.string(from: date)
    }
    
    // Handle tool call for time
    func handleTimeToolCall(_ arguments: [String: Any]?) -> String {
        let timezone = arguments?["timezone"] as? String
        let format = arguments?["format"] as? String
        
        return getCurrentTime(timezone: timezone, format: format)
    }
}