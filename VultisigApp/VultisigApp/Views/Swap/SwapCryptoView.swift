//
//  SwapCryptoView.swift
//  VultisigApp
//
//  Created by Amol Kumar on 2024-03-15.
//

import SwiftUI

struct SwapCryptoView: View {
    let coin: Coin?
    let vault: Vault
    
    @StateObject var tx = SwapTransaction()
    @StateObject var swapViewModel = SwapCryptoViewModel()
    @StateObject var shareSheetViewModel = ShareSheetViewModel()

    @State var keysignView: KeysignView?
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        content
            .navigationBarBackButtonHidden(true)
            .navigationTitle(NSLocalizedString("swap", comment: "SendCryptoView title"))
            .task {
                await swapViewModel.load(tx: tx, initialFromCoin: coin, vault: vault)
            }
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(.keyboard)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    backButton
                }
                
                if swapViewModel.currentIndex==3 {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationQRShareButton(title: "swap", renderedImage: shareSheetViewModel.renderedImage)
                    }
                }
            }
#endif
    }
    
    var content: some View {
        ZStack {
            Background()
            view
        }
        .onDisappear {
            swapViewModel.stopMediator()
        }
#if os(iOS)
        .onTapGesture {
            hideKeyboard()
        }
#endif
    }
    
    var view: some View {
        VStack(spacing: 30) {
            ProgressBar(progress: swapViewModel.progress)
                .padding(.top, 30)
            tabView
        }
    }

    @ViewBuilder
    var tabView: some View {
        ZStack {
            switch swapViewModel.currentIndex {
            case 1:
                detailsView
            case 2:
                verifyView
            case 3:
                pairView
            case 4:
                keysign
            case 5:
                doneView
            default:
                errorView
            }
        }
    }

    var detailsView: some View {
        SwapCryptoDetailsView(tx: tx, swapViewModel: swapViewModel, vault: vault)
    }

    var verifyView: some View {
        SwapVerifyView(tx: tx, swapViewModel: swapViewModel, vault: vault)
    }

    var pairView: some View {
        ZStack {
            if let keysignPayload = swapViewModel.keysignPayload {
                KeysignDiscoveryView(
                    vault: vault,
                    keysignPayload: keysignPayload,
                    transferViewModel: swapViewModel,
                    keysignView: $keysignView, 
                    shareSheetViewModel: shareSheetViewModel
                )
            } else {
                SendCryptoVaultErrorView()
            }
        }
    }

    var keysign: some View {
        ZStack {
            if let keysignView = keysignView {
                keysignView
            } else {
                SendCryptoSigningErrorView()
            }
        }
    }

    var doneView: some View {
        ZStack {
            if let hash = swapViewModel.hash {
                SendCryptoDoneView(
                    vault: vault, hash: hash, 
                    explorerLink: swapViewModel.explorerLink(tx: tx, hash: hash),
                    progressLink: swapViewModel.progressLink(tx: tx, hash: hash)
                )
            } else {
                SendCryptoSigningErrorView()
            }
        }.onAppear() {
            Task {
                try await Task.sleep(for: .seconds(5))
                swapViewModel.stopMediator()
            }
        }
    }

    var errorView: some View {
        SendCryptoSigningErrorView()
    }
    
    var backButton: some View {
        let isDone = swapViewModel.currentIndex==5
        
        return Button {
            handleBackTap()
        } label: {
            NavigationBlankBackButton()
        }
        .opacity(isDone ? 0 : 1)
        .disabled(isDone)
    }
    
    private func handleBackTap() {
        guard swapViewModel.currentIndex>1 else {
            dismiss()
            return
        }
        
        swapViewModel.handleBackTap()
    }
}

#Preview {
    SwapCryptoView(coin: .example, vault: .example)
}
