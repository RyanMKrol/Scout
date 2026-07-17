import SwiftUI

struct DialContent: Equatable {
    let downDisplay: String
    let upDisplay: String
    let downFraction: Double
    let upFraction: Double
    let qualityColor: Color
    let generationText: String
}

extension SignalQuality {
    var color: Color {
        switch self {
        case .great:
            ScoutTheme.great
        case .usable:
            ScoutTheme.usable
        case .poor:
            ScoutTheme.poor
        }
    }
}
