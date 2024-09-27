//
//  Placement+iOS.swift
//  VultisigApp
//
//  Created by Amol Kumar on 2024-09-27.
//

#if os(iOS)
import SwiftUI

enum Placement {
    case topBarLeading
    case topBarTrailing
    case principal

    func getPlacement() -> ToolbarItemPlacement {
        switch self {
        case .topBarLeading:
            return ToolbarItemPlacement.topBarLeading
        case .topBarTrailing:
            return ToolbarItemPlacement.topBarTrailing
        case .principal:
            return ToolbarItemPlacement.principal
        }
    }
}
#endif
