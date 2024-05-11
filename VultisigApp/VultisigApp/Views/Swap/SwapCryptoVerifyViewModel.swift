//
//  SwapVerifyViewModel.swift
//  VultisigApp
//
//  Created by Artur Guseinov on 08.04.2024.
//

import SwiftUI

@MainActor
class SwapCryptoVerifyViewModel: ObservableObject {

    @Published var isAmountCorrect = false
    @Published var isHackedOrPhished = false

    var isValidForm: Bool {
        return isAmountCorrect && isHackedOrPhished
    }
}
