//
//  AppFontFamily.swift
//  Enchanted
//
//  Created on 23/05/2024.
//

import Foundation
import SwiftUI

enum AppFontFamily: String, Identifiable, CaseIterable {
    case system
    case sfPro = "sfpro"
    case newYork = "newyork"
    case georgia
    case helveticaNeue = "helveticaneue"
    case avenir
    case futura
    
    var id: String {
        self.rawValue
    }
    
    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .sfPro:
            return "SF Pro"
        case .newYork:
            return "New York"
        case .georgia:
            return "Georgia"
        case .helveticaNeue:
            return "Helvetica Neue"
        case .avenir:
            return "Avenir"
        case .futura:
            return "Futura"
        }
    }
    
    var fontName: String? {
        switch self {
        case .system:
            return nil // System font doesn't need a specific name
        case .sfPro:
            return "SFPro-Regular"
        case .newYork:
            return "NewYork-Regular"
        case .georgia:
            return "Georgia"
        case .helveticaNeue:
            return "HelveticaNeue"
        case .avenir:
            return "Avenir-Book"
        case .futura:
            return "Futura-Medium"
        }
    }
    
    func font(size: CGFloat) -> Font {
        if let name = fontName {
            return Font.custom(name, size: size)
        }
        return Font.system(size: size)
    }
}