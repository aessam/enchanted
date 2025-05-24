import SwiftUI

/// App font size preference.
enum AppFontSize: String, Identifiable, CaseIterable {
    case small, normal, large

    var id: String { rawValue }

    /// Human readable description
    var toString: String {
        switch self {
        case .small: return "Small"
        case .normal: return "Normal"
        case .large: return "Large"
        }
    }

    /// Scale factor applied to base font sizes
    var scale: CGFloat {
        switch self {
        case .small: return 0.9
        case .normal: return 1.0
        case .large: return 1.1
        }
    }
}
