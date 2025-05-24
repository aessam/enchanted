//
//  FontConfigurationStore.swift
//  Enchanted
//
//  Created by Claude on 24/05/2025.
//

import SwiftUI
import Combine

class FontConfigurationStore: ObservableObject {
    static let shared = FontConfigurationStore()
    
    @Published var fontConfiguration: FontConfiguration
    
    @AppStorage("fontSizeCategory") private var fontSizeCategoryRawValue: String = FontSizeCategory.medium.rawValue
    
    private init() {
        let category = FontSizeCategory(rawValue: fontSizeCategoryRawValue) ?? .medium
        self.fontConfiguration = FontConfiguration(sizeCategory: category)
    }
    
    func updateFontSize(category: FontSizeCategory) {
        fontSizeCategoryRawValue = category.rawValue
        fontConfiguration = FontConfiguration(sizeCategory: category)
    }
    
    var currentSizeCategory: FontSizeCategory {
        fontConfiguration.sizeCategory
    }
}