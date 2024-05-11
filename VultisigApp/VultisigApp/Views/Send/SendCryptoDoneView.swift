//
//  SendCryptoDoneView.swift
//  VultisigApp
//
//  Created by Amol Kumar on 2024-03-17.
//

import SwiftUI

struct SendCryptoDoneView: View {
    let vault: Vault
    let hash: String
    let explorerLink: String

    var progressLink: String? = nil

    @State var showAlert = false
    
    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            Background()
            view
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(NSLocalizedString("hashCopied", comment: "")),
                message: Text(hash),
                dismissButton: .default(Text(NSLocalizedString("ok", comment: "")))
            )
        }
    }
    
    var view: some View {
        VStack {
            cards
            continueButton
        }
    }
    
    var cards: some View {
        ScrollView {
            card
        }
    }
    
    var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleSection
            
            Text(hash)
                .font(.body13Menlo)
                .foregroundColor(.turquoise600)

            if showProgress {
                HStack {
                    Spacer()
                    progressbutton
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.blue600)
        .cornerRadius(10)
        .padding(.horizontal, 16)
    }
    
    var titleSection: some View {
        HStack(spacing: 12) {
            Text(NSLocalizedString("transaction", comment: "Transaction"))
                .font(.body20MontserratSemiBold)
                .foregroundColor(.neutral0)
            
            copyButton
            linkButton
        }
    }
    
    var copyButton: some View {
        Button {
            copyHash()
        } label: {
            Image(systemName: "square.on.square")
                .font(.body18Menlo)
                .foregroundColor(.neutral0)
        }
        
    }
    
    var linkButton: some View {
        Button {
            shareLink()
        } label: {
            Image(systemName: "link")
                .font(.body18Menlo)
                .foregroundColor(.neutral0)
        }
    }

    var progressbutton: some View {
        Button {
            checkProgressLink()
        } label: {
            Text(NSLocalizedString("Swap progress", comment: ""))
                .font(.body14Menlo)
                .foregroundColor(.neutral0)
        }
    }

    var continueButton: some View {
        NavigationLink(destination: {
            HomeView(selectedVault: vault)
        }, label: {
            FilledButton(title: "complete")
        })
        .id(UUID())
        .padding(40)
    }

    var showProgress: Bool {
        return progressLink != nil && progressLink != explorerLink
    }

    private func copyHash() {
        showAlert = true
        let pasteboard = UIPasteboard.general
        pasteboard.string = hash
    }
    
    private func shareLink() {
        if !explorerLink.isEmpty, let u = URL(string: explorerLink) {
            openURL(u)
        }
    }

    private func checkProgressLink() {
        if let progressLink, let url = URL(string: progressLink) {
            openURL(url)
        }
    }
}

#Preview {
    SendCryptoDoneView(
        vault:Vault.example,
        hash: "bc1psrjtwm7682v6nhx2uwfgcfelrennd7pcvqq7v6w",
        explorerLink: "https://blockstream.info/tx/",
        progressLink: "https://blockstream.info/tx/"
    )
    .previewDevice("iPhone 13 Pro")
}
