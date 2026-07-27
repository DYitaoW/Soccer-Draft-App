import SwiftUI

enum Position: String, CaseIterable, Codable {
    case GK = "GK"
    case LB = "LB"
    case CB = "CB"
    case RB = "RB"
    case LWB = "LWB"
    case RWB = "RWB"
    case CDM = "CDM"
    case CM = "CM"
    case CAM = "CAM"
    case LM = "LM"
    case RM = "RM"
    case LW = "LW"
    case RW = "RW"
    case CF = "CF"
    case ST = "ST"

    func matches(_ other: Position) -> Bool {
        if self == other { return true }
        switch (self, other) {
        case (.LM, .LW), (.LW, .LM), (.RM, .RW), (.RW, .RM): return true
        case (.CM, .CAM), (.CAM, .CM), (.CM, .CDM), (.CDM, .CM): return true
        default: return false
        }
    }

    var categoryColor: Color {
        switch self {
        case .ST, .CF, .LW, .RW: return .red
        case .CM, .CDM, .CAM, .LM, .RM: return .blue
        case .CB, .LB, .RB, .LWB, .RWB: return Color(red: 0.1, green: 0.55, blue: 0.1)
        case .GK: return .purple
        }
    }
}
