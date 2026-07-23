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

    var categoryColor: Color {
        switch self {
        case .ST, .CF, .LW, .RW: return .red
        case .CM, .CDM, .CAM, .LM, .RM: return .blue
        case .CB, .LB, .RB, .LWB, .RWB: return .green
        case .GK: return .purple
        }
    }
}
