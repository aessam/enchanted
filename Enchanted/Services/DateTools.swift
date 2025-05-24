//
//  DateTools.swift
//  Enchanted
//
//  Created by Copilot on 24/05/2025.
//

import Foundation

class DateTools {
    static let shared = DateTools()
    
    private init() {}
    
    func getCurrentDate(timezone: String? = nil, format: String? = nil) -> String {
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
            formatter.dateStyle = .full
            formatter.timeStyle = .none
        }
        
        return formatter.string(from: date)
    }
    
    // Handle tool call for date
    func handleDateToolCall(_ arguments: [String: Any]?) -> String {
        let timezone = arguments?["timezone"] as? String
        let format = arguments?["format"] as? String
        
        return getCurrentDate(timezone: timezone, format: format)
    }
}