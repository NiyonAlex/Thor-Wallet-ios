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
    case memo
}

struct SendCryptoDetailsView: View {
    @ObservedObject var tx: SendTransaction
    @ObservedObject var sendCryptoViewModel: SendCryptoViewModel
    let vault: Vault
    
    @State var amount = ""
    @State var nativeTokenBalance = ""
    @State var coinBalance: String? = nil
    @State var showMemoField = false
    
    @State var isLoading = false
    @State var isCoinPickerActive = false
    
    @FocusState private var focusedField: Field?
    
    var body: some View {
        ZStack {
            Background()
            view
            
            if isLoading {
                Loader()
            }
        }
        .gesture(DragGesture())
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                
#if os(iOS)
                Button {
                    hideKeyboard()
                } label: {
                    Text(NSLocalizedString("done", comment: "Done"))
                }
#endif
            }
        }
        .onAppear {
            setData()
        }
        .onChange(of: tx.coin) { oldValue, newValue in
            setData()
        }
        .alert(isPresented: $sendCryptoViewModel.showAlert) {
            alert
        }
        .navigationDestination(isPresented: $isCoinPickerActive) {
            CoinPickerView(coins: vault.coins) { coin in
                tx.coin = coin
                tx.fromAddress = coin.address
            }
        }
    }
    
    var view: some View {
        VStack {
            fields
            button
        }
#if os(macOS)
        .padding(26)
#endif
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
                
                if tx.coin.isNativeToken {
                    memoField
                }
                
                amountField
                amountFiatField
                
                if !tx.coin.isNativeToken {
                    balanceNativeTokenField
                }
                
                gasField
                
                if tx.canBeReaped {
                    existentialDepositTextMessage
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    var coinSelector: some View {
        TokenSelectorDropdown(
            coin: tx.coin,
            onPress: {
                isCoinPickerActive = true
            }
        )
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
    
    var memoField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation {
                    showMemoField.toggle()
                }
            } label: {
                memoFieldTitle
            }
            
            MemoTextField(memo: $tx.memo)
                .focused($focusedField, equals: .memo)
                .onSubmit {
                    focusNextField($focusedField)
                }
                .frame(height: showMemoField ? nil : 0, alignment: .top)
                .clipped()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    var memoFieldTitle: some View {
        HStack(spacing: 8) {
            getTitle(for: "memo(optional)", isExpanded: false)
            
            Image(systemName: showMemoField ? "chevron.up" : "chevron.down")
                .font(.body14MontserratMedium)
                .foregroundColor(.neutral0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    var percentageButtons: some View {
        HStack(spacing: 12) {
            Button {
                sendCryptoViewModel.setMaxValues(tx: tx, percentage: 25)
            } label: {
                getPercentageCell(for: "25")
            }
            
            Button {
                sendCryptoViewModel.setMaxValues(tx: tx, percentage: 50)
            } label: {
                getPercentageCell(for: "50")
            }
        }
    }
    
    var amountField: some View {
        VStack(spacing: 8) {
            HStack {
                getTitle(for: "amount")
                Spacer()
                percentageButtons
            }
            
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
        .onChange(of: tx.coin) { oldValue, newValue in
            Task {
                await sendCryptoViewModel.convertToFiat(newValue: tx.amount, tx: tx)
            }
        }
    }
    
    var existentialDepositTextMessage: some View {
        HStack {
            Text(NSLocalizedString("polkadotExistentialDepositError", comment: ""))
        }
        .font(.body8Menlo)
        .foregroundColor(.red)
    }
    
    var balanceNativeTokenField: some View {
        HStack {
            Text(NSLocalizedString("balanceNativeToken", comment: ""))
            Spacer()
            Text(nativeTokenBalance)
        }
        .font(.body16Menlo)
        .foregroundColor(.neutral0)
        .onAppear{
            Task {
                let balanceInt = await tx.getNativeTokenBalance()
                nativeTokenBalance = balanceInt.description
            }
        }
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
    
    private func getTitle(for text: String, isExpanded: Bool = true) -> some View {
        Text(
            NSLocalizedString(text, comment: "")
                .replacingOccurrences(of: "Fiat", with: SettingsCurrency.current.rawValue)
        )
        .font(.body14MontserratMedium)
        .foregroundColor(.neutral0)
        .frame(maxWidth: isExpanded ? .infinity : nil, alignment: .leading)
    }
    
    private func getPercentageCell(for text: String) -> some View {
        Text(text + "%")
            .font(.body12Menlo)
            .foregroundColor(.neutral0)
            .padding(.vertical, 6)
            .padding(.horizontal, 20)
            .background(Color.blue600)
            .cornerRadius(6)
    }
    
    private func setData() {
        Task {
            isLoading = true
            await getBalance()
            isLoading = false
        }
    }
    
    private func validateForm() async {
        if await sendCryptoViewModel.validateForm(tx: tx) {
            sendCryptoViewModel.moveToNextView()
        }
    }
    
    private func getBalance() async {
        await BalanceService.shared.updateBalance(for: tx.coin)
        coinBalance = tx.coin.balanceString
    }
}

#Preview {
    SendCryptoDetailsView(
        tx: SendTransaction(),
        sendCryptoViewModel: SendCryptoViewModel(),
        vault: Vault.example
    )
}
