//
//  SwapCryptoView.swift
//  VultisigApp
//
//  Created by Amol Kumar on 2024-03-15.
//

import SwiftUI

struct SwapCryptoView: View {
    let coin: Coin
    let coins: [Coin]
    let vault: Vault
    
    @StateObject var tx = SwapTransaction()
    @StateObject var swapViewModel = SwapCryptoViewModel()
    @StateObject var coinViewModel = CoinViewModel()

    @State var keysignView: KeysignView?
    
    @Environment(\.dismiss) var dismiss

    var body: some View {
        content
            .navigationBarBackButtonHidden(true)
            .navigationTitle(NSLocalizedString("swap", comment: "SendCryptoView title"))
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(.keyboard)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        handleBackTap()
                    } label: {
                        NavigationBlankBackButton()
                    }
                }
            }
            .task {
                await swapViewModel.load(tx: tx, fromCoin: coin, coins: vault.coins, coinViewModel: coinViewModel)
            }
    }
    
    var content: some View {
        ZStack {
            Background()
            view
        }
        .onTapGesture {
            hideKeyboard()
        }
        .onDisappear {
            swapViewModel.stopMediator()
        }
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
        switch swapViewModel.flow {
        case .normal:
            normalFlow
        case .erc20:
            erc20Flow
        }
    }

    var normalFlow: some View {
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

    var erc20Flow: some View {
        ZStack {
            switch swapViewModel.currentIndex {
            case 1:
                detailsView
            case 2:
                approveVerifyView
            case 3:
                pairView
            case 4:
                keysign
            case 5:
                verifyView
            case 6:
                pairView
            case 7:
                keysign
            case 8:
                doneView
            default:
                errorView
            }
        }
    }

    var detailsView: some View {
        SwapCryptoDetailsView(tx: tx, swapViewModel: swapViewModel, coinViewModel: coinViewModel)
    }

    var verifyView: some View {
        SwapVerifyView(tx: tx, swapViewModel: swapViewModel, vault: vault)
    }

    var approveVerifyView: some View {
        SwapApproveVerifyView(tx: tx, swapViewModel: swapViewModel, vault: vault)
    }

    var pairView: some View {
        ZStack {
            if let keysignPayload = swapViewModel.keysignPayload {
                KeysignDiscoveryView(
                    vault: vault,
                    keysignPayload: keysignPayload,
                    transferViewModel: swapViewModel,
                    keysignView: $keysignView
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
                    explorerLink: Endpoint.getExplorerURL(chainTicker: tx.fromCoin.chain.ticker, txid: hash),
                    progressLink: Endpoint.getSwapProgressURL(txid: hash)
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
    
    private func handleBackTap() {
        guard swapViewModel.currentIndex>1 else {
            dismiss()
            return
        }
        
        swapViewModel.handleBackTap()
    }
}

#Preview {
    SwapCryptoView(coin: .example, coins: Vault.example.coins, vault: .example)
}
