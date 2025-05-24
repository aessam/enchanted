//
//  FontConfiguration.swift
//  Enchanted
//
//  Created by Claude on 24/05/2025.
//

import SwiftUI

enum FontSizeCategory: String, CaseIterable {
    case extraSmall = "extraSmall"
    case small = "small"
    case medium = "medium"
    case large = "large"
    case extraLarge = "extraLarge"
    
    var displayName: String {
        switch self {
        case .extraSmall: return "Extra Small"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .extraLarge: return "Extra Large"
        }
    }
    
    var baseSize: CGFloat {
        switch self {
        case .extraSmall: return 12
        case .small: return 13
        case .medium: return 14
        case .large: return 16
        case .extraLarge: return 18
        }
    }
    
    var scaleFactor: CGFloat {
        return baseSize / FontSizeCategory.medium.baseSize
    }
}

struct FontConfiguration {
    let sizeCategory: FontSizeCategory
    
    init(sizeCategory: FontSizeCategory = .medium) {
        self.sizeCategory = sizeCategory
    }
    
    // UI Font sizes with proportional scaling
    var smallUIFont: CGFloat { 12 * sizeCategory.scaleFactor }
    var regularUIFont: CGFloat { 14 * sizeCategory.scaleFactor }
    var mediumUIFont: CGFloat { 16 * sizeCategory.scaleFactor }
    
    // Chat and content font sizes
    var chatInputFont: CGFloat { 14 * sizeCategory.scaleFactor }
    var systemPromptFont: CGFloat { 13 * sizeCategory.scaleFactor }
    var codeFont: CGFloat { 13 * sizeCategory.scaleFactor }
    
    // Markdown base font size for theme
    var markdownBaseSize: CGFloat { 14 * sizeCategory.scaleFactor }
}

// Extension to provide SwiftUI Font objects
extension FontConfiguration {
    func smallUIFont(design: Font.Design = .default) -> Font {
        .system(size: smallUIFont, design: design)
    }
    
    func regularUIFont(design: Font.Design = .default) -> Font {
        .system(size: regularUIFont, design: design)
    }
    
    func mediumUIFont(design: Font.Design = .default) -> Font {
        .system(size: mediumUIFont, design: design)
    }
    
    func chatInputFont(design: Font.Design = .default) -> Font {
        .system(size: chatInputFont, design: design)
    }
    
    func systemPromptFont(design: Font.Design = .default) -> Font {
        .system(size: systemPromptFont, design: design)
    }
    
    func codeFont(design: Font.Design = .monospaced) -> Font {
        .system(size: codeFont, design: design)
    }
}