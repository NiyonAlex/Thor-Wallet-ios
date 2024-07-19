//
//  VaultDetailQRCodeView.swift
//  VultisigApp
//
//  Created by Amol Kumar on 2024-07-18.
//

import SwiftUI

struct VaultDetailQRCodeView: View {
    let vault: Vault
    
    @State var imageName = ""
    @StateObject var viewModel = VaultDetailQRCodeViewModel()
    @Environment(\.displayScale) var displayScale
    
    var body: some View {
        ZStack {
            Background()
            content
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle(NSLocalizedString("shareVaultQR", comment: ""))
        .toolbar {
            ToolbarItem(placement: Placement.topBarLeading.getPlacement()) {
                NavigationBackButton()
            }
        }
    }
    
    var content: some View {
        VStack {
            Spacer()
            qrCode
            Spacer()
            button
        }
        .padding(15)
        .onAppear {
            setData()
        }
    }
    
    var qrCode: some View {
        VaultDetailQRCode(vault: vault)
    }
    
    var button: some View {
        ZStack {
            if let renderedImage = viewModel.renderedImage {
                ShareLink(
                    item: renderedImage,
                    preview: SharePreview(Text(imageName), image: renderedImage)
                ) {
                    FilledButton(title: "saveOrShare")
                        .padding(.bottom, 10)
                }
            } else {
                ProgressView()
            }
        }
    }
    
    private func setData() {
        let name = vault.name
        let ecdsaKey = vault.pubKeyECDSA
        let eddsaKey = vault.pubKeyEdDSA
        let hexCode = vault.hexChainCode
        let id = "\(name)-\(ecdsaKey)-\(eddsaKey)-\(hexCode)".sha256()
        
        imageName = "Vultisig-\(vault.name)-\(id.suffix(3)).png"
        viewModel.render(vault: vault, displayScale: displayScale)
    }
}

#Preview {
    VaultDetailQRCodeView(vault: Vault.example)
}
