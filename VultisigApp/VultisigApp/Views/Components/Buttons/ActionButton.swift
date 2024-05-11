//
//  ActionButton.swift
//  VultisigApp
//
//  Created by Amol Kumar on 2024-05-01.
//

import SwiftUI

struct ActionButton: View {
    let title: String
    let fontColor: Color
    
    var body: some View {
        Text(NSLocalizedString(title, comment: "").uppercased())
            .font(.body16MenloBold)
            .foregroundColor(fontColor)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(Color.blue400)
            .cornerRadius(50)
            .overlay(
                RoundedRectangle(cornerRadius: 50)
                    .stroke(LinearGradient.primaryGradient, lineWidth: 1)
            )
    }
}

#Preview {
    ActionButton(title: "send", fontColor: .turquoise600)
}
