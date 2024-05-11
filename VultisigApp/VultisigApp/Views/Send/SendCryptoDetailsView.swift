//
//  SendCryptoDetailsView.swift
//  VultisigApp
//
//  Created by Amol Kumar on 2024-03-13.
//

import OSLog
import SwiftUI

enum Field: Int, Hashable {
    case toAddress
    case amount
    case amountInFiat
}

struct SendCryptoDetailsView: View {
    @ObservedObject var tx: SendTransaction
    @ObservedObject var sendCryptoViewModel: SendCryptoViewModel
    let group: GroupedChain
    
    @State var amount = ""
    
    @FocusState private var focusedField: Field?
    
    var body: some View {
        ZStack {
            Background()
            view
        }
        .gesture(DragGesture())
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                
                Button {
                    hideKeyboard()
                } label: {
                    Text(NSLocalizedString("done", comment: "Done"))
                }
            }
        }
        .alert(isPresented: $sendCryptoViewModel.showAlert) {
            alert
        }
    }
    
    var view: some View {
        VStack {
            fields
            button
        }
    }
    
    var alert: Alert {
        Alert(
            title: Text(NSLocalizedString("error", comment: "")),
            message: Text(NSLocalizedString(sendCryptoViewModel.errorMessage, comment: "")),
            dismissButton: .default(Text(NSLocalizedString("ok", comment: "")))
        )
    }
    
    var fields: some View {
        ScrollView {
            VStack(spacing: 16) {
                coinSelector
                fromField
                toField
                amountField
                amountFiatField
                gasField
            }
            .padding(.horizontal, 16)
        }
    }
    
    var coinSelector: some View {
        TokenSelectorDropdown(coins: .constant(group.coins), selected: $tx.coin)
    }
    
    var fromField: some View {
        VStack(spacing: 8) {
            getTitle(for: "from")
            fromTextField
        }
    }
    
    var fromTextField: some View {
        Text(tx.fromAddress)
            .font(.body12Menlo)
            .foregroundColor(.neutral0)
            .frame(height: 48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .background(Color.blue600)
            .cornerRadius(10)
            .lineLimit(1)
    }
    
    var toField: some View {
        VStack(spacing: 8) {
            getTitle(for: "to")
            SendCryptoAddressTextField(tx: tx, sendCryptoViewModel: sendCryptoViewModel)
                .focused($focusedField, equals: .toAddress)
                .onSubmit {
                    focusNextField($focusedField)
                }
        }
    }
    
    var amountField: some View {
        VStack(spacing: 8) {
            getTitle(for: "amount")
            textField
        }
    }
    
    var textField: some View {
        SendCryptoAmountTextField(
            amount: $tx.amount,
            onChange: { await sendCryptoViewModel.convertToFiat(newValue: $0, tx: tx) },
            onMaxPressed: { sendCryptoViewModel.setMaxValues(tx: tx) }
        )
        .focused($focusedField, equals: .amount)
    }
    
    var amountFiatField: some View {
        VStack(spacing: 8) {
            getTitle(for: "amount(inFiat)")
            textFiatField
        }
    }
    
    var textFiatField: some View {
        SendCryptoAmountTextField(
            amount: $tx.amountInFiat,
            onChange: { await sendCryptoViewModel.convertFiatToCoin(newValue: $0, tx: tx) }
        )
        .focused($focusedField, equals: .amountInFiat)
    }
    
    var gasField: some View {
        HStack {
            Text(NSLocalizedString("gas(auto)", comment: ""))
            Spacer()
            Text(tx.gasInReadable)
        }
        .font(.body16Menlo)
        .foregroundColor(.neutral0)
    }
    
    var button: some View {
        Button {
            Task{
                await validateForm()
            }
        } label: {
            FilledButton(title: "continue")
        }
        .padding(40)
    }
    
    private func getTitle(for text: String) -> some View {
        Text(
            NSLocalizedString(text, comment: "")
                .replacingOccurrences(of: "Fiat", with: SettingsCurrency.current.rawValue)
        )
        .font(.body14MontserratMedium)
        .foregroundColor(.neutral0)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func validateForm() async {
        if await sendCryptoViewModel.validateForm(tx: tx) {
            sendCryptoViewModel.moveToNextView()
        }
    }
}

#Preview {
    SendCryptoDetailsView(
        tx: SendTransaction(),
        sendCryptoViewModel: SendCryptoViewModel(),
        group: GroupedChain.example
    )
}
